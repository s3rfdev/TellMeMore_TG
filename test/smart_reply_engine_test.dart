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

    test('generateAutoReply evaluates the latest messages when list has 40+ messages', () {
      // 35 old messages about tickets
      final messages = List.generate(
        35,
        (i) => TgMessage(
          kind: MessageKind.text,
          text: 'Старое сообщение про авиабилеты $i',
          outgoing: false,
        ),
      );
      // Latest message at the end is about contacts screenshot
      messages.add(
        const TgMessage(
          kind: MessageKind.text,
          text: 'Вот скриншот списка контактов в Телеграм',
          outgoing: false,
        ),
      );

      final reply = SmartReplyEngine.generateAutoReply(
        chatTitle: 'Коллега',
        messages: messages,
      );

      // Must respond to the latest message (contacts screenshot), NOT ancient ticket messages
      expect(reply, contains('контактов'));
    });

    test('getEffectiveMessageText handles photo with caption and empty text', () {
      const photoMsg = TgMessage(
        kind: MessageKind.image,
        text: 'Смотри на экран',
        fileName: 'screen.png',
      );
      expect(SmartReplyEngine.getEffectiveMessageText(photoMsg), equals('Смотри на экран'));

      const photoNoCaption = TgMessage(
        kind: MessageKind.image,
        text: '',
        fileName: 'profile.jpg',
      );
      expect(SmartReplyEngine.getEffectiveMessageText(photoNoCaption), contains('фото'));
    });
  });
}
