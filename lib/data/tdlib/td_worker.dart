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
  final Map<int, Map<String, dynamic>> _allMessages = {};
  final Set<int> _requestedReplyMessages = {};
  int _myId = 0;
  int _myAvatarFileId = 0;
  final Map<int, String> _postPhotoFiles = {};
  bool _authorized = false;
  bool _paramsSent = false;
  bool _chatsDirty = false;
  final Set<String> _dirtyHistories = {};
  final Map<int, Map<String, dynamic>> _callProtocols = {};
  int? _currentOpenChatId;
  final Set<int> _contactUserIds = {};
  bool _contactsDirty = false;

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
      case 'logOut':
        _send({'@type': 'logOut'});
      case 'getMe':
        _send({'@type': 'getMe', '@extra': {'action': 'getMe'}});
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
        final ext = path.toLowerCase().split('.').last;
        final isImage = const ['jpg', 'jpeg', 'png', 'webp', 'bmp'].contains(ext);
        if (isImage) {
          _send({
            '@type': 'sendMessage',
            'chat_id': chatId,
            'input_message_content': {
              '@type': 'inputMessagePhoto',
              'photo': {
                '@type': 'inputPhoto',
                'photo': {
                  '@type': 'inputFileLocal',
                  'path': path,
                },
              },
              'caption': {'@type': 'formattedText', 'text': caption},
            },
          });
        } else {
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
        }
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
      case 'deleteMessages':
        final chatId = cmd['chatId'] as int;
        final messageIds = (cmd['messageIds'] as List).cast<int>();
        final revoke = cmd['revoke'] as bool? ?? true;
        _send({
          '@type': 'deleteMessages',
          'chat_id': chatId,
          'message_ids': messageIds,
          'revoke': revoke,
        });
        final st = _chatById(chatId);
        if (st != null) {
          st.history.removeWhere((m) => messageIds.contains(m['id']));
          _dirtyHistories.add(chatId.toString());
        }
      case 'clearHistory':
        final chatId = cmd['chatId'] as int;
        final revoke = cmd['revoke'] as bool? ?? true;
        _send({
          '@type': 'deleteChatHistory',
          'chat_id': chatId,
          'remove_from_chat_list': false,
          'revoke': revoke,
        });
        final st = _chatById(chatId);
        if (st != null) {
          st.history.clear();
          st.oldestId = 0;
          _dirtyHistories.add(chatId.toString());
        }
      case 'deleteChat':
        final chatId = cmd['chatId'] as int;
        _send({
          '@type': 'deleteChatHistory',
          'chat_id': chatId,
          'remove_from_chat_list': true,
          'revoke': true,
        });
        _send({
          '@type': 'closeChat',
          'chat_id': chatId,
        });
        _chats.remove(chatId);
        _chatsDirty = true;
      case 'createCall':
        final userId = cmd['userId'] as int?;
        if (userId != null) {
          // ignore: avoid_print
          print('[worker] createCall user_id=$userId');
          _send({
            '@type': 'createCall',
            'user_id': userId,
            'protocol': {
              '@type': 'callProtocol',
              'udp_p2p': true,
              'udp_reflector': true,
              'min_layer': 65,
              'max_layer': 92,
              'library_versions': ['3.0.0', '2.7.7', '2.4.4', '1.2.0'],
            },
            'is_video': false,
          });
        }
      case 'discardCall':
        final callId = cmd['callId'] as int?;
        final duration = (cmd['duration'] as num?)?.toInt() ?? 0;
        if (callId != null) {
          // ignore: avoid_print
          print('[worker] discardCall call_id=$callId duration=$duration');
          _send({
            '@type': 'discardCall',
            'call_id': callId,
            'is_disconnected': false,
            'duration': duration,
            'is_video': false,
            'connection_id': 0,
          });
        }
      case 'acceptCall':
        final callId = cmd['callId'] as int?;
        if (callId != null) {
          final savedProto = _callProtocols[callId];
          final proto = savedProto ?? {
            '@type': 'callProtocol',
            'udp_p2p': true,
            'udp_reflector': true,
            'min_layer': 65,
            'max_layer': 92,
            'library_versions': ['3.0.0', '2.7.7', '2.4.4', '1.2.0'],
          };
          // ignore: avoid_print
          print('[worker] acceptCall call_id=$callId with proto: $proto');
          _send({
            '@type': 'acceptCall',
            'call_id': callId,
            'protocol': proto,
          });
        }
      case 'syncProfile':
        if (_myId > 0 && _users.containsKey(_myId)) {
          _syncUserProfile(_users[_myId]!);
        } else {
          _send({'@type': 'getMe', '@extra': {'action': 'getMe'}});
        }
      case 'getContacts':
        _send({'@type': 'getContacts', '@extra': {'action': 'getContacts'}});
      case 'createPrivateChat':
        final uid = cmd['userId'] as int?;
        if (uid != null) {
          _send({
            '@type': 'createPrivateChat',
            'user_id': uid,
            'force': false,
            '@extra': {'action': 'openPrivateChat'},
          });
        }
    }
  }

  void _syncUserProfile(Map<String, dynamic> userMap) {
    if (_myId == 0) return;

    // 1. Check profile photo on user object
    final profilePhoto = userMap['profile_photo'] as Map<String, dynamic>?;
    if (profilePhoto != null) {
      final big = profilePhoto['big'] as Map<String, dynamic>?;
      final small = profilePhoto['small'] as Map<String, dynamic>?;
      final target = big ?? small;
      if (target != null) {
        final fId = (target['id'] as num?)?.toInt() ?? 0;
        if (fId > 0) {
          _myAvatarFileId = fId;
          final local = target['local'] as Map<String, dynamic>?;
          final isDone = local?['is_downloading_completed'] == true;
          final path = (local?['path'] as String?) ?? '';
          if (isDone && path.isNotEmpty && File(path).existsSync()) {
            // ignore: avoid_print
            print('[worker] user profile avatar already downloaded: $path');
            _ui.send({'type': 'myAvatar', 'path': path});
          } else {
            // ignore: avoid_print
            print('[worker] downloading user profile avatar fileId=$fId');
            _downloadFileIfNeeded(target, priority: 32);
          }
        }
      }
    } else {
      // Clear any previous mock avatar if user has no photo
      _ui.send({'type': 'myAvatar', 'path': ''});
    }

    // 2. Request user full info for bio & personal_chat_id
    // ignore: avoid_print
    print('[worker] requesting getUserFullInfo for user_id=$_myId');
    _send({'@type': 'getUserFullInfo', 'user_id': _myId});

    // 3. Request user profile photos history
    // ignore: avoid_print
    print('[worker] requesting getUserProfilePhotos for user_id=$_myId');
    _send({
      '@type': 'getUserProfilePhotos',
      'user_id': _myId,
      'offset': 0,
      'limit': 50,
      '@extra': {'action': 'profilePhotos', 'user_id': _myId},
    });
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
        for (final st in _chats.values) {
          st.loadingMore = false;
        }
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
            _authorized = true;
            _send({'@type': 'getMe', '@extra': {'action': 'getMe'}});
            _send({'@type': 'getChats', 'limit': 50});
            _send({'@type': 'getContacts', '@extra': {'action': 'getContacts'}});
        }
        return;
      case 'user':
        final extra = m['@extra'] as Map<String, dynamic>?;
        final id = m['id'] as int?;
        if (id != null) {
          _users[id] = m;
          if (_contactUserIds.contains(id)) {
            _contactsDirty = true;
          }
          final isMe = extra?['action'] == 'getMe' || (_myId > 0 && id == _myId);
          if (isMe) {
            _myId = id;
            _chatsDirty = true;
            final fn = m['first_name'] as String? ?? '';
            final ln = m['last_name'] as String? ?? '';
            final username = (m['usernames']?['active_usernames'] as List?)?.firstOrNull ?? m['username'] as String? ?? '';
            final phone = m['phone_number'] as String? ?? '';
            _ui.send({
              'type': 'me',
              'user': {
                'id': id,
                'first_name': fn,
                'last_name': ln,
                'username': username,
                'phone_number': phone,
              },
            });
            _syncUserProfile(m);
          }
        }
        return;
      case 'updateUser':
        final user = m['user'] as Map<String, dynamic>?;
        final id = user?['id'] as int?;
        if (id != null) {
          _users[id] = user!;
          _chatsDirty = true;
          if (_contactUserIds.contains(id)) {
            _contactsDirty = true;
          }
          if (_myId == id) {
            final fn = user['first_name'] as String? ?? '';
            final ln = user['last_name'] as String? ?? '';
            final username = (user['usernames']?['active_usernames'] as List?)?.firstOrNull ?? user['username'] as String? ?? '';
            final phone = user['phone_number'] as String? ?? '';
            _ui.send({
              'type': 'me',
              'user': {
                'id': id,
                'first_name': fn,
                'last_name': ln,
                'username': username,
                'phone_number': phone,
              },
            });
            _syncUserProfile(user);
          }
        }
        return;
      case 'users':
        final extra = m['@extra'] as Map<String, dynamic>?;
        if (extra?['action'] == 'getContacts') {
          final userIds = (m['user_ids'] as List?)?.cast<num>().map((n) => n.toInt()).toList() ?? [];
          // ignore: avoid_print
          print('[worker] got contacts from TDLib: count=${userIds.length}');
          _contactUserIds.addAll(userIds);
          for (final uid in userIds) {
            if (!_users.containsKey(uid)) {
              _send({'@type': 'getUser', 'user_id': uid, '@extra': {'action': 'getContactUser'}});
            }
          }
          _contactsDirty = true;
        }
        return;
      case 'updateUserStatus':
        final uid = (m['user_id'] as num?)?.toInt();
        final status = m['status'] as Map<String, dynamic>?;
        if (uid != null && status != null && _users.containsKey(uid)) {
          _users[uid]!['status'] = status;
          if (_contactUserIds.contains(uid)) {
            _contactsDirty = true;
          }
        }
        return;
      case 'userFullInfo':
      case 'updateUserFullInfo':
        final extra = m['@extra'] as Map<String, dynamic>?;
        final userId = (m['user_id'] as num?)?.toInt() ?? (extra?['user_id'] as num?)?.toInt() ?? 0;
        if (_myId == 0 || (userId != 0 && userId != _myId)) {
          // Игнорируем информацию о сторонних пользователях, чтобы не затирать профиль и посты
          return;
        }
        final full = (m['user_full_info'] ?? m) as Map<String, dynamic>;
        final bioObj = full['bio'] as Map<String, dynamic>?;
        final bioText = (bioObj?['text'] as String?) ?? '';
        final personalChatId = (full['personal_chat_id'] as num?)?.toInt() ?? 0;
        // ignore: avoid_print
        print('[worker] userFullInfo for myId=$_myId: bio="$bioText", personalChatId=$personalChatId');
        _ui.send({
          'type': 'userFullInfo',
          'bio': bioText,
          'personalChatId': personalChatId,
        });
        if (personalChatId != 0) {
          _send({
            '@type': 'getChatHistory',
            'chat_id': personalChatId,
            'from_message_id': 0,
            'offset': 0,
            'limit': 30,
            'only_local': false,
            '@extra': {'action': 'personalPosts', 'chat_id': personalChatId},
          });
        }
        return;
      case 'userProfilePhotos':
        final extra = m['@extra'] as Map<String, dynamic>?;
        final targetUserId = (extra?['user_id'] as num?)?.toInt() ?? 0;
        if (_myId == 0 || (targetUserId != 0 && targetUserId != _myId)) {
          return;
        }
        final photos = (m['photos'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final totalCount = (m['total_count'] as num?)?.toInt() ?? photos.length;
        // ignore: avoid_print
        print('[worker] userProfilePhotos count: ${photos.length}, total: $totalCount');
        final postList = <Map<String, dynamic>>[];
        for (int i = 0; i < photos.length; i++) {
          final p = photos[i];
          final photoId = p['id'].toString();
          final addedDate = (p['added_date'] as num?)?.toInt() ?? 0;
          final sizes = (p['sizes'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          String path = '';
          int fileId = 0;
          if (sizes.isNotEmpty) {
            final bigSize = sizes.last;
            final photoFile = bigSize['photo'] as Map<String, dynamic>?;
            if (photoFile != null) {
              fileId = (photoFile['id'] as num?)?.toInt() ?? 0;
              final local = photoFile['local'] as Map<String, dynamic>?;
              final isDone = local?['is_downloading_completed'] == true;
              final localPath = (local?['path'] as String?) ?? '';
              if (isDone && localPath.isNotEmpty && File(localPath).existsSync()) {
                path = localPath;
              } else if (fileId > 0) {
                _postPhotoFiles[fileId] = photoId;
                _downloadFileIfNeeded(photoFile, priority: 20);
              }
            }
          }
          postList.add({
            'id': photoId,
            'text': i == 0 ? 'Фото профиля' : 'Архивное фото профиля',
            'mediaPath': path,
            'date': addedDate,
            'views': 0,
            'likes': 0,
            'fileId': fileId,
            'isArchived': i > 0,
          });
        }
        _ui.send({
          'type': 'profilePhotos',
          'photos': postList,
        });
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
              if (fileId == _myAvatarFileId) {
                // ignore: avoid_print
                print('[worker] My avatar downloaded: $path');
                _ui.send({'type': 'myAvatar', 'path': path});
              }
              if (_postPhotoFiles.containsKey(fileId)) {
                final pId = _postPhotoFiles[fileId]!;
                _ui.send({
                  'type': 'postMediaDownloaded',
                  'postId': pId,
                  'path': path,
                });
              }
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
        if (extra?['action'] == 'openUsername' || extra?['action'] == 'createGroup' || extra?['action'] == 'openPrivateChat') {
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
        final newId = msg['id'] as int;
        _allMessages[newId] = msg;
        final chatId = msg['chat_id'] as int;
        final st = _chatById(chatId);
        if (st != null) {
          st.last = msg;
          _chatsDirty = true;
          if (st.history.isNotEmpty) {
            if (!st.history.any((e) => e['id'] == newId)) {
              st.history.insert(0, msg);
              st.history.sort((a, b) => (b['id'] as int).compareTo(a['id'] as int));
              if (st.oldestId == 0 || newId < st.oldestId) st.oldestId = newId;
              _dirtyHistories.add(chatId.toString());
            }
          }
        }
        final isOutgoing = msg['is_outgoing'] == true || _isFromMe(msg);
        if (!isOutgoing && _authorized) {
          final notif = st?.chat['notification_settings'] as Map<String, dynamic>?;
          final muteFor = (notif?['mute_for'] as num?)?.toInt() ?? 0;
          if (muteFor <= 0) {
            final senderTitle = st != null ? (st.chat['title'] as String? ?? 'Telegram') : 'Telegram';
            final text = TdContent.fullText(msg);
            _ui.send({
              'type': 'notification',
              'title': senderTitle,
              'body': text.isNotEmpty ? text : 'Новое сообщение',
              'chatId': chatId.toString(),
            });
          }
        }
        return;
      case 'updateMessageSendSucceeded':
        final msg = m['message'] as Map<String, dynamic>?;
        final oldId = m['old_message_id'] as int?;
        if (msg != null) {
          final newId = msg['id'] as int;
          final chatId = msg['chat_id'] as int;
          _allMessages[newId] = msg;
          if (oldId != null) _allMessages.remove(oldId);
          final st = _chatById(chatId);
          if (st != null) {
            if (oldId != null) {
              final idx = st.history.indexWhere((e) => e['id'] == oldId);
              if (idx != -1) {
                st.history[idx] = msg;
              } else if (!st.history.any((e) => e['id'] == newId)) {
                st.history.insert(0, msg);
              }
            } else if (!st.history.any((e) => e['id'] == newId)) {
              st.history.insert(0, msg);
            }
            st.history.sort((a, b) => (b['id'] as int).compareTo(a['id'] as int));
            _dirtyHistories.add(chatId.toString());
          }
        }
        return;
      case 'updateMessageContent':
        final chatId = m['chat_id'] as int?;
        final msgId = m['message_id'] as int?;
        final newContent = m['new_content'] as Map<String, dynamic>?;
        if (chatId != null && msgId != null && newContent != null) {
          final existing = _allMessages[msgId];
          if (existing != null) {
            existing['content'] = newContent;
            final st = _chatById(chatId);
            if (st != null) {
              final idx = st.history.indexWhere((e) => e['id'] == msgId);
              if (idx != -1) {
                st.history[idx]['content'] = newContent;
              }
              _dirtyHistories.add(chatId.toString());
            }
          }
        }
        return;
      case 'message':
        final msgId = m['id'] as int?;
        if (msgId != null) {
          _allMessages[msgId] = m;
          final cId = m['chat_id'] as int?;
          if (cId != null) {
            _dirtyHistories.add(cId.toString());
          }
        }
        return;
      case 'updateDeleteMessages':
        final chatId = m['chat_id'] as int?;
        final ids = (m['message_ids'] as List?)?.cast<int>().toSet();
        if (chatId != null && ids != null && ids.isNotEmpty) {
          for (final id in ids) {
            _allMessages.remove(id);
          }
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

        if (action == 'personalPosts') {
          final msgs = (m['messages'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          // ignore: avoid_print
          print('[worker] got personal channel posts: count=${msgs.length}');
          final channelPosts = <Map<String, dynamic>>[];
          for (final msg in msgs) {
            final postId = msg['id'].toString();
            final date = (msg['date'] as num?)?.toInt() ?? 0;
            final text = TdContent.fullText(msg);
            String mediaPath = '';
            int fileId = 0;
            final kind = TdContent.messageKind(msg);
            if (kind == MessageKind.image) {
              final content = msg['content'] as Map<String, dynamic>?;
              final photo = content?['photo'] as Map<String, dynamic>?;
              final sizes = (photo?['sizes'] as List?)?.cast<Map<String, dynamic>>() ?? [];
              if (sizes.isNotEmpty) {
                final target = sizes.last;
                final file = target['photo'] as Map<String, dynamic>?;
                if (file != null) {
                  fileId = (file['id'] as num?)?.toInt() ?? 0;
                  final local = file['local'] as Map<String, dynamic>?;
                  if (local?['is_downloading_completed'] == true && (local?['path'] as String? ?? '').isNotEmpty) {
                    mediaPath = local!['path'] as String;
                  } else if (fileId > 0) {
                    _postPhotoFiles[fileId] = postId;
                    _downloadFileIfNeeded(file, priority: 25);
                  }
                }
              }
            }
            final interactionInfo = msg['interaction_info'] as Map<String, dynamic>?;
            final viewCount = (interactionInfo?['view_count'] as num?)?.toInt() ?? 0;
            channelPosts.add({
              'id': postId,
              'text': text,
              'mediaPath': mediaPath,
              'date': date,
              'views': viewCount,
              'likes': 0,
              'fileId': fileId,
              'isArchived': false,
            });
          }
          _ui.send({
            'type': 'personalPosts',
            'posts': channelPosts,
          });
          return;
        }

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
        for (final item in page) {
          final id = item['id'] as int?;
          if (id != null) _allMessages[id] = item;
        }
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
          final delayMs = (newItems.isEmpty && page.isNotEmpty) ? 600 : 350;
          Timer(Duration(milliseconds: delayMs), () {
            if (st.history.length < 20 && st.hasMore) {
              _fetchHistoryBatch(st, isInitial: true);
            }
          });
        }
        return;
      case 'call':
        _handleCall(m);
        return;
      case 'updateCall':
        final c = m['call'] as Map<String, dynamic>?;
        if (c != null) _handleCall(c);
        return;
    }
  }

  void _handleCall(Map<String, dynamic> call) {
    final callId = (call['id'] as num?)?.toInt() ?? 0;
    final userId = (call['user_id'] as num?)?.toInt() ?? 0;
    final isOutgoing = call['is_outgoing'] as bool? ?? false;
    final stateObj = call['state'] as Map<String, dynamic>? ?? {};
    final stateType = stateObj['@type'] as String? ?? '';

    // Сохраняем протокол звонка для точного согласования при acceptCall
    final incomingProto = (call['protocol'] as Map<String, dynamic>?) ?? (stateObj['protocol'] as Map<String, dynamic>?);
    if (incomingProto != null) {
      _callProtocols[callId] = incomingProto;
      // ignore: avoid_print
      print('[worker] saved incoming call protocol for call $callId: $incomingProto');
    }

    TgCallState state = TgCallState.pending;
    List<String> emojis = [];
    String discardReason = '';

    if (stateType == 'callStatePending') {
      final isReceived = stateObj['is_received'] as bool? ?? false;
      state = isReceived ? TgCallState.ringing : TgCallState.pending;
    } else if (stateType == 'callStateExchangingKeys') {
      state = TgCallState.exchangingKeys;
    } else if (stateType == 'callStateReady') {
      state = TgCallState.ready;
      final emList = stateObj['emojis'] as List?;
      if (emList != null) {
        emojis = emList.whereType<String>().toList();
      }
    } else if (stateType == 'callStateHangingUp') {
      state = TgCallState.hangingUp;
    } else if (stateType == 'callStateError') {
      state = TgCallState.discarded;
      final err = stateObj['error'] as Map<String, dynamic>?;
      final errMsg = err?['message'] as String? ?? 'Ошибка соединения';
      final errCode = err?['code'];
      // ignore: avoid_print
      print('[worker] callStateError: $errMsg (code: $errCode), full: $stateObj');
      discardReason = errMsg;
    } else if (stateType == 'callStateDiscarded') {
      state = TgCallState.discarded;
      final reasonObj = stateObj['reason'] as Map<String, dynamic>?;
      final reasonType = reasonObj?['@type'] as String? ?? '';
      if (reasonType == 'callDiscardReasonDeclined') {
        discardReason = 'Вызов отклонен';
      } else if (reasonType == 'callDiscardReasonDisconnected') {
        discardReason = 'Связь прервана';
      } else if (reasonType == 'callDiscardReasonHungUp') {
        discardReason = 'Вызов завершен';
      } else if (reasonType == 'callDiscardReasonMissed') {
        discardReason = 'Пропущенный звонок';
      } else {
        discardReason = 'Звонок завершен';
      }
    }

    String callerName = 'Пользователь';
    final user = _users[userId];
    if (user != null) {
      final fn = user['first_name'] as String? ?? '';
      final ln = user['last_name'] as String? ?? '';
      callerName = '$fn $ln'.trim();
      if (callerName.isEmpty) callerName = user['username'] as String? ?? 'Telegram';
    }

    // ignore: avoid_print
    print('[worker] call update: id=$callId user=$userId ($callerName) outgoing=$isOutgoing state=$stateType ($state)');

    final callInfo = TgCallInfo(
      callId: callId,
      userId: userId,
      userName: callerName,
      isOutgoing: isOutgoing,
      state: state,
      rawState: stateType,
      discardReason: discardReason,
      emojis: emojis,
    );

    _ui.send({
      'type': 'callUpdate',
      'call': callInfo,
    });

    if (!isOutgoing && (state == TgCallState.pending || state == TgCallState.ringing)) {
      _ui.send({
        'type': 'incomingCall',
        'call': callInfo,
      });
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
        _contactsDirty = true;
      }
      if (_contactsDirty) {
        _contactsDirty = false;
        _sendContactsToUi();
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

  void _sendContactsToUi() {
    try {
      final contactMap = <int, Map<String, dynamic>>{};

      // 1. All user IDs from getContacts
      for (final uid in _contactUserIds) {
        if (uid == _myId) continue;
        final u = _users[uid];
        if (u != null) {
          contactMap[uid] = u;
        }
      }

      // 2. All users from private chats
      for (final st in _chats.values) {
        final chatType = st.chat['type'] as Map<String, dynamic>?;
        if (chatType?['@type'] == 'chatTypePrivate') {
          final uid = (chatType?['user_id'] as num?)?.toInt();
          if (uid != null && uid != _myId) {
            final u = _users[uid];
            if (u != null) {
              contactMap[uid] = u;
            }
          }
        }
      }

      final contactsList = <Map<String, dynamic>>[];
      for (final entry in contactMap.entries) {
        final uid = entry.key;
        final u = entry.value;

        final userType = u['type']?['@type'] as String?;
        final isDeleted = userType == 'userTypeDeleted';

        final fn = (u['first_name'] as String?)?.trim() ?? '';
        final ln = (u['last_name'] as String?)?.trim() ?? '';
        var name = '$fn $ln'.trim();

        final rawUsername = (u['usernames']?['active_usernames'] as List?)?.firstOrNull?.toString().trim() ??
            (u['username'] as String?)?.trim() ??
            '';
        final rawPhone = (u['phone_number'] as String?)?.trim() ?? '';

        // Filter out deleted accounts and nameless ghost debris from contacts list
        if (isDeleted || (fn.isEmpty && ln.isEmpty && rawUsername.isEmpty && rawPhone.isEmpty)) {
          continue;
        }

        if (name.isEmpty) {
          if (rawUsername.isNotEmpty) {
            name = rawUsername.startsWith('@') ? rawUsername : '@$rawUsername';
          } else if (rawPhone.isNotEmpty) {
            name = rawPhone.startsWith('+') ? rawPhone : '+$rawPhone';
          } else {
            name = 'User $uid';
          }
        }

        final username = rawUsername.isNotEmpty
            ? (rawUsername.startsWith('@') ? rawUsername : '@$rawUsername')
            : '';

        final phone = rawPhone.isNotEmpty
            ? (rawPhone.startsWith('+') ? rawPhone : '+$rawPhone')
            : '';

        String statusStr = '';
        bool isOnline = false;
        final status = u['status'] as Map<String, dynamic>?;
        if (status != null) {
          final sType = status['@type'] as String?;
          if (sType == 'userStatusOnline') {
            isOnline = true;
            statusStr = 'в сети';
          } else if (sType == 'userStatusRecently') {
            statusStr = 'был(а) недавно';
          } else if (sType == 'userStatusLastWeek') {
            statusStr = 'был(а) на этой неделе';
          } else if (sType == 'userStatusLastMonth') {
            statusStr = 'был(а) в этом месяце';
          } else if (sType == 'userStatusOffline') {
            final wasOnline = (status['was_online'] as num?)?.toInt() ?? 0;
            if (wasOnline > 0) {
              statusStr = 'был(а) ${formatTime(wasOnline)}';
            } else {
              statusStr = 'не в сети';
            }
          }
        }

        String? avatarPath;
        final profilePhoto = u['profile_photo'] as Map<String, dynamic>?;
        if (profilePhoto != null) {
          final small = profilePhoto['small'] as Map<String, dynamic>?;
          if (small != null) {
            final local = small['local'] as Map<String, dynamic>?;
            final localPath = (local?['path'] as String?) ?? '';
            final isDone = local?['is_downloading_completed'] == true;
            if (isDone && localPath.isNotEmpty && File(localPath).existsSync()) {
              avatarPath = localPath;
            } else {
              _downloadFileIfNeeded(small);
            }
          }
        }

        // Check if there is an existing chat with this user
        String chatId = uid.toString();
        for (final st in _chats.values) {
          final ct = st.chat['type'] as Map<String, dynamic>?;
          if (ct?['@type'] == 'chatTypePrivate' && (ct?['user_id'] as num?)?.toInt() == uid) {
            chatId = st.chat['id'].toString();
            break;
          }
        }

        contactsList.add({
          'id': chatId,
          'userId': uid,
          'name': name,
          'username': username,
          'phone': phone,
          'status': statusStr.isEmpty ? (isOnline ? 'в сети' : 'не в сети') : statusStr,
          'isOnline': isOnline,
          'avatarColor': TdContent.colorFor(name),
          'avatarEmoji': TdContent.initials(name),
          'avatarPath': avatarPath,
          'bio': '',
        });
      }

      contactsList.sort((a, b) => (a['name'] as String).toLowerCase().compareTo((b['name'] as String).toLowerCase()));

      _ui.send({
        'type': 'contacts',
        'contacts': contactsList,
      });
    } catch (e, stack) {
      // ignore: avoid_print
      print('[worker] error in _sendContactsToUi: $e\n$stack');
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

    final lastReadOutboxId = (st.chat['last_read_outbox_message_id'] as num?)?.toInt() ?? 0;
    final lastMsgId = last != null ? (last['id'] as num?)?.toInt() ?? 0 : 0;
    final isOutgoingRead = fromMe && (lastMsgId > 0 && lastMsgId <= lastReadOutboxId);
    final chatType = st.chat['type'] as Map<String, dynamic>?;
    int? userId;
    if (chatType?['@type'] == 'chatTypePrivate') {
      userId = chatType?['user_id'] as int?;
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
      userId: userId,
      verified: st.chat['is_verified'] as bool? ?? false,
      unread: st.unread,
      unreadOwn: fromMe,
      outgoing: fromMe,
      outgoingRead: isOutgoingRead,
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
          final localPath = (local?['path'] as String?) ?? '';
          final downloadedVoice = fileId != 0 ? _downloadedFiles[fileId] : null;
          if (downloadedVoice != null && downloadedVoice.isNotEmpty && File(downloadedVoice).existsSync()) {
            mediaPath = downloadedVoice;
            isDownloaded = true;
          } else if (local?['is_downloading_completed'] == true && localPath.isNotEmpty && File(localPath).existsSync()) {
            mediaPath = localPath;
            isDownloaded = true;
          } else {
            mediaPath = localPath;
            isDownloading = _downloadingFiles.contains(fileId) || local?['is_downloading_active'] == true;
          }
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
            if (thumbnailPath.isEmpty && sizes.isNotEmpty) {
              final firstSz = sizes.first;
              if (firstSz is Map) {
                final file = firstSz['photo'] is Map ? firstSz['photo'] as Map : null;
                final fId = (file?['id'] as num?)?.toInt();
                final local = file?['local'] is Map ? file!['local'] as Map : null;
                final localPath = (local?['path'] as String?) ?? '';
                final downloaded = fId != null ? _downloadedFiles[fId] : null;
                if (downloaded != null && downloaded.isNotEmpty && File(downloaded).existsSync()) {
                  thumbnailPath = downloaded;
                } else if (local?['is_downloading_completed'] == true && localPath.isNotEmpty && File(localPath).existsSync()) {
                  thumbnailPath = localPath;
                }
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

        // Обработка ответа на сообщение (Reply / Quote)
        int replyToMessageId = 0;
        String replySenderName = '';
        String replyText = '';
        String replyThumbnailPath = '';
        MessageKind? replyKind;

        final replyTo = msg['reply_to'] is Map ? msg['reply_to'] as Map : null;
        if (replyTo != null) {
          replyToMessageId = (replyTo['message_id'] as num?)?.toInt() ?? 0;
          if (replyTo['quote'] is Map) {
            final quote = replyTo['quote'] as Map;
            final qText = quote['text'] is Map ? (quote['text']['text'] as String?) : null;
            if (qText != null && qText.isNotEmpty) {
              replyText = qText;
            }
          }
        }
        if (replyToMessageId == 0) {
          replyToMessageId = (msg['reply_to_message_id'] as num?)?.toInt() ?? 0;
        }

        if (replyToMessageId > 0) {
          Map<String, dynamic>? repliedMsg;
          for (final m in st.history) {
            if (m['id'] == replyToMessageId) {
              repliedMsg = m;
              break;
            }
          }
          repliedMsg ??= _allMessages[replyToMessageId];

          if (repliedMsg == null) {
            if (!_requestedReplyMessages.contains(replyToMessageId)) {
              _requestedReplyMessages.add(replyToMessageId);
              _send({
                '@type': 'getMessage',
                'chat_id': st.chat['id'],
                'message_id': replyToMessageId,
              });
            }
          } else {
            replySenderName = _senderName(repliedMsg);
            if (replySenderName.isEmpty) {
              replySenderName = repliedMsg['is_outgoing'] == true ? 'Вы' : 'Пользователь';
            }
            replyKind = TdContent.messageKind(repliedMsg);
            if (replyText.isEmpty) {
              if (replyKind == MessageKind.video) {
                final rContent = repliedMsg['content'] as Map?;
                final isVideoNote = rContent?['video_note'] != null;
                final txt = TdContent.fullText(repliedMsg);
                replyText = isVideoNote ? 'Видеосообщение' : (txt.isNotEmpty ? txt : 'Видеозапись');
              } else if (replyKind == MessageKind.image) {
                final txt = TdContent.fullText(repliedMsg);
                replyText = txt.isNotEmpty ? txt : 'Фотография';
              } else if (replyKind == MessageKind.voice) {
                replyText = 'Голосовое сообщение';
              } else if (replyKind == MessageKind.document) {
                final txt = TdContent.fullText(repliedMsg);
                replyText = txt.isNotEmpty ? txt : 'Файл';
              } else {
                replyText = TdContent.fullText(repliedMsg);
              }
            }

            final rContent = repliedMsg['content'] as Map?;
            if (rContent != null) {
              final vn = (rContent['video_note'] ?? rContent['video'] ?? rContent['animation']) as Map?;
              if (vn != null) {
                final thumb = vn['thumbnail'] as Map?;
                final tf = thumb?['file'] as Map?;
                if (tf != null) {
                  final tfId = (tf['id'] as num?)?.toInt() ?? 0;
                  final loc = tf['local'] as Map?;
                  final p = (loc?['path'] as String?) ?? '';
                  if (_downloadedFiles[tfId] != null && File(_downloadedFiles[tfId]!).existsSync()) {
                    replyThumbnailPath = _downloadedFiles[tfId]!;
                  } else if (p.isNotEmpty && File(p).existsSync()) {
                    replyThumbnailPath = p;
                  } else {
                    _downloadFileIfNeeded(tf, priority: 25);
                  }
                }
              } else if (rContent['photo'] is Map) {
                final photo = rContent['photo'] as Map;
                final sizes = photo['sizes'] as List?;
                if (sizes != null && sizes.isNotEmpty) {
                  final small = sizes.first as Map?;
                  final sf = small?['photo'] as Map?;
                  if (sf != null) {
                    final sfId = (sf['id'] as num?)?.toInt() ?? 0;
                    final loc = sf['local'] as Map?;
                    final p = (loc?['path'] as String?) ?? '';
                    if (_downloadedFiles[sfId] != null && File(_downloadedFiles[sfId]!).existsSync()) {
                      replyThumbnailPath = _downloadedFiles[sfId]!;
                    } else if (p.isNotEmpty && File(p).existsSync()) {
                      replyThumbnailPath = p;
                    } else {
                      _downloadFileIfNeeded(sf, priority: 25);
                    }
                  }
                }
              }
            }
          }
        }

        final sName = _senderName(msg);
        final sUserId = (msg['sender_id'] is Map)
            ? ((msg['sender_id']['user_id'] as num?)?.toInt() ?? 0)
            : 0;

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
          replyToMessageId: replyToMessageId,
          replySenderName: replySenderName,
          replyText: replyText,
          replyThumbnailPath: replyThumbnailPath,
          replyKind: replyKind,
          senderName: sName,
          senderUserId: sUserId,
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
