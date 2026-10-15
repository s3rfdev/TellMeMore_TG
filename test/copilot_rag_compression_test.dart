import 'package:flutter_test/flutter_test.dart';
import 'package:tg_answer/data/models/tg_chat.dart';
import 'package:tg_answer/features/ai_copilot/models/ai_settings_model.dart';
import 'package:tg_answer/features/ai_copilot/models/contact_dossier.dart';
import 'package:tg_answer/features/ai_copilot/models/copilot_session.dart';
import 'package:tg_answer/features/ai_copilot/services/copilot_session_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Copilot RAG & Dialogue Memory Compression Tests', () {
    final store = CopilotSessionStore.instance;

    test('CopilotSession initializes with customizable default RAG and dialogue prompts', () {
      final session = store.activeSession;
      expect(session.ragPrompt, contains('Извлеки ключевые сухие факты'));
      expect(session.dialogueCompressionPrompt, contains('Сформируй связную хронологическую выжимку'));
      expect(session.autoCompressEnabled, isTrue);
      expect(session.autoCompressThreshold, 20);
      expect(session.keepRawCount, 6);
    });

    test('Updating RAG and compression configuration persists in session store', () {
      final session = store.activeSession;
      const customRagLens = 'Извлекай только даты дедлайнов, ставки и реквизиты кошельков.';
      const customCompLens = 'Фиксируй только финальные решения пользователя.';

      store.updateSessionRagConfig(
        session.id,
        prompt: customRagLens,
        summary: '• 15.10.2026: дедлайн первого спринта\n• Ставка: \$50/час',
        count: 150,
      );

      store.updateSessionCompressionConfig(
        session.id,
        enabled: true,
        threshold: 30,
        keepRaw: 8,
        prompt: customCompLens,
      );

      expect(session.ragPrompt, customRagLens);
      expect(session.ragFactSummary, contains('дедлайн первого спринта'));
      expect(session.ragFactSummaryCount, 150);
      expect(session.ragFactUpdatedAt, isNotNull);

      expect(session.autoCompressThreshold, 30);
      expect(session.keepRawCount, 8);
      expect(session.dialogueCompressionPrompt, customCompLens);
    });

    test('runRagFactExtraction extracts facts and synchronizes with ContactDossier', () async {
      final session = store.activeSession;
      const chatId = 'chat_test_rag_999';

      final mockMessages = List.generate(
        50,
        (i) => TgMessage(
          id: i + 1,
          kind: MessageKind.text,
          text: i % 2 == 0 ? 'Мы договорились встретиться в пятницу в 18:00' : 'Отлично, я беру с собой ноутбук',
          outgoing: i % 2 == 0,
        ),
      );

      final result = await store.runRagFactExtraction(
        sessionId: session.id,
        chatId: chatId,
        messages: mockMessages,
        limit: 30,
        ragPrompt: 'Извлеки все договоренности и детали встречи.',
        chatTitle: 'Тестовый Чат',
      );

      expect(result.isNotEmpty, isTrue);
      expect(session.ragFactSummary, result);
      expect(session.ragFactSummaryCount, 30);

      // Проверяем синхронизацию в ContactDossierStore
      final dossier = ContactDossierStore.instance.getDossier(chatId).value;
      expect(dossier.ragFactSummary, result);
      expect(dossier.ragFactSummaryCount, 30);
      expect(dossier.ragPrompt, 'Извлеки все договоренности и детали встречи.');
    });

    test('compressSessionIntelligent compresses earlier dialogue and retains keepRawCount', () async {
      final session = store.activeSession;
      session.messages.clear();

      // Добавим 12 сообщений
      for (int i = 0; i < 12; i++) {
        store.addMessage(
          session.id,
          CopilotMessage(
            text: 'Реплика диалога $i между пользователем и агентом.',
            isUser: i.isEven,
          ),
        );
      }

      session.keepRawCount = 5;

      final success = await store.compressSessionIntelligent(session.id);
      expect(success, isTrue);

      // В сыром виде должно остаться ровно keepRawCount = 5 сообщений
      expect(session.messages.length, 5);

      // В памяти contextSummary должно появиться резюме
      expect(session.contextSummary, isNotNull);
      expect(session.contextSummary!.isNotEmpty, isTrue);
      expect(session.summaryTokenCount, greaterThan(0));
    });
  });
}
