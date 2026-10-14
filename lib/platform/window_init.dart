import 'window_init_stub.dart' if (dart.library.io) 'window_init_native.dart';

/// Настройка окна под платформу (на web — no-op).
Future<void> initDesktopWindow() => initWindowImpl();

/// Хук завершения процесса (SIGTERM): даёт приложению корректно
/// закрыть TDLib и сбросить сессию на диск перед выходом.
void registerExitHook(Future<void> Function() onExit) =>
    registerExitHookImpl(onExit);
