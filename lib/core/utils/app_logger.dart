import 'dart:io';

class AppLogger {
  static final File _logFile = File('/tmp/tg_answer_app.log');

  static void log(String message) {
    final timestamp = DateTime.now().toIso8601String();
    final line = '[$timestamp] $message';
    // ignore: avoid_print
    print(line);
    try {
      _logFile.writeAsStringSync('$line\n', mode: FileMode.append, flush: true);
    } catch (_) {}
  }

  static void error(String message, [Object? error, StackTrace? stack]) {
    final timestamp = DateTime.now().toIso8601String();
    final buffer = StringBuffer('[$timestamp] ERROR: $message');
    if (error != null) {
      buffer.write('\nDetails: $error');
    }
    if (stack != null) {
      buffer.write('\nStack trace:\n$stack');
    }
    final text = buffer.toString();
    // ignore: avoid_print
    print(text);
    try {
      _logFile.writeAsStringSync('$text\n', mode: FileMode.append, flush: true);
    } catch (_) {}
  }
}
