import 'dart:async';
import 'dart:io';

/// Сервис воспроизведения звуков вызова (звонок, гудки, занято) через системный аудиосервер.
class CallSoundService {
  CallSoundService._();

  static Process? _currentProcess;
  static Timer? _loopTimer;
  static bool _isPlaying = false;

  static const String _incomingSound = '/usr/share/sounds/freedesktop/stereo/phone-incoming-call.oga';
  static const String _callingSound = '/usr/share/sounds/freedesktop/stereo/phone-outgoing-calling.oga';
  static const String _busySound = '/usr/share/sounds/freedesktop/stereo/phone-outgoing-busy.oga';

  /// Запустить циклический рингтон входящего вызова
  static void startIncomingRingtone() {
    stop();
    _isPlaying = true;
    _playFile(_incomingSound);
    _loopTimer = Timer.periodic(const Duration(milliseconds: 2800), (_) {
      if (_isPlaying) {
        _playFile(_incomingSound);
      }
    });
  }

  /// Запустить гудки ожидания ответа при исходящем вызове
  static void startOutgoingRingback() {
    stop();
    _isPlaying = true;
    _playFile(_callingSound);
    _loopTimer = Timer.periodic(const Duration(milliseconds: 3200), (_) {
      if (_isPlaying) {
        _playFile(_callingSound);
      }
    });
  }

  /// Звук завершения / занято
  static void playBusy() {
    stop();
    _playFile(_busySound);
  }

  /// Остановить воспроизведение звонка
  static void stop() {
    _isPlaying = false;
    _loopTimer?.cancel();
    _loopTimer = null;
    try {
      _currentProcess?.kill();
    } catch (_) {}
    _currentProcess = null;
  }

  static void _playFile(String path) {
    if (!File(path).existsSync()) return;
    try {
      _currentProcess?.kill();
      Process.start('paplay', [path]).then((p) {
        _currentProcess = p;
      }).catchError((_) {
        // Запасной вариант для PipeWire без paplay
        Process.start('pw-play', [path]).then((p) {
          _currentProcess = p;
        }).catchError((_) {});
      });
    } catch (_) {}
  }
}
