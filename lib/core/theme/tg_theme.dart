import 'package:flutter/material.dart';

/// Дизайн-токены единой темы Telegram Desktop (Dark Slate & Graphite-Blue Accent).
/// Все цвета сведены к гармоничному диапазону без разнобоя и вынесены в переменные.
class Tg {
  Tg._();

  // Основной фон и поверхности (Dark Slate / Charcoal Blue)
  static const bg = Color(0xFF0E1621);
  static const sidebar = Color(0xFF17212B);
  static const chatBg = Color(0xFF0E1621);
  static const surface = Color(0xFF17212B);
  static const card = Color(0xFF1E2C3A);
  static const cardLight = Color(0xFF243447);

  // Поля ввода и поиск
  static const field = Color(0xFF242F3D);
  static const searchFrame = Color(0xFF242F3D);

  // Сообщения и выделение
  static const selected = Color(0xFF2B5278);
  static const outBubble = Color(0xFF2B5278);
  static const inBubble = Color(0xFF182533);
  static const quote = Color(0xFF15222E);
  static const screenshot = Color(0xFF0B1118);

  // Текст (минималистичный, не жирный)
  static const text = Color(0xFFFFFFFF);
  static const textDim = Color(0xFF7E8E9E);
  static const textFaint = Color(0xFF5A6B7B);
  static const time = Color(0xFF6C7E90);
  static const timeOut = Color(0xFF8DAAC6);
  static const ticks = Color(0xFF64B5F6);

  // Акценты (Серо-синий Telegram Classic Steel Blue - НИКАКОГО ФИОЛЕТОВОГО)
  static const accent = Color(0xFF5288C1);
  static const accentDark = Color(0xFF2F6EA5);
  static const accentLight = Color(0xFF6499D2);
  static const accentHover = Color(0xFF6499D2);
  static const accentSubtle = Color(0x265288C1);
  static const accentGradient = LinearGradient(
    colors: [Color(0xFF2F6EA5), Color(0xFF245B8B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const accentGradientColors = [Color(0xFF2F6EA5), Color(0xFF245B8B)];

  // Бейджи и границы
  static const badgeMuted = Color(0xFF27384A);
  static const hairline = Color(0xFF121B24);
  static const border = Color(0x1AFFFFFF);
  static const borderSubtle = Color(0x0FFFFFFF);
  static const verified = Color(0xFF5288C1);
  static const service = Color(0xFF6C7E90);
  static const danger = Color(0xFFE5565B);

  // Типографика (минимализм: маленький, не жирный текст)
  static const fontRegular = FontWeight.w400;
  static const fontMedium = FontWeight.w500;

  static const title = TextStyle(
    fontSize: 14.5,
    fontWeight: fontMedium,
    color: text,
  );

  static const subheader = TextStyle(
    fontSize: 13,
    fontWeight: fontMedium,
    color: text,
  );

  static const body = TextStyle(
    fontSize: 13,
    fontWeight: fontRegular,
    color: text,
  );

  static const caption = TextStyle(
    fontSize: 11.5,
    fontWeight: fontRegular,
    color: textDim,
  );

  static const button = TextStyle(
    fontSize: 12.5,
    fontWeight: fontMedium,
    color: Colors.white,
  );
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
      selectionColor: Color(0x405288C1),
      selectionHandleColor: Tg.accent,
    ),
    scrollbarTheme: ScrollbarThemeData(
      thickness: WidgetStateProperty.all(4),
      radius: const Radius.circular(2),
      thumbColor: WidgetStateProperty.all(Colors.white.withValues(alpha: 0.16)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: const Color(0xEE17212B),
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w400),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Tg.border, width: 1),
      ),
    ),
  );
}
