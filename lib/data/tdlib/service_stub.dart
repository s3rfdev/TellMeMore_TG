import 'package:flutter/foundation.dart';

import '../models/tg_chat.dart';
import 'auth_phase.dart';

/// Web-заглушка: TDLib (dart:ffi) на web недоступна — остаёмся на моках.
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
  final ValueNotifier<Set<String>> loadingMore =
      ValueNotifier<Set<String>>(const {});
  final ValueNotifier<Set<String>> loadingHistory =
      ValueNotifier<Set<String>>(const {});

  Future<void> init() async {}

  void requestHistory(String chatId, {bool force = false}) {}

  void requestQrCode() {}
  void requestPhoneAuth() {}
  void sendPhoneNumber(String phone) {}
  void sendCode(String code) {}
  void sendPassword(String password) {}
  void sendMessage(int chatId, String text, {int? replyToMessageId}) {}
  void downloadFile(int fileId) {}
  void deleteMessage(int chatId, int messageId) {}
  void pinMessage(int chatId, int messageId) {}
  void forwardMessage(int toChatId, int fromChatId, int messageId) {}
  void sendVoiceNote(int chatId, String path, int duration) {}
  void sendFile(int chatId, String path, [String caption = '']) {}
  void searchChats(String query) {}
  void loadMe() {}
  void openUserByUsername(String username) {}
  void createGroup(String title) {}
  void openChat(int chatId) {}
  void deleteMessages(int chatId, List<int> messageIds, {bool revoke = true}) {}
  void clearHistory(int chatId, {bool revoke = true}) {}
  void deleteChat(int chatId) {}
  void createCall(int userId) {}
  void discardCall(int callId, {int duration = 0}) {}
  void acceptCall(int callId) {}

  Future<void> shutdown() async {}
  void logOut() {}

  ValueNotifier<TgChatHistory> messagesOf(String chatId) =>
      ValueNotifier<TgChatHistory>(const TgChatHistory());

  void loadMore(String chatId) {}
}
