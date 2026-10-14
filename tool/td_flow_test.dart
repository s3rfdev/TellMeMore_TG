// Инструментальный тест потока «воркер → история чата» без UI.
// Переиспользует живую сессию из ~/Documents/tdlib-db (если есть).
// Запуск: dart run --define=TD_DEBUG=true tool/td_flow_test.dart
// ВАЖНО: запускать только при закрытом приложении (одна база — один клиент).
import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:tg_answer/data/tdlib/td_json_ffi.dart';
import 'package:tg_answer/data/tdlib/td_worker.dart';

Future<void> main() async {
  final ffi = TdJsonFfi.tryOpen();
  if (ffi == null) {
    stdout.writeln('FAIL: libtdjson не найдена');
    exit(1);
  }
  ffi.setLogLevel(1);
  final client = ffi.createClient();

  final ui = ReceivePort();
  final cmdCompleter = Completer<SendPort>();
  final pongCompleter = Completer<int>();
  final phoneResult = Completer<String>();
  final chatsCompleter = Completer<List<dynamic>>();
  final historyCompleter = Completer<String>();

  ui.listen((m) {
    final msg = Map<String, dynamic>.from(m as Map);
    switch (msg['type']) {
      case 'ready':
        stdout.writeln('FLOW: worker ready');
        if (!cmdCompleter.isCompleted) {
          cmdCompleter.complete(msg['cmd'] as SendPort);
        }
      case 'pong':
        final rtt = DateTime.now().millisecondsSinceEpoch - (msg['t'] as int);
        stdout.writeln('FLOW: pong, rtt=${rtt}ms');
        if (!pongCompleter.isCompleted) pongCompleter.complete(rtt);
      case 'auth':
        stdout.writeln('FLOW: auth = ${msg['state']}');
        if (msg['state'] == 'authorizationStateWaitCode' &&
            !phoneResult.isCompleted) {
          phoneResult.complete('WAIT_CODE — сервер принял номер!');
        }
      case 'error':
        stdout.writeln('FLOW: error = ${msg['message']}');
        if (!phoneResult.isCompleted) {
          phoneResult.complete('ERROR: ${msg['message']}');
        }
      case 'chats':
        final chats = msg['chats'] as List;
        stdout.writeln('FLOW: chats snapshot, ${chats.length} chats');
        if (!chatsCompleter.isCompleted && chats.isNotEmpty) {
          chatsCompleter.complete(chats);
        }
      case 'history':
        final payload = Map<String, dynamic>.from(msg['messages'] as Map);
        payload.forEach((key, value) {
          final hist = value as dynamic;
          final messages = hist.messages as List<dynamic>;
          stdout.writeln(
              'FLOW: history for $key: ${messages.length} msgs, hasMore=${hist.hasMore}');
          if (!historyCompleter.isCompleted && messages.isNotEmpty) {
            final first = messages.first as dynamic;
            final text = first.text as String;
            final preview = text.isEmpty
                ? first.kind.name as String
                : text.substring(0, text.length > 40 ? 40 : text.length);
            historyCompleter.complete('chat $key: "$preview" @ ${first.time}');
          }
        });
    }
  });

  final home = Platform.environment['HOME'] ?? '/tmp';
  await Isolate.spawn(TdWorker.entry, {
    'clientAddress': client.clientAddress,
    'ui': ui.sendPort,
    'dbDir': '$home/Documents/tdlib-db',
    'filesDir': '$home/Documents/tdlib-files',
  }, debugName: 'flow-test-worker');

  final cmd = await cmdCompleter.future.timeout(const Duration(seconds: 15));
  stdout.writeln('FLOW: got cmd port');

  // 1. Пинг: команды обрабатываются?
  cmd.send({'type': 'ping', 't': DateTime.now().millisecondsSinceEpoch});
  final rtt = await pongCompleter.future.timeout(const Duration(seconds: 5));
  stdout.writeln('FLOW: commands processed, rtt=${rtt}ms');

  // 2. Фейковый номер: формат запроса верный? Любой ответ сервера — успех.
  cmd.send({'type': 'phone', 'value': '+79990000000'});
  final phone = await phoneResult.future.timeout(const Duration(seconds: 25));
  stdout.writeln('FLOW: phone request → $phone');
  exit(0);
}
