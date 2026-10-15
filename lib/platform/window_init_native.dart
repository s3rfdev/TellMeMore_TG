import 'dart:io' show Platform, ProcessSignal, exit;

import 'package:flutter/material.dart' show Size;
import 'package:window_manager/window_manager.dart';

/// Скрываем штатный заголовок окна, оставляя «светофор» macOS —
/// как в оригинальном Telegram.
Future<void> initWindowImpl() async {
  if (!Platform.isLinux && !Platform.isMacOS && !Platform.isWindows) return;
  await windowManager.ensureInitialized();
  final isMac = Platform.isMacOS;
  final options = WindowOptions(
    size: const Size(1280, 840),
    minimumSize: const Size(800, 540),
    center: true,
    title: 'TellMeMore TG',
    titleBarStyle: isMac ? TitleBarStyle.hidden : TitleBarStyle.normal,
  );
  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.show();
    await windowManager.focus();
  });
}

/// SIGTERM (в т.ч. pkill без -9): успеваем закрыть TDLib перед выходом.
void registerExitHookImpl(Future<void> Function() onExit) {
  if (!Platform.isLinux && !Platform.isMacOS && !Platform.isWindows) return;
  try {
    ProcessSignal.sigterm.watch().listen((_) async {
      await onExit();
      exit(0);
    });
  } catch (_) {}
}
