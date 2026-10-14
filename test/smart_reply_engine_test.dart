import 'package:flutter_test/flutter_test.dart';
import 'package:tg_answer/data/models/tg_chat.dart';
import 'package:tg_answer/features/ai_copilot/services/smart_reply_engine.dart';

void main() {
  group('SmartReplyEngine Tests', () {
    test('generateAutoReply responds constructively to ticket/return topic', () {
      final messages = [
        const TgMessage(
          kind: MessageKind.text,
          text: 'раньше они просто деньги возвращали. Ну и при этом можно же реальный билет купить',
          outgoing: false,
        ),
      ];

      final reply = SmartReplyEngine.generateAutoReply(
        chatTitle: 'Филиппины',
        messages: messages,
      );

      expect(reply, contains('правила поменялись'));
      expect(reply, isNotEmpty);
    });

    test('generateInstructionReply recognizes dismissive/unpleasant directive without rudeness', () {
      final messages = [
        const TgMessage(
          kind: MessageKind.text,
          text: 'Слушай, помоги мне с одним вопросом срочно!',
          outgoing: false,
        ),
      ];

      final reply = SmartReplyEngine.generateInstructionReply(
        chatTitle: 'Дмитрий',
        messages: messages,
        instruction: 'Мне этот человек неприятен, как лучше ответить чтобы отстал без грубости',
      );

      expect(reply, contains('загружен'));
      expect(reply, contains('поставим на паузу'));
    });

    test('generateInstructionReply recognizes call / voice directive', () {
      final reply = SmartReplyEngine.generateInstructionReply(
        chatTitle: 'Партнер',
        messages: [],
        instruction: 'Предложи созвониться голосом',
      );

      expect(reply, contains('созвонимся'));
      expect(reply, contains('голосом'));
    });
  });
}
