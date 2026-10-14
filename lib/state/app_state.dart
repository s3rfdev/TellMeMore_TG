import 'package:flutter/foundation.dart';
import '../data/models/tg_chat.dart';

/// Глобальное состояние приложения (до подключения реального API).
class AppState {
  AppState._();

  static final ValueNotifier<String?> selectedChatId =
      ValueNotifier<String?>('taras');

  /// Ширина левой колонки; перетаскивается за разделитель.
  static final ValueNotifier<double> sidebarWidth = ValueNotifier<double>(340);

  /// Открыто ли главное меню (drawer).
  static final ValueNotifier<bool> drawerOpen = ValueNotifier<bool>(false);

  /// Демо-режим на моках (если TDLib недоступна или вход отложен).
  static final ValueNotifier<bool> demoMode = ValueNotifier<bool>(false);

  /// Сообщение, на которое сейчас пишется ответ (Reply).
  static final ValueNotifier<TgMessage?> replyingTo = ValueNotifier<TgMessage?>(null);
}
