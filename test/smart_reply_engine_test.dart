import 'package:flutter_test/flutter_test.dart';
import 'package:tg_answer/data/models/tg_chat.dart';
import 'package:tg_answer/features/ai_copilot/models/contact_dossier.dart';
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

    test('generateAutoReply leverages ContactDossier goal: Закрыть сделку', () {
      final messages = [
        const TgMessage(
          kind: MessageKind.text,
          text: 'Сколько это будет стоить и какие условия оплаты?',
          outgoing: false,
        ),
      ];

      final dossier = ContactDossier(
        chatId: 'client_1',
        goal: '🤝 Закрыть сделку',
        tone: 'Строго деловой и лаконичный',
        psychotype: 'Прагматик',
        facts: ['Бюджет утвержден'],
        summary: 'Готов к сделке',
      );

      final reply = SmartReplyEngine.generateAutoReply(
        chatTitle: 'Клиент',
        messages: messages,
        dossier: dossier,
      );

      expect(reply, contains('предоплату'));
      expect(reply, contains('счёт'));
    });

    test('generateAutoReply leverages ContactDossier goal: Позвать на свидание', () {
      final messages = [
        const TgMessage(
          kind: MessageKind.text,
          text: 'Привет! Чем занимаешься?',
          outgoing: false,
        ),
      ];

      final dossier = ContactDossier(
        chatId: 'girl_1',
        goal: '❤️ Позвать на свидание',
        tone: 'Игривый и харизматичный',
        psychotype: 'Открытая',
        facts: [],
        summary: 'Знакомство',
      );

      final reply = SmartReplyEngine.generateAutoReply(
        chatTitle: 'Аня',
        messages: messages,
        dossier: dossier,
      );

      expect(reply, contains('выбраться'));
      expect(reply, contains('кофе'));
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
