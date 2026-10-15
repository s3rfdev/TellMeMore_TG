import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart' as ffi;
import 'package:ffi/ffi.dart' show Utf8;

/// Низкоуровневый доступ к TDLib JSON-интерфейсу (libtdjson).
class TdJsonFfi {
  TdJsonFfi._(this._lib, this._client);

  final DynamicLibrary _lib;
  final Pointer<Void> _client;

  late final Pointer<Void> Function() _create = _lib
      .lookup<NativeFunction<Pointer<Void> Function()>>('td_json_client_create')
      .asFunction();

  late final void Function(Pointer<Void>, Pointer<Utf8>) _send = _lib
      .lookup<NativeFunction<Void Function(Pointer<Void>, Pointer<Utf8>)>>(
          'td_json_client_send')
      .asFunction();

  late final Pointer<Utf8> Function(Pointer<Void>, double) _receive = _lib
      .lookup<NativeFunction<Pointer<Utf8> Function(Pointer<Void>, Double)>>(
          'td_json_client_receive')
      .asFunction();

  late final Pointer<Utf8> Function(Pointer<Void>, Pointer<Utf8>) _execute =
      _lib
          .lookup<NativeFunction<Pointer<Utf8> Function(
              Pointer<Void>, Pointer<Utf8>)>>('td_json_client_execute')
          .asFunction();

  late final void Function(Pointer<Void>, Pointer<Utf8>) _destroy = _lib
      .lookup<NativeFunction<Void Function(Pointer<Void>, Pointer<Utf8>)>>(
          'td_json_client_destroy')
      .asFunction();

  late final void Function(int)? _setLogLevel = () {
    try {
      return _lib
          .lookup<NativeFunction<Void Function(Int32)>>(
              'td_set_log_verbosity_level')
          .asFunction<void Function(int)>();
    } catch (_) {
      return null;
    }
  }();

  /// Причина последней неудачной загрузки — для диагностики в UI.
  static String? lastError;

  /// Ищет libtdjson по стандартным путям системы и бандла приложения.
  static TdJsonFfi? tryOpen() {
    if (Platform.isAndroid) {
      try {
        final lib = DynamicLibrary.open('libtdjson.so');
        final probe = TdJsonFfi._(lib, Pointer<Void>.fromAddress(0));
        probe.setLogLevel(2);
        return probe;
      } catch (e) {
        lastError = 'Android DynamicLibrary.open(libtdjson.so) error: $e';
        return null;
      }
    }

    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final home = Platform.environment['HOME'] ?? '';
    final candidates = <String>[
      // Рядом с бинарником или в lib бандла (Linux / macOS)
      '$exeDir/lib/libtdjson.so',
      '$exeDir/libtdjson.so',
      '$exeDir/../Frameworks/libtdjson.dylib',
      '$exeDir/libtdjson.dylib',
      // Текущая рабочая директория
      './libtdjson.so',
      'libtdjson.so',
      'libtdjson.dylib',
      'tdjson.dll',
      // Пользовательские и системные пути Linux
      if (home.isNotEmpty) '$home/.local/lib/libtdjson.so',
      '/usr/local/lib/libtdjson.so',
      '/usr/lib/libtdjson.so',
      '/usr/lib/x86_64-linux-gnu/libtdjson.so',
      // macOS Homebrew
      '/opt/homebrew/lib/libtdjson.dylib',
      '/usr/local/lib/libtdjson.dylib',
      '/usr/local/opt/tdlib/lib/libtdjson.dylib',
    ];

    final failures = <String>[];
    for (final path in candidates) {
      try {
        final lib = DynamicLibrary.open(path);
        final probe = TdJsonFfi._(lib, Pointer<Void>.fromAddress(0));
        probe.setLogLevel(2); // проверяем доступность вызова
        return probe;
      } catch (e) {
        failures.add('$path → $e');
      }
    }
    lastError = failures.join('\n');
    return null;
  }

  /// Создаёт клиент TDLib.
  TdJsonFfi createClient() => TdJsonFfi._(_lib, _create());

  /// Оборачивает существующий адрес клиента (для фонового изолята).
  static TdJsonFfi attach(int clientAddress) {
    final probe = tryOpen();
    if (probe == null) {
      throw StateError('libtdjson не найдена');
    }
    return TdJsonFfi._(probe._lib, Pointer<Void>.fromAddress(clientAddress));
  }

  /// Адрес клиента — можно передать в другой изолят/функцию.
  int get clientAddress => _client.address;

  /// Отправляет запрос (неблокирующий, потокобезопасный).
  void send(Map<String, dynamic> request) {
    final p = _toNativeUtf8(jsonEncode(request));
    _send(_client, p);
    ffi.malloc.free(p);
  }

  /// Синхронный execute; при [useNullClient] работает до создания клиента.
  Map<String, dynamic>? execute(Map<String, dynamic> request,
      {bool useNullClient = false}) {
    final p = _toNativeUtf8(jsonEncode(request));
    final client = useNullClient ? Pointer<Void>.fromAddress(0) : _client;
    final result = _execute(client, p);
    ffi.malloc.free(p);
    if (result == nullptr) return null;
    final s = _fromNativeUtf8(result);
    // строки, выделенные TDLib, освобождаем через td_json_client_destroy
    _destroy(Pointer<Void>.fromAddress(0), result);
    return jsonDecode(s) as Map<String, dynamic>;
  }

  /// Блокирующее чтение очереди обновлений (вызывать из фонового изолята).
  String? receive({double timeoutSeconds = 1.0}) {
    final result = _receive(_client, timeoutSeconds);
    if (result == nullptr) return null;
    final s = _fromNativeUtf8(result);
    _destroy(Pointer<Void>.fromAddress(0), result);
    return s;
  }

  void setLogLevel(int level) {
    final setter = _setLogLevel;
    if (setter != null) {
      setter(level);
    } else {
      execute({'@type': 'setLogVerbosityLevel', 'new_verbosity_level': level}, useNullClient: true);
    }
  }

  static Pointer<Utf8> _toNativeUtf8(String s) {
    final units = utf8.encode(s);
    final p = ffi.malloc.allocate<Uint8>(units.length + 1);
    for (var i = 0; i < units.length; i++) {
      p[i] = units[i];
    }
    p[units.length] = 0;
    return p.cast();
  }

  static String _fromNativeUtf8(Pointer<Utf8> p) {
    final bytes = <int>[];
    var i = 0;
    // ignore: avoid infinite loops
    while (true) {
      final b = p.cast<Uint8>()[i];
      if (b == 0) break;
      bytes.add(b);
      i++;
    }
    return utf8.decode(bytes);
  }
}
