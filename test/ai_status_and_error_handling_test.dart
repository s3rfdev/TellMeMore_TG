import 'package:flutter_test/flutter_test.dart';
import 'package:tg_answer/features/ai_copilot/models/copilot_session.dart';
import 'package:tg_answer/state/app_state.dart';

void main() {
  group('AI Status and Error Handling Tests', () {
    test('CopilotMessage isError flag operates correctly', () {
      final normalMsg = CopilotMessage(
        text: 'Привет, как дела?',
        isUser: true,
      );
      expect(normalMsg.isError, isFalse);

      final errorMsg = CopilotMessage(
        text: '⚠️ Не удалось получить ответ от нейросети.',
        isUser: false,
        isError: true,
      );
      expect(errorMsg.isError, isTrue);

      final copiedMsg = errorMsg.copyWith(text: 'Обновленная ошибка');
      expect(copiedMsg.isError, isTrue);
      expect(copiedMsg.text, 'Обновленная ошибка');

      final resetMsg = errorMsg.copyWith(isError: false);
      expect(resetMsg.isError, isFalse);
    });

    test('AppState.aiProcessingStatus updates and notifies listeners', () {
      String? lastStatus;
      void listener() {
        lastStatus = AppState.aiProcessingStatus.value;
      }

      AppState.aiProcessingStatus.addListener(listener);

      AppState.aiProcessingStatus.value = '🧠 Обработка чата...';
      expect(lastStatus, '🧠 Обработка чата...');

      AppState.aiProcessingStatus.value = '⚡ Запрос к Gemini...';
      expect(lastStatus, '⚡ Запрос к Gemini...');

      AppState.aiProcessingStatus.value = null;
      expect(lastStatus, isNull);

      AppState.aiProcessingStatus.removeListener(listener);
    });

    test('Inline AI command prefix matching', () {
      const command1 = '/ai Какой план на сегодня?';
      const command2 = '@ai Сформулируй вежливый отказ';
      const command3 = '/ask Поясни последний вопрос';
      const normalMsg = 'Привет, как дела? /ai не команда здесь';

      final pattern = RegExp(r'^(/ai|@ai|/ask)\s+');

      expect(command1.startsWith('/ai '), isTrue);
      expect(command1.replaceFirst(pattern, '').trim(), 'Какой план на сегодня?');

      expect(command2.startsWith('@ai '), isTrue);
      expect(command2.replaceFirst(pattern, '').trim(), 'Сформулируй вежливый отказ');

      expect(command3.startsWith('/ask '), isTrue);
      expect(command3.replaceFirst(pattern, '').trim(), 'Поясни последний вопрос');

      expect(normalMsg.startsWith(pattern), isFalse);
    });
  });
}
