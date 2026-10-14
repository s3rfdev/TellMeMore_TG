import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import '../../config/credentials.dart';
import '../../core/utils/time_format.dart';
import '../models/tg_chat.dart';
import 'td_content.dart';
import 'td_json_ffi.dart';

/// Диагностика воркера: запускать с --define=TD_DEBUG=true.
const _debug = bool.fromEnvironment('TD_DEBUG');

void _log(String message) {
  if (_debug) {
    // ignore: avoid_print
    print('[worker] $message');
  }
}

/// Воркер-изолят: единственный владелец TDLib-клиента.
///
/// Два подизолята, ноль блокировок на event loop агрегатора:
///  - entry (агрегатор): события TDLib + команды UI + таймер снимков;
///  - _receiveLoopEntry (приёмник): блокирующий td_json_client_receive,
///    форсит сырой JSON в агрегатор.
///
/// В UI летят готовые снимки не чаще ~6 раз в секунду.
class TdWorker {
  TdWorker._();

  @pragma('vm:entry-point')
  static Future<void> entry(Map<dynamic, dynamic> init) async {
    final clientAddress = init['clientAddress'] as int;
    final ui = init['ui'] as SendPort;
    final store = _Store(
      TdJsonFfi.attach(clientAddress),
      ui,
      init['dbDir'] as String,
      init['filesDir'] as String,
    );

    // Команды из UI — обрабатываются сразу, event loop свободен.
    final cmdPort = ReceivePort();
    cmdPort.listen((m) => store.command(Map<String, dynamic>.from(m as Map)));
    ui.send({'type': 'ready', 'cmd': cmdPort.sendPort});

    // Приёмник: блокирующий цикл в отдельном изоляте.
    final tdEvents = ReceivePort();
    await Isolate.spawn(_receiveLoopEntry, {
      'clientAddress': clientAddress,
      'out': tdEvents.sendPort,
    }, debugName: 'tdlib-receiver');
    tdEvents.listen((m) => store.handleJson(m as String));

    // Периодический сброс снимков в UI.
    Timer.periodic(const Duration(milliseconds: 150), (_) {
      try {
        store.flush();
      } catch (e, stack) {
        // ignore: avoid_print
        print('[worker] uncaught error in flush callback: $e\n$stack');
      }
    });
  }

  /// Блокирующий цикл td_json_client_receive — только чтение, без портов.
  @pragma('vm:entry-point')
  static void _receiveLoopEntry(Map<dynamic, dynamic> args) {
    final ffi = TdJsonFfi.attach(args['clientAddress'] as int);
    final out = args['out'] as SendPort;
    while (true) {
      final json = ffi.receive(timeoutSeconds: 0.5);
      if (json != null) out.send(json);
    }
  }
}

/// Состояние одного чата внутри воркера.
class _ChatState {
  _ChatState({required this.chat, this.unread = 0});

  Map<String, dynamic> chat;
  Map<String, dynamic>? last;
  int unread;

  /// Сырая история TDLib, «новые сверху».
  List<Map<String, dynamic>> history = [];
  bool initialRequested = false;
  bool loadingMore = false;
  bool hasMore = true;
  int oldestId = 0;
}

class _Store {
  _Store(this._ffi, this._ui, this._dbDir, this._filesDir);

  final TdJsonFfi _ffi;
  final SendPort _ui;
  final String _dbDir;
  final String _filesDir;

  final Map<int, _ChatState> _chats = {};
  final Map<int, Map<String, dynamic>> _users = {};
  final Map<int, String> _downloadedFiles = {};
  final Set<int> _downloadingFiles = {};
  int _myId = 0;
  bool _paramsSent = false;
  bool _chatsDirty = false;
  final Set<String> _dirtyHistories = {};
  int? _currentOpenChatId;

  void _openChat(int chatId) {
    if (_currentOpenChatId == chatId) return;
    if (_currentOpenChatId != null) {
      _send({'@type': 'closeChat', 'chat_id': _currentOpenChatId!});
    }
    _currentOpenChatId = chatId;
    _send({'@type': 'openChat', 'chat_id': chatId});
  }

  void _fetchHistoryBatch(_ChatState st, {required bool isInitial}) {
    if (st.loadingMore) return;
    st.loadingMore = true;
    final fromId = (isInitial && st.history.isEmpty) ? 0 : st.oldestId;
    // ignore: avoid_print
    print('[worker] requesting getChatHistory for chat ${st.chat['id']} (fromId: $fromId, isInitial: $isInitial, currHistory: ${st.history.length})');
    _send({
      '@type': 'getChatHistory',
      'chat_id': st.chat['id'],
      'from_message_id': fromId,
      'offset': 0,
      'limit': 30,
      'only_local': false,
      '@extra': {
        'action': isInitial ? 'history' : 'loadMore',
        'chat_id': st.chat['id'],
      },
    });
  }

  // ------------------------------------------------------------ commands

  void command(Map<String, dynamic> cmd) {
    // ignore: avoid_print
    print('[worker] cmd: ${cmd['type']} ${cmd.containsKey('chatId') ? cmd['chatId'] : ''}');
    switch (cmd['type']) {
      case 'ping':
        _ui.send({'type': 'pong', 't': cmd['t']});
      case 'qr':
        _send({'@type': 'requestQrCodeAuthentication'});
      case 'phone':
        // В 1.8.6+ только phone_number + settings (пустые настройки = дефолт).
        _send({
          '@type': 'setAuthenticationPhoneNumber',
          'phone_number': cmd['value'],
          'settings': {'@type': 'phoneNumberAuthenticationSettings'},
        });
      case 'code':
        _send({'@type': 'checkAuthenticationCode', 'code': cmd['value']});
      case 'password':
        _send({'@type': 'checkAuthenticationPassword', 'password': cmd['value']});
      case 'close':
        // корректное закрытие: TDLib сбрасывает binlog с сессией на диск
        _send({'@type': 'close'});
      case 'getMe':
        _send({'@type': 'getMe'});
      case 'send':
        final replyTo = cmd['replyToMessageId'] as int?;
        _send({
          '@type': 'sendMessage',
          'chat_id': cmd['chatId'],
          if (replyTo != null && replyTo > 0)
            'reply_to': {
              '@type': 'inputMessageReplyToMessage',
              'message_id': replyTo,
            },
          'input_message_content': {
            '@type': 'inputMessageText',
            'text': {'@type': 'formattedText', 'text': cmd['text']},
          },
        });
      case 'downloadFile':
        final fileId = cmd['fileId'] as int?;
        if (fileId != null && fileId > 0) {
          _downloadingFiles.add(fileId);
          // ignore: avoid_print
          print('[td_worker] Manual download requested for fileId=$fileId');
          _send({'@type': 'downloadFile', 'file_id': fileId, 'priority': 32, 'synchronous': false});
        }
      case 'deleteMessage':
        final chatId = cmd['chatId'] as int?;
        final messageId = cmd['messageId'] as int?;
        if (chatId != null && messageId != null) {
          _send({
            '@type': 'deleteMessages',
            'chat_id': chatId,
            'message_ids': [messageId],
            'revoke': true,
          });
          final st = _chatById(chatId);
          if (st != null) {
            st.history.removeWhere((m) => m['id'] == messageId);
            _dirtyHistories.add(chatId.toString());
          }
        }
      case 'pinMessage':
        final chatId = cmd['chatId'] as int?;
        final messageId = cmd['messageId'] as int?;
        if (chatId != null && messageId != null) {
          _send({
            '@type': 'pinChatMessage',
            'chat_id': chatId,
            'message_id': messageId,
            'disable_notification': false,
            'only_for_self': false,
          });
        }
      case 'forwardMessage':
        final toChatId = cmd['toChatId'] as int?;
        final fromChatId = cmd['fromChatId'] as int?;
        final messageId = cmd['messageId'] as int?;
        if (toChatId != null && fromChatId != null && messageId != null) {
          _send({
            '@type': 'forwardMessages',
            'chat_id': toChatId,
            'from_chat_id': fromChatId,
            'message_ids': [messageId],
            'send_copy': false,
            'remove_caption': false,
          });
        }
      case 'sendVoice':
        final chatId = cmd['chatId'] as int;
        final path = cmd['path'] as String;
        final duration = cmd['duration'] as int? ?? 0;
        _send({
          '@type': 'sendMessage',
          'chat_id': chatId,
          'input_message_content': {
            '@type': 'inputMessageVoiceNote',
            'voice_note': {
              '@type': 'inputVoiceNote',
              'voice_note': {
                '@type': 'inputFileLocal',
                'path': path,
              },
              'duration': duration,
              'waveform': '',
            },
          },
        });
      case 'sendFile':
        final chatId = cmd['chatId'] as int;
        final path = cmd['path'] as String;
        final caption = cmd['caption'] as String? ?? '';
        _send({
          '@type': 'sendMessage',
          'chat_id': chatId,
          'input_message_content': {
            '@type': 'inputMessageDocument',
            'document': {
              '@type': 'inputDocument',
              'document': {
                '@type': 'inputFileLocal',
                'path': path,
              },
            },
            'caption': {'@type': 'formattedText', 'text': caption},
          },
        });
      case 'searchChats':
        final q = cmd['query'] as String;
        _send({
          '@type': 'searchChats',
          'query': q,
          'limit': 25,
          '@extra': {'action': 'searchChats', 'query': q},
        });
      case 'openUsername':
        final u = (cmd['username'] as String).replaceAll('@', '').trim();
        _send({
          '@type': 'searchPublicChat',
          'username': u,
          '@extra': {'action': 'openUsername', 'username': u},
        });
      case 'createGroup':
        final title = cmd['title'] as String;
        _send({
          '@type': 'createNewBasicGroupChat',
          'title': title,
          'user_ids': <int>[],
          '@extra': {'action': 'createGroup'},
        });
      case 'openChat':
        final chatId = cmd['chatId'] as int;
        _openChat(chatId);
      case 'history':
        final chatId = cmd['chatId'] as int;
        _openChat(chatId);
        final st = _chats.putIfAbsent(
          chatId,
          () => _ChatState(chat: {'id': chatId, 'title': 'Chat'}),
        );
        if (st.history.length >= 20) {
          _dirtyHistories.add(chatId.toString());
          return;
        }
        _fetchHistoryBatch(st, isInitial: true);
      case 'loadMore':
        final chatId = cmd['chatId'] as int;
        final st = _chatById(chatId);
        if (st == null || !st.hasMore || st.loadingMore) {
          return;
        }
        _fetchHistoryBatch(st, isInitial: false);
    }
  }

  // ------------------------------------------------------------ receiving

  void handleJson(String raw) {
    Map<String, dynamic> m;
    try {
      m = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final type = m['@type'] as String?;

    switch (type) {
      case 'error':
        final rawMsg = m['message'] as String? ?? 'Неизвестная ошибка';
        // ignore: avoid_print
        print('[tdlib] ERROR: $rawMsg');
        _ui.send({'type': 'error', 'message': _translateError(rawMsg)});
        return;
      case 'updateAuthorizationState':
        final state = m['authorization_state'] as Map<String, dynamic>;
        final stateType = state['@type'] as String;
        // ignore: avoid_print
        print('[tdlib] auth: $stateType');
        _ui.send({
          'type': 'auth',
          'state': stateType,
          'link': state['link'],
          'codeInfo': state['code_info'],
          'passwordHint': state['password_hint'],
        });
        switch (stateType) {
          case 'authorizationStateWaitTdlibParameters':
            if (!_paramsSent) _sendTdlibParameters();
          case 'authorizationStateWaitEncryptionKey':
            _send({'@type': 'checkDatabaseEncryptionKey', 'encryption_key': ''});
          case 'authorizationStateWaitPhoneNumber':
            // Запрашиваем QR-код для удобного и безопасного входа
            _send({'@type': 'requestQrCodeAuthentication'});
          case 'authorizationStateReady':
            _send({'@type': 'getMe'});
            _send({'@type': 'getChats', 'limit': 50});
        }
        return;
      case 'user':
        final id = m['id'] as int?;
        if (id != null) {
          _users[id] = m;
          _myId = id;
          _chatsDirty = true;
          _ui.send({
            'type': 'me',
            'user': {
              'id': id,
              'first_name': m['first_name'] as String? ?? '',
              'last_name': m['last_name'] as String? ?? '',
              'username': (m['usernames']?['active_usernames'] as List?)?.firstOrNull ?? m['username'] as String? ?? '',
              'phone_number': m['phone_number'] as String? ?? '',
            },
          });
        }
        return;
      case 'updateUser':
        final user = m['user'] as Map<String, dynamic>?;
        final id = user?['id'] as int?;
        if (id != null) {
          _users[id] = user!;
          _chatsDirty = true;
          if (_myId == id) {
            _ui.send({
              'type': 'me',
              'user': {
                'id': id,
                'first_name': user['first_name'] as String? ?? '',
                'last_name': user['last_name'] as String? ?? '',
                'username': (user['usernames']?['active_usernames'] as List?)?.firstOrNull ?? user['username'] as String? ?? '',
                'phone_number': user['phone_number'] as String? ?? '',
              },
            });
          }
        }
        return;
      case 'chats':
        final extra = m['@extra'] as Map<String, dynamic>?;
        if (extra?['action'] == 'searchChats') {
          final ids = (m['chat_ids'] as List?)?.cast<int>() ?? [];
          _ui.send({'type': 'searchResults', 'query': extra?['query'] ?? '', 'chatIds': ids});
          for (final id in ids) {
            if (!_chats.containsKey(id)) {
              _send({'@type': 'getChat', 'chat_id': id});
            }
          }
        }
        return;
      case 'updateFile':
        final file = m['file'] as Map<String, dynamic>?;
        if (file != null) {
          final fileId = file['id'] as int?;
          final local = file['local'] as Map<String, dynamic>?;
          if (fileId != null && local != null) {
            final isDone = local['is_downloading_completed'] as bool? ?? false;
            final isActive = local['is_downloading_active'] as bool? ?? false;
            final path = local['path'] as String? ?? '';
            if (isDone && path.isNotEmpty) {
              // ignore: avoid_print
              print('[td_worker] File download complete: fileId=$fileId, path=$path');
              _downloadingFiles.remove(fileId);
              _downloadedFiles[fileId] = path;
              _chatsDirty = true;
              for (final st in _chats.values) {
                if (st.history.isNotEmpty) {
                  _dirtyHistories.add(st.chat['id'].toString());
                }
              }
            } else if (isActive) {
              if (_downloadingFiles.add(fileId)) {
                // ignore: avoid_print
                print('[td_worker] File download active: fileId=$fileId');
                for (final st in _chats.values) {
                  if (st.history.isNotEmpty) {
                    _dirtyHistories.add(st.chat['id'].toString());
                  }
                }
              }
            } else if (!isDone && !isActive) {
              _downloadingFiles.remove(fileId);
            }
          }
        }
        return;
      case 'updateChatPhoto':
        final chatId = m['chat_id'] as int?;
        final photo = m['photo'] as Map<String, dynamic>?;
        if (chatId != null) {
          final st = _chatById(chatId);
          if (st != null) {
            st.chat['photo'] = photo;
            if (photo?['small'] != null) {
              _downloadFileIfNeeded(photo!['small'] as Map<String, dynamic>?);
            }
            _chatsDirty = true;
          }
        }
        return;
      case 'updateChatTitle':
        final st = _chatById(m['chat_id'] as int?);
        if (st != null) {
          st.chat['title'] = m['title'];
          _chatsDirty = true;
        }
        return;
      case 'updateNewChat':
      case 'chat':
        final chat = (m['chat'] ?? m) as Map<String, dynamic>;
        final id = chat['id'] as int?;
        if (id == null || chat['title'] == null) return;
        final st = _chats.putIfAbsent(
          id,
          () => _ChatState(
            chat: chat,
            unread: chat['unread_count'] as int? ?? 0,
          ),
        );
        st.chat = chat;
        _chatsDirty = true;
        final extra = m['@extra'] as Map<String, dynamic>?;
        if (extra?['action'] == 'openUsername' || extra?['action'] == 'createGroup') {
          _ui.send({'type': 'selectChat', 'chatId': id.toString()});
        }
        return;
      case 'updateChatLastMessage':
        final st = _chatById(m['chat_id'] as int?);
        final lm = m['last_message'] as Map<String, dynamic>?;
        if (st != null && lm != null) {
          st.last = lm;
          _chatsDirty = true;
        }
        return;
      case 'updateChatReadInbox':
        final st = _chatById(m['chat_id'] as int?);
        if (st != null) {
          st.unread = (m['unread_count'] as int?) ?? 0;
          _chatsDirty = true;
        }
        return;
      case 'updateNewMessage':
        final msg = m['message'] as Map<String, dynamic>?;
        if (msg == null) return;
        final chatId = msg['chat_id'] as int;
        final st = _chatById(chatId);
        if (st != null) {
          st.last = msg;
          _chatsDirty = true;
          if (st.history.isNotEmpty) {
            final newId = msg['id'] as int;
            if (!st.history.any((e) => e['id'] == newId)) {
              st.history.insert(0, msg);
              st.history.sort((a, b) => (b['id'] as int).compareTo(a['id'] as int));
              if (st.oldestId == 0 || newId < st.oldestId) st.oldestId = newId;
              _dirtyHistories.add(chatId.toString());
            }
          }
        }
        return;
      case 'updateDeleteMessages':
        final chatId = m['chat_id'] as int?;
        final ids = (m['message_ids'] as List?)?.cast<int>().toSet();
        if (chatId != null && ids != null && ids.isNotEmpty) {
          final st = _chatById(chatId);
          if (st != null) {
            st.history.removeWhere((msg) => ids.contains(msg['id']));
            _dirtyHistories.add(chatId.toString());
          }
        }
        return;
      case 'messages':
        final extra = m['@extra'] as Map<String, dynamic>?;
        final action = extra?['action'] as String?;
        final extraChatId = extra?['chat_id'] as int?;
        final list = m['messages'] as List?;

        // ignore: avoid_print
        print('[worker] got messages for chat $extraChatId: count=${list?.length}, action=$action');

        if (extraChatId == null) return;
        final st = _chatById(extraChatId);
        if (st == null) return;
        st.loadingMore = false;

        if (list == null || list.isEmpty) {
          st.hasMore = false;
          _dirtyHistories.add(st.chat['id'].toString());
          return;
        }

        final page = list.cast<Map<String, dynamic>>().toList();
        final knownIds = st.history.map((e) => e['id']).toSet();
        final newItems = page.where((e) => !knownIds.contains(e['id'])).toList();

        if (st.history.isEmpty) {
          st.history = page;
        } else if (newItems.isNotEmpty) {
          final merged = [...st.history, ...newItems];
          merged.sort((a, b) => (b['id'] as int).compareTo(a['id'] as int));
          st.history = merged;
        }

        if (st.history.isNotEmpty) {
          st.oldestId = st.history.last['id'] as int;
        }

        _dirtyHistories.add(st.chat['id'].toString());

        // AUTO-EXPAND TO AT LEAST 20 MESSAGES:
        // TDLib getChatHistory often returns only 1 message from local cache on first call
        // while initiating network download from Telegram MTProto servers.
        // We chain requests until we have at least 20 messages or history is exhausted.
        if (action == 'history' && st.history.length < 20 && st.hasMore) {
          if (newItems.isEmpty && page.isNotEmpty) {
            Timer(const Duration(milliseconds: 600), () {
              if (st.history.length < 20 && st.hasMore) {
                _fetchHistoryBatch(st, isInitial: true);
              }
            });
          } else if (newItems.isNotEmpty) {
            _fetchHistoryBatch(st, isInitial: true);
          }
        }
        return;
    }
  }

  _ChatState? _chatById(int? id) => id == null ? null : _chats[id];

  // ------------------------------------------------------------ tdlib api

  void _send(Map<String, dynamic> request) => _ffi.send(request);

  /// Плоская форма setTdlibParameters: работает и на 1.8.0, и на 1.8.68
  /// (лишние поля новые версии молча игнорируют).
  void _sendTdlibParameters() {
    _paramsSent = true;
    _send({
      '@type': 'setTdlibParameters',
      'use_test_dc': false,
      'database_directory': _dbDir,
      'files_directory': _filesDir,
      'database_encryption_key': '',
      'use_file_database': true,
      'use_chat_info_database': true,
      'use_message_database': true,
      'use_secret_chats': false,
      'api_id': TgCredentials.apiId,
      'api_hash': TgCredentials.apiHash,
      'system_language_code': 'ru',
      'device_model': 'Desktop (${Platform.operatingSystem})',
      'system_version': Platform.operatingSystemVersion,
      'application_version': TgCredentials.appVersion,
    });
  }

  static String _translateError(String raw) {
    if (raw.contains('PHONE_CODE_INVALID')) {
      return 'Неверный код подтверждения.';
    }
    if (raw.contains('PHONE_CODE_EXPIRED')) {
      return 'Срок действия кода истек. Запросите новый код.';
    }
    if (raw.contains('PHONE_NUMBER_INVALID')) {
      return 'Неверный номер телефона. Введите в международном формате (+7...).';
    }
    if (raw.contains('PASSWORD_HASH_INVALID')) {
      return 'Неверный облачный пароль (2FA).';
    }
    if (raw.contains('FLOOD_WAIT')) {
      return 'Слишком много попыток. Пожалуйста, подождите немного.';
    }
    return raw;
  }

  // ------------------------------------------------------------ snapshots

  void flush() {
    try {
      if (_chatsDirty) {
        _chatsDirty = false;
        final built = _buildChats();
        _log('flush chats: ${built.length}');
        _ui.send({'type': 'chats', 'chats': built});
      }
      if (_dirtyHistories.isNotEmpty) {
        final payload = <String, TgChatHistory>{};
        for (final key in _dirtyHistories) {
          final st = _chatById(int.tryParse(key));
          if (st == null) continue;
          try {
            payload[key] = TgChatHistory(
              messages: _buildDisplay(st),
              hasMore: st.hasMore,
            );
          } catch (e, stack) {
            // ignore: avoid_print
            print('[worker] error in _buildDisplay for chat $key: $e\n$stack');
          }
        }
        _dirtyHistories.clear();
        if (payload.isNotEmpty) {
          _log('flush history: ${payload.keys.toList()}');
          _ui.send({'type': 'history', 'messages': payload});
        }
      }
    } catch (e, stack) {
      // ignore: avoid_print
      print('[worker] error in flush: $e\n$stack');
    }
  }

  List<TgChat> _buildChats() {
    final rows = _chats.values.toList()
      ..removeWhere((st) => st.chat['type']?['@type'] == 'chatTypeSecret')
      ..sort((a, b) => (b.last?['date'] as int? ?? 0)
          .compareTo(a.last?['date'] as int? ?? 0));
    final out = <TgChat>[];
    for (final st in rows) {
      try {
        out.add(_toTgChat(st));
      } catch (e, stack) {
        // ignore: avoid_print
        print('[worker] error in _toTgChat for chat ${st.chat['id']}: $e\n$stack');
        out.add(TgChat(
          id: st.chat['id'].toString(),
          title: st.chat['title'] as String? ?? 'Chat',
          avatarEmoji: '?',
          avatarColor: 0xFF65AADD,
          time: '',
          sender: '',
          preview: '',
          headerSubtitle: 'last seen recently',
        ));
      }
    }
    return out;
  }

  TgChat _toTgChat(_ChatState st) {
    final title = st.chat['title'] as String? ?? 'Chat';
    final last = st.last;
    final fromMe = last != null && _isFromMe(last);

    String sender = '';
    String preview = '';
    String time = '';
    if (last != null) {
      sender = fromMe ? '' : _senderName(last);
      preview = TdContent.fullText(last);
      time = formatTime(last['date'] as int? ?? 0);
    }

    Map<String, dynamic>? photoFile;
    final chatPhoto = st.chat['photo'] as Map<String, dynamic>?;
    if (chatPhoto != null && chatPhoto['small'] != null) {
      photoFile = chatPhoto['small'] as Map<String, dynamic>?;
    } else {
      final chatType = st.chat['type'] as Map<String, dynamic>?;
      if (chatType?['@type'] == 'chatTypePrivate') {
        final userId = chatType?['user_id'] as int?;
        if (userId != null) {
          final u = _users[userId];
          final profilePhoto = u?['profile_photo'] as Map<String, dynamic>?;
          if (profilePhoto != null && profilePhoto['small'] != null) {
            photoFile = profilePhoto['small'] as Map<String, dynamic>?;
          }
        }
      }
    }

    String avatarPath = '';
    if (photoFile != null) {
      final fileId = photoFile['id'] as int?;
      final local = photoFile['local'] as Map<String, dynamic>?;
      final localPath = local?['path'] as String? ?? '';
      final isDone = local?['is_downloading_completed'] as bool? ?? false;
      final downloaded = fileId != null ? _downloadedFiles[fileId] : null;

      if (downloaded != null && downloaded.isNotEmpty && File(downloaded).existsSync()) {
        avatarPath = downloaded;
      } else if (isDone && localPath.isNotEmpty && File(localPath).existsSync()) {
        avatarPath = localPath;
      } else {
        _downloadFileIfNeeded(photoFile);
      }
    }

    return TgChat(
      id: st.chat['id'].toString(),
      title: title,
      avatarEmoji: TdContent.initials(title),
      avatarColor: TdContent.colorFor(title),
      avatarPath: avatarPath,
      sender: sender,
      preview: preview,
      time: time,
      headerSubtitle: 'last seen recently',
      verified: st.chat['is_verified'] as bool? ?? false,
      unread: st.unread,
      unreadOwn: fromMe,
    );
  }

  bool _isFromMe(Map<String, dynamic> msg) {
    final sender = msg['sender_id'];
    return sender != null && sender['user_id'] == _myId;
  }

  String _senderName(Map<String, dynamic> msg) {
    final sender = msg['sender_id'];
    if (sender == null) return '';
    final userId = sender['user_id'] as int?;
    if (userId != null) {
      final user = _users[userId];
      if (user != null) return (user['first_name'] as String? ?? '').trim();
      return '';
    }
    final chatId = sender['chat_id'] as int?;
    if (chatId != null) {
      return _chats[chatId]?.chat['title'] as String? ?? '';
    }
    return '';
  }

  void _downloadFileIfNeeded(dynamic file, {int priority = 20}) {
    if (file is! Map) return;
    final local = file['local'] is Map ? file['local'] as Map : null;
    final isDone = local?['is_downloading_completed'] == true;
    final path = (local?['path'] as String?) ?? '';
    if (!isDone || path.isEmpty) {
      final fileId = (file['id'] as num?)?.toInt();
      if (fileId != null && fileId > 0) {
        if (!_downloadingFiles.contains(fileId)) {
          _downloadingFiles.add(fileId);
          // ignore: avoid_print
          print('[td_worker] Auto-downloading file: fileId=$fileId, priority=$priority');
          _send({'@type': 'downloadFile', 'file_id': fileId, 'priority': priority, 'synchronous': false});
        }
      }
    }
  }

  /// Готовый список для UI: даты + разделитель непрочитанных.
  List<TgMessage> _buildDisplay(_ChatState st) {
    final oldestFirst = st.history.reversed.toList();
    final out = <TgMessage>[];
    DateTime? prevDay;
    for (final msg in oldestFirst) {
      try {
        final date = DateTime.fromMillisecondsSinceEpoch(
            ((msg['date'] as num?)?.toInt() ?? 0) * 1000);
        final day = DateTime(date.year, date.month, date.day);
        if (prevDay == null || day != prevDay) {
          out.add(TgMessage(kind: MessageKind.date, text: dayLabel(day)));
          prevDay = day;
        }

        final kind = TdContent.messageKind(msg);
        String mediaPath = '';
        String thumbnailPath = '';
        int duration = 0;
        String fileName = '';
        String fileSize = '';
        int fileId = 0;
        int thumbFileId = 0;
        int width = 0;
        int height = 0;

        bool isDownloading = false;
        bool isDownloaded = false;

        final content = msg['content'] is Map ? msg['content'] as Map : null;
        if (kind == MessageKind.voice) {
          final vn = content?['voice_note'] is Map ? content!['voice_note'] as Map : null;
          duration = (vn?['duration'] as num?)?.toInt() ?? 0;
          final voice = vn?['voice'] is Map ? vn!['voice'] as Map : null;
          fileId = (voice?['id'] as num?)?.toInt() ?? 0;
          final local = voice?['local'] is Map ? voice!['local'] as Map : null;
          mediaPath = (local?['path'] as String?) ?? '';
          _downloadFileIfNeeded(voice);
        } else if (kind == MessageKind.document) {
          final doc = content?['document'] is Map ? content!['document'] as Map : null;
          fileName = (doc?['file_name'] as String?) ?? 'Файл';
          final file = doc?['document'] is Map ? doc!['document'] as Map : null;
          fileId = (file?['id'] as num?)?.toInt() ?? 0;
          fileSize = TdContent.formatBytes((file?['size'] as num?)?.toInt() ?? 0);
          final local = file?['local'] is Map ? file!['local'] as Map : null;
          final localPath = (local?['path'] as String?) ?? '';
          final isCompleted = local?['is_downloading_completed'] == true;
          final downloadedDoc = fileId != 0 ? _downloadedFiles[fileId] : null;
          if (downloadedDoc != null && downloadedDoc.isNotEmpty && File(downloadedDoc).existsSync() && File(downloadedDoc).lengthSync() > 0) {
            mediaPath = downloadedDoc;
            isDownloaded = true;
          } else if (isCompleted && localPath.isNotEmpty && File(localPath).existsSync() && File(localPath).lengthSync() > 0) {
            mediaPath = localPath;
            isDownloaded = true;
          } else {
            isDownloading = _downloadingFiles.contains(fileId) || local?['is_downloading_active'] == true;
          }
        } else if (kind == MessageKind.image) {
          final photo = content?['photo'] is Map ? content!['photo'] as Map : null;
          final sizes = photo?['sizes'] is List ? photo!['sizes'] as List : null;
          if (sizes != null && sizes.isNotEmpty) {
            for (final sz in sizes.reversed) {
              if (sz is! Map) continue;
              final file = sz['photo'] is Map ? sz['photo'] as Map : null;
              final fId = (file?['id'] as num?)?.toInt();
              final local = file?['local'] is Map ? file!['local'] as Map : null;
              final localPath = (local?['path'] as String?) ?? '';
              final downloaded = fId != null ? _downloadedFiles[fId] : null;
              if (downloaded != null && downloaded.isNotEmpty && File(downloaded).existsSync() && File(downloaded).lengthSync() > 0) {
                mediaPath = downloaded;
                if (fId != null) fileId = fId;
                isDownloaded = true;
                break;
              } else if (local?['is_downloading_completed'] == true && localPath.isNotEmpty && File(localPath).existsSync() && File(localPath).lengthSync() > 0) {
                mediaPath = localPath;
                if (fId != null) fileId = fId;
                isDownloaded = true;
                break;
              }
            }
            final target = sizes.length > 1 ? sizes[sizes.length - 2] : sizes.last;
            if (target is Map) {
              final file = target['photo'] is Map ? target['photo'] as Map : null;
              if (fileId == 0 && file?['id'] != null) {
                fileId = (file!['id'] as num?)?.toInt() ?? 0;
              }
              final fLocal = file?['local'] is Map ? file!['local'] as Map : null;
              if (!isDownloaded) {
                _downloadFileIfNeeded(file);
                isDownloading = _downloadingFiles.contains(fileId) || fLocal?['is_downloading_active'] == true;
              }
            }
          }
        } else if (kind == MessageKind.video) {
          final vid = (content?['video'] ?? content?['animation'] ?? content?['video_note']) is Map
              ? (content?['video'] ?? content?['animation'] ?? content?['video_note']) as Map
              : null;
          duration = (vid?['duration'] as num?)?.toInt() ?? 0;
          fileName = (vid?['file_name'] as String?) ?? 'video.mp4';
          width = (vid?['width'] as num?)?.toInt() ?? 0;
          height = (vid?['height'] as num?)?.toInt() ?? 0;

          final thumb = vid?['thumbnail'] is Map ? vid!['thumbnail'] as Map : null;
          final thumbFile = thumb?['file'] is Map ? thumb!['file'] as Map : null;
          if (thumbFile != null) {
            thumbFileId = (thumbFile['id'] as num?)?.toInt() ?? 0;
            final tLocal = thumbFile['local'] is Map ? thumbFile['local'] as Map : null;
            final tLocalPath = (tLocal?['path'] as String?) ?? '';
            final downloadedThumb = thumbFileId != 0 ? _downloadedFiles[thumbFileId] : null;
            if (downloadedThumb != null && downloadedThumb.isNotEmpty && File(downloadedThumb).existsSync()) {
              thumbnailPath = downloadedThumb;
            } else if (tLocal?['is_downloading_completed'] == true && tLocalPath.isNotEmpty && File(tLocalPath).existsSync() && File(tLocalPath).lengthSync() > 0) {
              thumbnailPath = tLocalPath;
            } else {
              _downloadFileIfNeeded(thumbFile);
            }
          }

          final videoFile = (vid?['video'] ?? vid?['animation']) is Map
              ? (vid?['video'] ?? vid?['animation']) as Map
              : null;
          if (videoFile != null) {
            fileId = (videoFile['id'] as num?)?.toInt() ?? 0;
            fileSize = TdContent.formatBytes((videoFile['size'] as num?)?.toInt() ?? 0);
            final vLocal = videoFile['local'] is Map ? videoFile['local'] as Map : null;
            final vLocalPath = (vLocal?['path'] as String?) ?? '';
            final isCompleted = vLocal?['is_downloading_completed'] == true;
            final downloadedVideo = fileId != 0 ? _downloadedFiles[fileId] : null;

            if (downloadedVideo != null && downloadedVideo.isNotEmpty && File(downloadedVideo).existsSync() && File(downloadedVideo).lengthSync() > 0) {
              mediaPath = downloadedVideo;
              isDownloaded = true;
            } else if (isCompleted && vLocalPath.isNotEmpty && File(vLocalPath).existsSync() && File(vLocalPath).lengthSync() > 0) {
              mediaPath = vLocalPath;
              isDownloaded = true;
            } else {
              // Автоматическая загрузка видео в фоне для открытого чата
              _downloadFileIfNeeded(videoFile);
              isDownloading = _downloadingFiles.contains(fileId) || vLocal?['is_downloading_active'] == true;
            }
          }
        }

        out.add(TgMessage(
          id: (msg['id'] as num?)?.toInt() ?? 0,
          kind: kind,
          text: TdContent.fullText(msg),
          time: formatTime((msg['date'] as num?)?.toInt() ?? 0),
          outgoing: msg['is_outgoing'] == true,
          read: msg['contains_unread_mention'] != true,
          mediaPath: mediaPath,
          thumbnailPath: thumbnailPath,
          duration: duration,
          fileName: fileName,
          fileSize: fileSize,
          fileId: fileId,
          thumbFileId: thumbFileId,
          width: width,
          height: height,
          isDownloading: isDownloading,
          isDownloaded: isDownloaded,
        ));
      } catch (e, stack) {
        // ignore: avoid_print
        print('[worker] error in _buildDisplay for msg ${msg['id']}: $e\n$stack');
      }
    }
    if (st.unread > 0 && st.unread < out.length) {
      out.insert(out.length - st.unread,
          const TgMessage(kind: MessageKind.unreadDivider, text: 'Unread messages'));
    }
    return out;
  }
}
