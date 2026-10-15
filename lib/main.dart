import 'dart:async' show unawaited;
import 'dart:io' show Platform;
import 'dart:ui' show AppExitResponse, PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'app.dart';
import 'data/tdlib/tdlib_service.dart';
import 'features/ai_copilot/models/ai_settings_model.dart';
import 'features/ai_copilot/models/contact_dossier.dart';
import 'features/ai_copilot/services/copilot_session_store.dart';
import 'platform/window_init.dart';

import 'core/utils/app_logger.dart';

void _setupLogging() {
  AppLogger.log('=== APP LAUNCHED ===');

  final originalDebugPrint = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message != null) {
      AppLogger.log('[DEBUG] $message');
    }
    originalDebugPrint(message, wrapWidth: wrapWidth);
  };

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    AppLogger.error('FLUTTER ERROR: ${details.exceptionAsString()}', details.exception, details.stack);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.error('PLATFORM DISPATCHER ERROR', error, stack);
    return false;
  };
}

Future<void> main() async {
  _setupLogging();
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && (Platform.isLinux || Platform.isMacOS || Platform.isWindows)) {
    try {
      MediaKit.ensureInitialized();
    } catch (e) {
      AppLogger.error('MediaKit initialization skipped: $e');
    }
  }
  await initDesktopWindow();
  try {
    await Future.wait([
      CopilotSessionStore.instance.init(),
      AiSettingsStore.instance.init(),
      ContactDossierStore.instance.init(),
    ]);
  } catch (e) {
    AppLogger.error('Store initialization error: $e');
  }
  if (!kIsWeb) {
    // TDLib живёт в своём изоляте; UI только получает готовые снимки.
    unawaited(TdlibService.instance.init());
    // SIGTERM: корректно закрываем TDLib (сброс сессии на диск).
    registerExitHook(() => TdlibService.instance.shutdown());
  }
  // Cmd+Q и системный выход: сначала закрываем TDLib, потом выходим.
  // (листенер регистрируется в WidgetsBinding, хранить ссылку не нужно)
  AppLifecycleListener(
    onDetach: () {
      TdlibService.instance.shutdown();
    },
    onExitRequested: () async {
      await TdlibService.instance.shutdown();
      return AppExitResponse.exit;
    },
  );
  runApp(const TgAnswerApp());
}
