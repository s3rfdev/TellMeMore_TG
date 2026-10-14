// Смоук-тест TDLib без UI: грузим libtdjson, инициализируем параметры
// и ждём authorizationStateWaitPhoneNumber. Запуск: dart run tool/td_smoke.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:tg_answer/config/credentials.dart';
import 'package:tg_answer/data/tdlib/td_json_ffi.dart';

Future<void> main() async {
  final ffi = TdJsonFfi.tryOpen();
  if (ffi == null) {
    stdout.writeln('FAIL: libtdjson не найдена');
    exit(1);
  }
  stdout.writeln('OK: libtdjson загружена');
  ffi.setLogLevel(3);
  final client = ffi.createClient();

  var paramsSent = false;
  var phoneWait = false;
  final watchdog = Timer(const Duration(seconds: 30), () {
    stdout.writeln('FAIL: таймаут ожидания authorizationStateWaitPhoneNumber');
    exit(2);
  });

  Timer.periodic(const Duration(milliseconds: 80), (timer) {
    while (true) {
      final json = client.receive(timeoutSeconds: 0.0);
      if (json == null) break;
      final m = jsonDecode(json) as Map<String, dynamic>;
      final type = m['@type'];
      if (type == 'error') {
        stdout.writeln('TDLib error: ${m['message']}');
      } else if (type == 'updateAuthorizationState') {
        final state =
            (m['authorization_state'] as Map<String, dynamic>)['@type'];
        stdout.writeln('AUTH: $state');
        if (state == 'authorizationStateWaitTdlibParameters' && !paramsSent) {
          paramsSent = true;
          final request = {
            '@type': 'setTdlibParameters',
            'use_test_dc': false,
            'database_directory': '/tmp/td_smoke_db',
            'files_directory': '/tmp/td_smoke_files',
            'database_encryption_key': '',
            'use_file_database': true,
            'use_chat_info_database': true,
            'use_message_database': true,
            'use_secret_chats': false,
            'api_id': TgCredentials.apiId,
            'api_hash': TgCredentials.apiHash,
            'system_language_code': 'en',
            'device_model': 'Desktop',
            'system_version': Platform.operatingSystemVersion,
            'application_version': '1.0.0',
          };
          stdout.writeln('SEND: ${jsonEncode(request)}');
          client.send(request);
        }
        if (state == 'authorizationStateWaitEncryptionKey') {
          client.send({'@type': 'checkDatabaseEncryptionKey', 'encryption_key': ''});
        }
        if (state == 'authorizationStateWaitPhoneNumber') {
          phoneWait = true;
          stdout.writeln('SUCCESS: TDLib готов принять номер телефона');
          watchdog.cancel();
          timer.cancel();
          exit(0);
        }
      }
    }
    if (phoneWait) timer.cancel();
  });

  await Future.delayed(const Duration(minutes: 5));
}
