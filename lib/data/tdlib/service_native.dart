import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import '../../core/services/call_sound_service.dart';
import '../../core/services/desktop_notification_service.dart';
import '../../core/utils/session_paths.dart';
import '../../state/app_state.dart';
import '../models/tg_account.dart';
import '../models/tg_chat.dart';
import '../../features/contacts/models/tg_contact.dart';
import 'auth_phase.dart';
import 'td_content.dart';
import 'td_json_ffi.dart';
import 'td_worker.dart';

/// UI-сторона TDLib: тонкий клиент воркера-изолята.
class TdlibService {
  TdlibService._();

  static final TdlibService instance = TdlibService._();

  final ValueNotifier<AuthPhase> phase =
      ValueNotifier<AuthPhase>(AuthPhase.idle);
  final ValueNotifier<String?> errorText = ValueNotifier<String?>(null);
  final ValueNotifier<String?> qrLink = ValueNotifier<String?>(null);
  final ValueNotifier<String?> codeDeliveryHint = ValueNotifier<String?>(null);
  final ValueNotifier<String?> passwordHint = ValueNotifier<String?>(null);
  final ValueNotifier<List<TgChat>> chats = ValueNotifier<List<TgChat>>([]);
  final ValueNotifier<TgUser?> currentUser = ValueNotifier<TgUser?>(null);
  final ValueNotifier<List<TgChat>> searchResults = ValueNotifier<List<TgChat>>([]);

  /// Чаты, для которых идёт догрузка истории вверх.
  final ValueNotifier<Set<String>> loadingMore =
      ValueNotifier<Set<String>>(const {});

  /// Чаты, для которых идёт первичная загрузка истории.
  final ValueNotifier<Set<String>> loadingHistory =
      ValueNotifier<Set<String>>(const {});

  final Set<String> _requestedHistories = {};

  SendPort? _cmd;
  ReceivePort? _ui;
  bool _started = false;
  final Map<String, ValueNotifier<TgChatHistory>> _stores = {};
  final List<Map<String, dynamic>> _pendingCmds = [];
  final Completer<void> _closedCompleter = Completer<void>();

  void _sendCmd(Map<String, dynamic> cmd) {
    if (_cmd != null) {
      _cmd!.send(cmd);
    } else {
      _pendingCmds.add(cmd);
    }
  }

  // ---------------------------------------------------------------- init

  Future<void> init() async {
    if (_started) return;
    _started = true;

    final ffi = TdJsonFfi.tryOpen();
    if (ffi == null) {
      phase.value = AuthPhase.error;
      errorText.value = 'libtdjson не найдена. ${TdJsonFfi.lastError ?? ''}';
      return;
    }
    ffi.setLogLevel(1);
    final client = ffi.createClient();

    final dirs = await SessionPaths.getTdlibDirectories();
    _ui = ReceivePort();
    _ui!.listen((m) => _onWorkerMessage(Map<String, dynamic>.from(m as Map)));

    await Isolate.spawn(
      TdWorker.entry,
      {
        'clientAddress': client.clientAddress,
        'ui': _ui!.sendPort,
        'dbDir': dirs['dbDir']!,
        'filesDir': dirs['filesDir']!,
      },
      debugName: 'tdlib-worker',
    );

    // ВАЖНО: ждём тот же completer, который завершает _onWorkerMessage
    // в case 'ready'.
    _cmd = await _cmdCompleter.future;
    phase.value = AuthPhase.connecting;
  }

  void _onWorkerMessage(Map<String, dynamic> msg) {
    switch (msg['type']) {
      case 'ready':
        // ignore: avoid_print
        print('[service] worker ready, захватываю cmd-порт');
        final port = msg['cmd'] as SendPort;
        if (!_cmdCompleter.isCompleted) _cmdCompleter.complete(port);
        _cmd = port;
        for (final pending in _pendingCmds) {
          _cmd!.send(pending);
        }
        _pendingCmds.clear();
      case 'auth':
        if (msg.containsKey('link') && msg['link'] != null) {
          qrLink.value = msg['link'] as String;
        }
        if (msg.containsKey('passwordHint')) {
          passwordHint.value = msg['passwordHint'] as String?;
        }
        if (msg.containsKey('codeInfo')) {
          final ci = msg['codeInfo'] as Map<String, dynamic>?;
          final type = ci?['type']?['@type'] as String?;
          if (type == 'authenticationCodeTypeTelegramMessage') {
            codeDeliveryHint.value = 'Код отправлен в приложение Telegram';
          } else if (type == 'authenticationCodeTypeSms') {
            codeDeliveryHint.value = 'Код отправлен по SMS';
          } else {
            codeDeliveryHint.value = 'Код подтверждения отправлен';
          }
        }
        _setAuth(msg['state'] as String);
      case 'error':
        errorText.value = msg['message'] as String?;
      case 'me':
        final u = msg['user'] as Map<String, dynamic>;
        final fn = u['first_name'] as String? ?? '';
        final ln = u['last_name'] as String? ?? '';
        final user = TgUser(
          id: u['id'] as int,
          firstName: fn,
          lastName: ln,
          username: u['username'] as String? ?? '',
          phoneNumber: u['phone_number'] as String? ?? '',
          avatarEmoji: TdContent.initials('$fn $ln'.trim().isEmpty ? 'User' : '$fn $ln'.trim()),
          avatarColor: TdContent.colorFor('$fn $ln'.trim().isEmpty ? 'User' : '$fn $ln'.trim()),
        );
        currentUser.value = user;
        AccountManager.instance.syncAuthorizedUser(user);
      case 'userFullInfo':
        final bio = msg['bio'] as String? ?? '';
        AccountManager.instance.syncBio(bio);
        AccountManager.instance.isSyncingProfile.value = false;
      case 'myAvatar':
        final path = msg['path'] as String? ?? '';
        AccountManager.instance.syncAvatar(path);
      case 'profilePhotos':
        final rawPhotos = (msg['photos'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final activePhotos = <TgPost>[];
        final archivedPhotos = <TgPost>[];
        for (final p in rawPhotos) {
          final isArch = p['isArchived'] as bool? ?? false;
          final post = TgPost(
            id: p['id'].toString(),
            text: p['text'] as String? ?? '',
            mediaPath: p['mediaPath'] as String? ?? '',
            date: DateTime.fromMillisecondsSinceEpoch(((p['date'] as num?)?.toInt() ?? 0) * 1000),
            views: (p['views'] as num?)?.toInt() ?? 0,
            likes: (p['likes'] as num?)?.toInt() ?? 0,
            isArchived: isArch,
          );
          if (isArch) {
            archivedPhotos.add(post);
          } else {
            activePhotos.add(post);
          }
        }
        AccountManager.instance.mergeProfilePhotos(activePhotos, archivedPhotos);
        AccountManager.instance.isSyncingProfile.value = false;
      case 'personalPosts':
        final rawPosts = (msg['posts'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final posts = rawPosts.map((p) => TgPost(
          id: p['id'].toString(),
          text: p['text'] as String? ?? '',
          mediaPath: p['mediaPath'] as String? ?? '',
          date: DateTime.fromMillisecondsSinceEpoch(((p['date'] as num?)?.toInt() ?? 0) * 1000),
          views: (p['views'] as num?)?.toInt() ?? 0,
          likes: (p['likes'] as num?)?.toInt() ?? 0,
          isArchived: false,
        )).toList();
        AccountManager.instance.setChannelPosts(posts);
        AccountManager.instance.isSyncingProfile.value = false;
      case 'postMediaDownloaded':
        final postId = msg['postId'] as String;
        final path = msg['path'] as String;
        AccountManager.instance.updatePostMedia(postId, path);
      case 'searchResults':
        final ids = (msg['chatIds'] as List).cast<int>().toSet();
        final all = chats.value;
        searchResults.value = all.where((c) => ids.contains(int.tryParse(c.id))).toList();
      case 'contacts':
        final rawContacts = (msg['contacts'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final list = rawContacts.map((c) => TgContact(
          id: c['id'] as String,
          name: c['name'] as String,
          username: c['username'] as String? ?? '',
          phone: c['phone'] as String? ?? '',
          status: c['status'] as String? ?? '',
          isOnline: c['isOnline'] as bool? ?? false,
          avatarColor: c['avatarColor'] as int? ?? 0xFF5288C1,
          avatarEmoji: c['avatarEmoji'] as String? ?? '👤',
          avatarPath: c['avatarPath'] as String?,
          bio: c['bio'] as String? ?? '',
        )).toList();
        AccountManager.instance.setContacts(list);
      case 'chats':
        final list = (msg['chats'] as List).cast<TgChat>();
        chats.value = list;
        if (list.isNotEmpty) {
          final cur = AppState.selectedChatId.value;
          if (cur == null || cur == 'taras' || !list.any((c) => c.id == cur)) {
            AppState.selectedChatId.value = list.first.id;
          }
        }
      case 'history':
        final payload = Map<String, TgChatHistory>.from(msg['messages'] as Map);
        final stillLoading = Set<String>.from(loadingMore.value);
        final stillInitialLoading = Set<String>.from(loadingHistory.value);
        payload.forEach((key, history) {
          _store(key).value = history;
          stillLoading.remove(key);
          stillInitialLoading.remove(key);
        });
        loadingMore.value = stillLoading;
        loadingHistory.value = stillInitialLoading;
      case 'selectChat':
        final cid = msg['chatId'] as String?;
        if (cid != null) {
          AppState.selectedChatId.value = cid;
        }
      case 'notification':
        final title = msg['title'] as String? ?? 'Telegram';
        final body = msg['body'] as String? ?? '';
        final chatId = msg['chatId'] as String?;
        DesktopNotificationService.show(title: title, body: body, chatId: chatId);
      case 'callUpdate':
        final call = msg['call'] as TgCallInfo?;
        if (call != null) {
          AppState.activeCall.value = call;
          if (call.state == TgCallState.ready) {
            CallSoundService.stop();
          } else if (call.state == TgCallState.discarded) {
            CallSoundService.stop();
            CallSoundService.playBusy();
            if (AppState.incomingCall.value?.callId == call.callId) {
              AppState.incomingCall.value = null;
            }
            Future.delayed(const Duration(milliseconds: 1600), () {
              if (AppState.activeCall.value?.callId == call.callId) {
                AppState.activeCall.value = null;
              }
            });
          }
        }
      case 'incomingCall':
        final call = msg['call'] as TgCallInfo?;
        if (call != null) {
          AppState.incomingCall.value = call;
          CallSoundService.startIncomingRingtone();
          DesktopNotificationService.show(
            title: 'Входящий звонок',
            body: '${call.userName} звонит вам',
          );
        }
    }
  }

  final Completer<SendPort> _cmdCompleter = Completer<SendPort>();

  void _setAuth(String state) {
    switch (state) {
      case 'authorizationStateWaitTdlibParameters':
      case 'authorizationStateWaitEncryptionKey':
        phase.value = AuthPhase.connecting;
      case 'authorizationStateWaitOtherDeviceConfirmation':
        phase.value = AuthPhase.waitQr;
        errorText.value = null;
      case 'authorizationStateWaitPhoneNumber':
        phase.value = AuthPhase.waitPhone;
      case 'authorizationStateWaitCode':
        phase.value = AuthPhase.waitCode;
      case 'authorizationStateWaitRegistration':
      case 'authorizationStateWaitPassword':
        phase.value = AuthPhase.waitPassword;
      case 'authorizationStateReady':
        phase.value = AuthPhase.ready;
        errorText.value = null;
      case 'authorizationStateClosed':
        if (!_closedCompleter.isCompleted) _closedCompleter.complete();
        phase.value = AuthPhase.error;
        errorText.value = 'Сессия закрыта';
    }
  }

  // ------------------------------------------------------------- actions

  void requestQrCode() {
    errorText.value = null;
    _sendCmd({'type': 'qr'});
  }

  void requestPhoneAuth() {
    errorText.value = null;
    phase.value = AuthPhase.waitPhone;
  }

  void sendPhoneNumber(String phone) {
    errorText.value = null;
    final cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    final formatted = cleaned.startsWith('+') ? cleaned : '+$cleaned';
    // ignore: avoid_print
    print('[auth-ui] sendPhoneNumber "$formatted", cmdPort ready: ${_cmd != null}');
    _sendCmd({'type': 'phone', 'value': formatted});
  }

  void sendCode(String code) {
    errorText.value = null;
    _sendCmd({'type': 'code', 'value': code});
  }

  void sendPassword(String password) {
    errorText.value = null;
    _sendCmd({'type': 'password', 'value': password});
  }

  void sendMessage(int chatId, String text, {int? replyToMessageId}) {
    _sendCmd({
      'type': 'send',
      'chatId': chatId,
      'text': text,
      if (replyToMessageId != null && replyToMessageId > 0)
        'replyToMessageId': replyToMessageId,
    });
  }

  void downloadFile(int fileId) {
    if (fileId > 0) {
      _sendCmd({'type': 'downloadFile', 'fileId': fileId});
    }
  }

  void deleteMessage(int chatId, int messageId) {
    _sendCmd({'type': 'deleteMessage', 'chatId': chatId, 'messageId': messageId});
  }

  void pinMessage(int chatId, int messageId) {
    _sendCmd({'type': 'pinMessage', 'chatId': chatId, 'messageId': messageId});
  }

  void forwardMessage(int toChatId, int fromChatId, int messageId) {
    _sendCmd({
      'type': 'forwardMessage',
      'toChatId': toChatId,
      'fromChatId': fromChatId,
      'messageId': messageId,
    });
  }

  void sendVoiceNote(int chatId, String path, int duration) {
    _sendCmd({'type': 'sendVoice', 'chatId': chatId, 'path': path, 'duration': duration});
  }

  void sendFile(int chatId, String path, [String caption = '']) {
    _sendCmd({'type': 'sendFile', 'chatId': chatId, 'path': path, 'caption': caption});
  }

  void searchChats(String query) {
    if (query.trim().isEmpty) {
      searchResults.value = [];
      return;
    }
    _sendCmd({'type': 'searchChats', 'query': query.trim()});
  }

  void loadMe() {
    _sendCmd({'type': 'getMe'});
  }

  void syncUserProfile() {
    AccountManager.instance.isSyncingProfile.value = true;
    _sendCmd({'type': 'syncProfile'});
  }

  void openUserByUsername(String username) {
    _sendCmd({'type': 'openUsername', 'username': username});
  }

  void syncContacts() {
    _sendCmd({'type': 'getContacts'});
  }

  void createPrivateChat(int userId) {
    _sendCmd({'type': 'createPrivateChat', 'userId': userId});
  }

  void createGroup(String title) {
    _sendCmd({'type': 'createGroup', 'title': title});
  }

  void openChat(int chatId) {
    _sendCmd({'type': 'openChat', 'chatId': chatId});
    requestHistory(chatId.toString());
  }

  /// Запрос истории сообщений для чата (вызывается при выборе чата, но не на каждый build)
  void requestHistory(String chatId, {bool force = false}) {
    final id = int.tryParse(chatId);
    if (id == null) return;
    if (!force && _requestedHistories.contains(chatId)) {
      _sendCmd({'type': 'openChat', 'chatId': id});
      return;
    }
    _requestedHistories.add(chatId);
    final current = Set<String>.from(loadingHistory.value);
    current.add(chatId);
    loadingHistory.value = current;
    _sendCmd({'type': 'history', 'chatId': id});
  }

  /// Корректное закрытие TDLib: сбрасывает сессию на диск.
  /// Вызывается при выходе из приложения (Cmd+Q / SIGTERM).
  Future<void> shutdown() async {
    if (_closedCompleter.isCompleted) return;
    _sendCmd({'type': 'close'});
    await _closedCompleter.future
        .timeout(const Duration(seconds: 4), onTimeout: () {});
  }

  void logOut() {
    _sendCmd({'type': 'logOut'});
    chats.value = [];
    currentUser.value = null;
    phase.value = AuthPhase.waitPhone;
    AppState.demoMode.value = true;
  }

  /// Хранилище истории чата: чистый getter, не отправляющий команд во избежание бесконечных циклов.
  ValueNotifier<TgChatHistory> messagesOf(String chatId) {
    return _store(chatId);
  }

  /// Догрузка более старых сообщений (скролл вверх).
  void loadMore(String chatId) {
    final id = int.tryParse(chatId);
    if (id == null) return;
    if (loadingMore.value.contains(chatId)) return;
    loadingMore.value = {...loadingMore.value, chatId};
    _sendCmd({'type': 'loadMore', 'chatId': id});
  }

  /// Удалить список сообщений (в т.ч. множественное удаление)
  void deleteMessages(int chatId, List<int> messageIds, {bool revoke = true}) {
    _sendCmd({
      'type': 'deleteMessages',
      'chatId': chatId,
      'messageIds': messageIds,
      'revoke': revoke,
    });
  }

  /// Очистить историю сообщений
  void clearHistory(int chatId, {bool revoke = true}) {
    _sendCmd({
      'type': 'clearHistory',
      'chatId': chatId,
      'revoke': revoke,
    });
  }

  /// Удалить чат полностью
  void deleteChat(int chatId) {
    _sendCmd({
      'type': 'deleteChat',
      'chatId': chatId,
    });
  }

  /// Начать аудиозвонок пользователю
  void createCall(int userId) {
    _sendCmd({'type': 'createCall', 'userId': userId});
  }

  /// Завершить / отклонить аудиозвонок
  void discardCall(int callId, {int duration = 0}) {
    CallSoundService.stop();
    _sendCmd({'type': 'discardCall', 'callId': callId, 'duration': duration});
    if (AppState.activeCall.value?.callId == callId) {
      AppState.activeCall.value = null;
    }
    if (AppState.incomingCall.value?.callId == callId) {
      AppState.incomingCall.value = null;
    }
  }

  /// Принять входящий звонок
  void acceptCall(int callId) {
    CallSoundService.stop();
    _sendCmd({'type': 'acceptCall', 'callId': callId});
    if (AppState.incomingCall.value?.callId == callId) {
      AppState.incomingCall.value = null;
    }
  }

  ValueNotifier<TgChatHistory> _store(String chatId) =>
      _stores.putIfAbsent(
          chatId, () => ValueNotifier<TgChatHistory>(const TgChatHistory()));
}
