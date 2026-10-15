import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tg_answer/data/models/tg_chat.dart';
import 'package:tg_answer/features/ai_copilot/models/contact_dossier.dart';
import 'package:tg_answer/features/chat/widgets/chat_system_prompt_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testChat = TgChat(
    id: 'test-direct-chat',
    title: 'Дмитрий Архитектор',
    sender: 'Дмитрий',
    preview: 'Жду архитектурную схему',
    time: '12:00',
    headerSubtitle: 'Architect',
    avatarEmoji: '⚡',
    avatarColor: 0xFF51B2FF,
  );

  group('ContactDossierStore & Dynamic Directives Tests', () {
    test('Default dossier has no hardcoded mock personas', () {
      final dossier = ContactDossierStore.instance.getDossier('test-clean-chat').value;
      expect(dossier.goal, isEmpty);
      expect(dossier.tone, isEmpty);
      expect(dossier.systemPrompt, isEmpty);
      expect(dossier.facts, isEmpty);
    });

    test('Updating system prompt, goal, and tone saves in ContactDossierStore', () {
      final store = ContactDossierStore.instance;
      store.updateSystemPrompt('test-direct-chat', 'Отвечай кратко, как технический лид.');
      store.updateGoal('test-direct-chat', 'Согласовать спецификацию протокола');
      store.updateTone('test-direct-chat', 'Лаконичный, инженерный');

      final saved = store.getDossier('test-direct-chat').value;
      expect(saved.systemPrompt, 'Отвечай кратко, как технический лид.');
      expect(saved.goal, 'Согласовать спецификацию протокола');
      expect(saved.tone, 'Лаконичный, инженерный');
    });
  });

  group('ChatSystemPromptDialog Widget Tests', () {
    testWidgets('Renders title, text fields and save button', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ChatSystemPromptDialog.show(context, testChat),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Check title and chat context
      expect(find.textContaining('Системный промпт AI'), findsOneWidget);
      expect(find.textContaining('Дмитрий Архитектор'), findsWidgets);

      // Check form fields
      expect(find.byType(TextField), findsNWidgets(3));

      // Check action buttons
      expect(find.text('Открыть в Copilot'), findsOneWidget);
      expect(find.text('Сохранить'), findsOneWidget);
    });

    testWidgets('Saving from dialog updates dossier store', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ChatSystemPromptDialog.show(context, testChat),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Enter custom prompt directives
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'Всегда предлагай готовые куски кода Dart.');
      await tester.pumpAndSettle();

      // Click save
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));

      final updated = ContactDossierStore.instance.getDossier('test-direct-chat').value;
      expect(updated.systemPrompt, 'Всегда предлагай готовые куски кода Dart.');
    });
  });
}
