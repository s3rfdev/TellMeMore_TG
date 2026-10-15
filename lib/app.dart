import 'package:flutter/material.dart';

import 'core/localization/app_locale.dart';
import 'core/theme/tg_theme.dart';
import 'shell/home_shell.dart';

class TgAnswerApp extends StatelessWidget {
  const TgAnswerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: I18n.instance.currentLanguage,
      builder: (context, lang, _) {
        return MaterialApp(
          title: 'TellMeMore TG',
          debugShowCheckedModeBanner: false,
          theme: buildTgTheme(),
          home: const Scaffold(body: HomeShell()),
        );
      },
    );
  }
}
