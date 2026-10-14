import 'package:flutter/material.dart';

import 'core/theme/tg_theme.dart';
import 'shell/home_shell.dart';

class TgAnswerApp extends StatelessWidget {
  const TgAnswerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TG Answer',
      debugShowCheckedModeBanner: false,
      theme: buildTgTheme(),
      home: const Scaffold(body: HomeShell()),
    );
  }
}
