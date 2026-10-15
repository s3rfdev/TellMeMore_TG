import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Определяет надежные, не зависящие от временных папок пути для сессии TDLib.
class SessionPaths {
  SessionPaths._();

  static Future<Map<String, String>> getTdlibDirectories() async {
    final home = Platform.environment['HOME'] ?? '';
    String base = '';

    if (Platform.isLinux && home.isNotEmpty) {
      base = '$home/.local/share/tg_answer/tdlib';
    } else if (Platform.isMacOS && home.isNotEmpty) {
      base = '$home/Library/Application Support/tg_answer/tdlib';
    } else if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'] ?? '';
      if (appData.isNotEmpty) {
        base = '$appData/tg_answer/tdlib';
      }
    }

    if (base.isEmpty) {
      final docs = await getApplicationDocumentsDirectory();
      base = '${docs.path}/tg_answer/tdlib';
    }

    final dbDir = Directory('$base/db');
    final filesDir = Directory('$base/files');

    if (!dbDir.existsSync()) dbDir.createSync(recursive: true);
    if (!filesDir.existsSync()) filesDir.createSync(recursive: true);

    return {
      'dbDir': dbDir.path,
      'filesDir': filesDir.path,
    };
  }

  /// Возвращает директорию для хранения локальных данных приложения (настройки, сессии копилота, досье).
  static Future<String> getAppStorageDirectory() async {
    final home = Platform.environment['HOME'] ?? '';
    String base = '';

    if (Platform.isLinux && home.isNotEmpty) {
      base = '$home/.local/share/tg_answer';
    } else if (Platform.isMacOS && home.isNotEmpty) {
      base = '$home/Library/Application Support/tg_answer';
    } else if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'] ?? '';
      if (appData.isNotEmpty) {
        base = '$appData/tg_answer';
      }
    }

    if (base.isEmpty) {
      try {
        final docs = await getApplicationDocumentsDirectory();
        base = '${docs.path}/tg_answer';
      } catch (_) {
        base = Directory.systemTemp.path;
      }
    }

    final dir = Directory(base);
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir.path;
  }
}
