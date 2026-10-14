import 'package:flutter/material.dart';

/// Дизайн-токены аутентичной темы Telegram Desktop (Dark / Purple Accent).
class Tg {
  Tg._();

  static const bg = Color(0xFF0F0F12);
  static const sidebar = Color(0xFF1E1E22);
  static const chatBg = Color(0xFF0F0F12);
  static const field = Color(0xFF28282D);
  static const searchFrame = Color(0xFF242428);
  static const selected = Color(0xFF766AC8);
  static const outBubble = Color(0xFF766AC8);
  static const inBubble = Color(0xFF212126);
  static const quote = Color(0xFF1A1A1F);
  static const screenshot = Color(0xFF0A0F14);

  static const text = Color(0xFFFFFFFF);
  static const textDim = Color(0xFFA5A5AB);
  static const textFaint = Color(0xFF707078);
  static const time = Color(0xFF8E8E96);
  static const timeOut = Color(0xFFD6D1F7);
  static const ticks = Color(0xFFE2DEFB);

  static const accent = Color(0xFF8774E1);
  static const accentGradient = [Color(0xFF8774E1), Color(0xFF766AC8)];
  static const badgeMuted = Color(0xFF38383F);
  static const hairline = Color(0xFF18181C);
  static const verified = Color(0xFF8774E1);
  static const service = Color(0xFF8E8E96);
  static const danger = Color(0xFFE5565B);
}

ThemeData buildTgTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: Tg.bg,
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
    hoverColor: Colors.white.withValues(alpha: 0.05),
    colorScheme: const ColorScheme.dark(
      primary: Tg.accent,
      surface: Tg.sidebar,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: Tg.accent,
      selectionColor: Color(0x558774E1),
      selectionHandleColor: Tg.accent,
    ),
    scrollbarTheme: ScrollbarThemeData(
      thickness: WidgetStateProperty.all(4),
      radius: const Radius.circular(2),
      thumbColor: WidgetStateProperty.all(Colors.white.withValues(alpha: 0.16)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: const Color(0xEE1A222D),
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w500),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.14), width: 1),
      ),
    ),
  );
}
