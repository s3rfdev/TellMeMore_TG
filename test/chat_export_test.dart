import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tg_answer/data/models/tg_chat.dart';
import 'package:tg_answer/features/ai_copilot/models/contact_dossier.dart';
import 'package:tg_answer/features/chat/services/chat_export_service.dart';
import 'package:tg_answer/features/chat/widgets/chat_export_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testChat = TgChat(
    id: 'test-user',
    title: 'Алексей Смирнов',
    sender: 'Алексей',
    preview: 'Обсудим проект?',
    time: '14:20',
    headerSubtitle: 'Senior Lead Dev @ Fintech',
    avatarEmoji: '👨‍💻',
    avatarColor: 0xFF2A85FF,
    messages: const [
      TgMessage(
        kind: MessageKind.date,
        text: '14 октября',
      ),
      TgMessage(
        id: 1,
        kind: MessageKind.text,
        text: 'Здравствуйте! Готовы провести собеседование в четверг?',
        time: '14:15',
        outgoing: false,
      ),
      TgMessage(
        id: 2,
        kind: MessageKind.text,
        text: 'Добрый день, Алексей! Да, четверг в 15:00 отлично подойдет.',
        time: '14:20',
        outgoing: true,
      ),
    ],
  );

  final testDossier = ContactDossier(
    chatId: 'test-user',
    goal: '🎯 Пройти техническое собеседование и согласовать оффер 450k',
    tone: 'Уверенный и экспертный',
    psychotype: 'Прагматик: ценит точность в архитектуре, опыт в highload и системный подход',
    summary: 'Обсуждали позицию Lead Flutter/C++ инженера. Назначили созвон на четверг.',
    facts: [
      'Опыт 8+ лет в финтехе',
      'Задает вопросы по многопоточности и FFI',
      'Оффер в вилке 400-500k',
    ],
  );

  group('ChatExportService Unit Tests', () {
    test('formatAdvisorProfile includes structured context for AI Interview Advisor', () {
      final text = ChatExportService.instance.formatAdvisorProfile(testChat, testDossier);

      expect(text, contains('📋 ПРОФИЛЬ СОБЕСЕДНИКА ДЛЯ AI-ЭДВАЙЗЕРА'));
      expect(text, contains('Алексей Смирнов'));
      expect(text, contains('Senior Lead Dev @ Fintech'));
      expect(text, contains('🎯 ЦЕЛЬ ОБЩЕНИЯ (СТРАТЕГИЧЕСКАЯ ЗАДАЧА):'));
      expect(text, contains('Пройти техническое собеседование и согласовать оффер 450k'));
      expect(text, contains('🧠 ПСИХОТИП И СТИЛЬ МЫШЛЕНИЯ:'));
      expect(text, contains('Прагматик'));
      expect(text, contains('📌 КЛЮЧЕВЫЕ ФАКТЫ И CRM-ПАМЯТЬ:'));
      expect(text, contains('Опыт 8+ лет в финтехе'));
      expect(text, contains('Задает вопросы по многопоточности и FFI'));
      expect(text, contains('💡 ИНСТРУКЦИЯ ДЛЯ АССИСТЕНТА ВО ВРЕМЯ РАЗГОВОРА (LIVE PROMPT):'));
    });

    test('formatChatHistory exports all messages with timestamps and senders', () {
      final text = ChatExportService.instance.formatChatHistory(testChat, testChat.messages);

      expect(text, contains('💬 ИСТОРИЯ ПЕРЕПИСКИ: Алексей Смирнов'));
      expect(text, contains('--- 14 октября ---'));
      expect(text, contains('[14:15] Алексей Смирнов: Здравствуйте! Готовы провести собеседование в четверг?'));
      expect(text, contains('[14:20] Вы: Добрый день, Алексей! Да, четверг в 15:00 отлично подойдет.'));
    });

    test('formatFullArchive combines advisor profile and chat history', () {
      final text = ChatExportService.instance.formatFullArchive(testChat, testDossier, testChat.messages);

      expect(text, contains('ПРОФИЛЬ СОБЕСЕДНИКА ДЛЯ AI-ЭДВАЙЗЕРА'));
      expect(text, contains('ИСТОРИЯ ПЕРЕПИСКИ: Алексей Смирнов'));
    });

    test('exportToJsonString creates valid JSON with metadata, profile, and messages', () {
      final jsonStr = ChatExportService.instance.exportToJsonString(
        testChat,
        testDossier,
        testChat.messages,
        type: ExportContentType.fullArchive,
      );

      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      expect(decoded['contact']['title'], 'Алексей Смирнов');
      expect(decoded['advisor_profile']['goal'], contains('450k'));
      expect(decoded['advisor_profile']['crm_facts'].length, 3);
      expect(decoded['messages'].length, 3); // date + 2 text msgs
    });

    test('saveToFile writes export file to directory', () async {
      final path = await ChatExportService.instance.saveToFile(
        fileName: 'test_export_file.txt',
        content: 'Тестовый экспорт переписки',
      );

      final file = File(path);
      expect(file.existsSync(), isTrue);
      expect(file.readAsStringSync(), 'Тестовый экспорт переписки');
      // Clean up
      try {
        file.deleteSync();
      } catch (_) {}
    });
  });

  group('ChatExportDialog Widget Tests', () {
    testWidgets('ChatExportDialog renders tabs, preview, and buttons', (tester) async {
      tester.view.physicalSize = const Size(1280, 960);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Pre-seed dossier
      ContactDossierStore.instance.getDossier('test-user').value = testDossier;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ChatExportDialog.show(
                  context,
                  testChat,
                  initialType: ExportContentType.advisorProfile,
                ),
                child: const Text('Open Export'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Export'));
      await tester.pumpAndSettle();

      // Check Dialog title and tabs
      expect(find.text('Экспорт данных чата и профиля'), findsOneWidget);
      expect(find.text('🎯 Профиль (AI-эдвайзер)'), findsOneWidget);
      expect(find.text('💬 Переписка'), findsOneWidget);
      expect(find.text('📦 Всё вместе'), findsOneWidget);

      // Check Format switcher
      expect(find.text('TXT / Markdown'), findsOneWidget);
      expect(find.text('JSON'), findsOneWidget);

      // Check Action buttons
      expect(find.text('Копировать'), findsOneWidget);
      expect(find.text('Сохранить файл'), findsOneWidget);

      // Switch to Chat tab
      await tester.tap(find.text('💬 Переписка'));
      await tester.pumpAndSettle();
      expect(find.textContaining('ИСТОРИЯ ПЕРЕПИСКИ'), findsOneWidget);

      // Switch to JSON format
      await tester.tap(find.text('JSON'));
      await tester.pumpAndSettle();
      expect(find.textContaining('"export_metadata"'), findsOneWidget);

      // Tap Copy button
      await tester.tap(find.text('Копировать'));
      await tester.pump(const Duration(milliseconds: 100));

      // Tap Save button
      await tester.tap(find.text('Сохранить файл'));
      await tester.pump(const Duration(milliseconds: 500));
    });
  });
}
