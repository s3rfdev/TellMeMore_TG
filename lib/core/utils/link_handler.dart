import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/mock_data.dart';
import '../../data/models/tg_account.dart';
import '../../data/tdlib/tdlib_service.dart';
import '../../state/app_state.dart';
import '../widgets/tg_toast.dart';

/// Утилита для распознавания и открытия ссылок и упоминаний (@username, http/https, t.me).
class LinkHandler {
  LinkHandler._();

  static final RegExp linkRegex = RegExp(
    r'(@[a-zA-Z0-9_]{3,}|https?:\/\/[^\s\)\>]+|(?:t\.me|telegram\.me)\/[a-zA-Z0-9_\+]+)',
    caseSensitive: false,
  );

  /// Обработать клик по ссылке или @mention
  static Future<void> openLink(BuildContext context, String raw) async {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return;

    // 1. Упоминание Telegram (@username)
    if (trimmed.startsWith('@')) {
      final username = trimmed.substring(1).trim();
      _openTelegramUsername(context, username);
      return;
    }

    // 2. Короткая ссылка t.me/username
    if (trimmed.toLowerCase().startsWith('t.me/') ||
        trimmed.toLowerCase().startsWith('telegram.me/')) {
      final parts = trimmed.split('/');
      if (parts.length >= 2 && !parts[1].startsWith('+') && !parts[1].startsWith('c/')) {
        final username = parts[1].split('?').first.trim();
        _openTelegramUsername(context, username);
        return;
      }
    }

    // 3. HTTP / HTTPS ссылка
    String url = trimmed;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    // Fallback для Linux Desktop через xdg-open
    if (Platform.isLinux) {
      try {
        await Process.run('xdg-open', [url]);
        return;
      } catch (_) {}
    }

    if (context.mounted) {
      TgToast.show(context, 'Не удалось открыть ссылку: $url');
    }
  }

  /// Открыть чат или профиль по Telegram username
  static void _openTelegramUsername(BuildContext context, String username) {
    final lower = username.toLowerCase();

    // 1. Проверяем локальные чаты текущего аккаунта
    final currentAcc = AccountManager.instance.currentAccount.value;
    final chats = AccountManager.instance.getChats(currentAcc.id);
    for (final chat in chats) {
      if (chat.id.toLowerCase() == lower ||
          chat.title.toLowerCase() == lower ||
          chat.headerSubtitle.toLowerCase().contains('@$lower')) {
        AppState.activeSidebarTab.value = SidebarTab.chats;
        AppState.selectedChatId.value = chat.id;
        if (context.mounted) {
          TgToast.show(context, 'Открыт чат: ${chat.title}');
        }
        return;
      }
    }

    // 2. Проверяем контакты текущего аккаунта
    final contacts = AccountManager.instance.getContacts(currentAcc.id);
    for (final contact in contacts) {
      if (contact.id.toLowerCase() == lower ||
          contact.name.toLowerCase() == lower ||
          contact.phone.contains(lower)) {
        AppState.activeSidebarTab.value = SidebarTab.chats;
        AppState.selectedChatId.value = contact.id;
        if (context.mounted) {
          TgToast.show(context, 'Открыт чат с ${contact.name}');
        }
        return;
      }
    }

    // 3. Проверяем общие мок-чаты (Taras, Du Rove, etc.)
    for (final chat in mockChats) {
      if (chat.id.toLowerCase() == lower ||
          chat.title.toLowerCase().contains(lower) ||
          chat.headerSubtitle.toLowerCase().contains('@$lower')) {
        AppState.activeSidebarTab.value = SidebarTab.chats;
        AppState.selectedChatId.value = chat.id;
        if (context.mounted) {
          TgToast.show(context, 'Открыт чат: ${chat.title}');
        }
        return;
      }
    }

    // 3. Отправляем запрос в TDLib на поиск публичного чата
    TdlibService.instance.openUserByUsername(username);
    AppState.activeSidebarTab.value = SidebarTab.chats;

    if (context.mounted) {
      TgToast.show(context, 'Поиск @$username в Telegram...');
    }
  }

  /// Построить список InlineSpan со стилизованными кликабельными ссылками
  static List<InlineSpan> buildSpans({
    required BuildContext context,
    required String text,
    required bool outgoing,
    Color? linkColor,
    TextStyle? baseStyle,
  }) {
    final matches = linkRegex.allMatches(text);
    if (matches.isEmpty) {
      return [TextSpan(text: text, style: baseStyle)];
    }

    final spans = <InlineSpan>[];
    int lastEnd = 0;

    final defaultLinkColor = outgoing
        ? const Color(0xFFE0D8FF)
        : const Color(0xFF51B2FF);

    for (final m in matches) {
      if (m.start > lastEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastEnd, m.start),
            style: baseStyle,
          ),
        );
      }

      final matched = m.group(0)!;
      final isMention = matched.startsWith('@');

      spans.add(
        TextSpan(
          text: matched,
          style: (baseStyle ?? const TextStyle()).copyWith(
            color: linkColor ?? defaultLinkColor,
            fontWeight: isMention ? FontWeight.w600 : FontWeight.w500,
            decoration: isMention ? TextDecoration.none : TextDecoration.underline,
            decorationColor: linkColor ?? defaultLinkColor,
          ),
          mouseCursor: SystemMouseCursors.click,
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              openLink(context, matched);
            },
        ),
      );

      lastEnd = m.end;
    }

    if (lastEnd < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(lastEnd),
          style: baseStyle,
        ),
      );
    }

    return spans;
  }
}
