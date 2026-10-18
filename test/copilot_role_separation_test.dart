import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tg_answer/data/models/tg_chat.dart';
import 'package:tg_answer/features/ai_copilot/models/ai_settings_model.dart';
import 'package:tg_answer/features/ai_copilot/models/copilot_session.dart';
import 'package:tg_answer/features/ai_copilot/services/copilot_prompt_builder.dart';

void main() {
  group('Copilot Role Separation & Multilingual Tests', () {
    final session = CopilotSession(
      id: 'test_session',
      title: 'Test Session',
      agentRole: 'Negotiator',
      avatarIcon: Icons.auto_awesome,
      avatarColor: const Color(0xFF5288C1),
    );

    final settings = AiSettings(
      model: 'gemini-3.5-flash-lite',
      provider: 'Google Gemini',
      geminiKey: 'test_key',
    );

    final dummyChat = TgChat(
      id: '12345',
      title: 'Taras Interlocutor',
      avatarEmoji: 'TI',
      avatarColor: 0xFF5288C1,
      sender: 'Taras Interlocutor',
      headerSubtitle: 'online',
      preview: 'Hello from Me',
      time: '12:01',
      messages: [
        TgMessage(
          id: 1,
          kind: MessageKind.text,
          text: 'Hello from Taras',
          time: '12:00',
          outgoing: false,
          senderName: 'Taras Interlocutor',
        ),
        TgMessage(
          id: 2,
          kind: MessageKind.text,
          text: 'Hello from Me',
          time: '12:01',
          outgoing: true,
        ),
      ],
    );

    test('buildSandwichPrompt (Russian) formats explicit roles and legend', () async {
      final res = await CopilotPromptBuilder.instance.buildSandwichPrompt(
        session: session,
        settings: settings,
        query: 'What do you think of Taras?',
        matchedChat: dummyChat,
        isRu: true,
      );

      final prompt = res.systemPrompt;

      // Verify explicit role tags
      expect(prompt, contains('[Пользователь (Вы)]: Hello from Me'));
      expect(prompt, contains('[Собеседник (Taras Interlocutor)]: Hello from Taras'));

      // Verify legend and anti-hallucination directive
      expect(prompt, contains('ВАЖНЕЙШЕЕ ПРАВИЛО РАЗДЕЛЕНИЯ РОЛЕЙ:'));
      expect(prompt, contains('«[Пользователь (Вы)]» — это САМ ПОЛЬЗОВАТЕЛЬ'));
      expect(prompt, contains('«[Собеседник (Taras Interlocutor)]» — это его ОППОНЕНТ / ВИЗАВИ'));
      expect(prompt, contains('СТРОЖАЙШЕ ЗАПРЕЩЕНО путать роли'));
    });

    test('buildSandwichPrompt (English) formats explicit roles and legend', () async {
      final res = await CopilotPromptBuilder.instance.buildSandwichPrompt(
        session: session,
        settings: settings,
        query: 'What do you think of Taras?',
        matchedChat: dummyChat,
        isRu: false,
      );

      final prompt = res.systemPrompt;

      // Verify explicit role tags
      expect(prompt, contains('[User (You)]: Hello from Me'));
      expect(prompt, contains('[Interlocutor (Taras Interlocutor)]: Hello from Taras'));

      // Verify legend and anti-hallucination directive
      expect(prompt, contains('CRITICAL ROLE SEPARATION RULE:'));
      expect(prompt, contains('"[User (You)]" denotes the USER HIMSELF'));
      expect(prompt, contains('"[Interlocutor (Taras Interlocutor)]" denotes his OPPONENT / COUNTERPART'));
      expect(prompt, contains('STRICTLY FORBIDDEN to invert roles'));
    });
  });
}
