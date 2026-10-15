import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

import '../../state/app_state.dart';
import '../utils/app_logger.dart';

/// Сервис системных десктопных push-уведомлений для Linux / Desktop.
/// Использует нативный D-Bus интерфейс org.freedesktop.Notifications.
class DesktopNotificationService {
  DesktopNotificationService._();

  static Future<void> show({
    required String title,
    required String body,
    String? chatId,
  }) async {
    if (kIsWeb) return;

    try {
      if (Platform.isLinux) {
        // Вызов нативного DBus org.freedesktop.Notifications.Notify
        await Process.run('gdbus', [
          'call',
          '--session',
          '--dest',
          'org.freedesktop.Notifications',
          '--object-path',
          '/org/freedesktop/Notifications',
          '--method',
          'org.freedesktop.Notifications.Notify',
          'TellMeMore TG',
          '0',
          'telegram',
          title,
          body,
          '[]',
          '{}',
          '5000',
        ]);
        AppLogger.log('[Notification] Shown: "$title": "$body" (chat: $chatId)');
      }
    } catch (e, st) {
      AppLogger.error('[Notification] Failed to show notification', e, st);
    }
  }

  /// Активировать окно приложения и перейти в нужный чат
  static Future<void> activateWindow({String? chatId}) async {
    try {
      if (!kIsWeb && (Platform.isLinux || Platform.isMacOS || Platform.isWindows)) {
        await windowManager.show();
        await windowManager.focus();
      }
      if (chatId != null && chatId.isNotEmpty) {
        AppState.selectedChatId.value = chatId;
      }
    } catch (e) {
      AppLogger.log('[Notification] activateWindow error: $e');
    }
  }
}
