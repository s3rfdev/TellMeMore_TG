import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tg_answer/features/ai_copilot/models/ai_settings_model.dart';
import 'package:tg_answer/features/ai_copilot/models/copilot_session.dart';
import 'package:tg_answer/features/ai_copilot/services/copilot_session_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Multi-Agent Copilot & Volume Compression Tests', () {
    final store = CopilotSessionStore.instance;

    test('Initial store has default copilot assistant without hardcoded agents', () {
      final sessions = store.sessions.value;
      expect(sessions.isNotEmpty, isTrue);
      expect(sessions.any((s) => s.id == 'main_copilot'), isTrue);
      expect(store.activeSession.id, sessions.first.id);
    });

    test('Token estimation accurately accounts for Cyrillic and ASCII', () {
      final asciiText = 'Hello world! This is a simple test prompt for LLM.';
      final asciiTokens = CopilotMessage.estimateTokens(asciiText);
      expect(asciiTokens, greaterThan(5));
      expect(asciiTokens, lessThan(30));

      final cyrillicText = 'Привет! Это тестовое сообщение для проверки подсчета токенов.';
      final cyrillicTokens = CopilotMessage.estimateTokens(cyrillicText);
      expect(cyrillicTokens, greaterThan(15));
      expect(cyrillicTokens, lessThan(45));
    });

    test('Creating a new Copilot chat creates isolated agent session', () {
      final initialCount = store.sessions.value.length;
      final newAgent = store.createSession(
        title: 'Тестовый агент парсинга',
        role: 'Data Scraper',
        prompt: 'Парси участников групп и извлекай номера телефонов.',
        model: 'glm-5',
        icon: Icons.search_rounded,
        color: const Color(0xFF00C48C),
      );

      expect(store.sessions.value.length, initialCount + 1);
      expect(store.activeSessionId.value, newAgent.id);
      expect(store.activeSession.title, 'Тестовый агент парсинга');
      expect(store.activeSession.agentRole, 'Data Scraper');
      expect(store.activeSession.systemPrompt, contains('Парси участников'));
    });

    test('Short conversational messages do NOT trigger volume compression prematurely', () {
      final session = store.activeSession;
      final settings = AiSettings(
        contextCompression: true,
        compressionMode: 'volume',
        compressionVolumeThreshold: 2000,
        compressionKeepRawCount: 4,
      );

      // Добавим 10 коротких сообщений ("ок", "да", "хорошо")
      for (int i = 0; i < 10; i++) {
        store.addMessage(
          session.id,
          CopilotMessage(text: 'Ок $i', isUser: i.isEven),
        );
      }

      // Объем токенов коротких сообщений намного меньше 2000 токенов
      final triggered = store.checkAndAutoCompress(session.id, settings);
      expect(triggered, isFalse);
      expect(session.contextSummary, isNull);
    });

    test('Exceeding volume threshold triggers auto-compression and preserves raw window', () {
      final session = store.activeSession;
      final settings = AiSettings(
        contextCompression: true,
        compressionMode: 'volume',
        compressionVolumeThreshold: 500, // низкий порог для проверки
        compressionKeepRawCount: 4, // сохраняем 4 последних сырых
      );

      // Добавляем длинные объемные сообщения (код, логи)
      for (int i = 0; i < 6; i++) {
        store.addMessage(
          session.id,
          CopilotMessage(
            text: 'Длинное сообщение $i с большим описанием архитектуры TDLib, Isolate воркеров, ' * 12,
            isUser: i.isEven,
          ),
        );
      }

      expect(session.totalTokens, greaterThan(500));

      final triggered = store.checkAndAutoCompress(session.id, settings);
      expect(triggered, isTrue);

      // Проверяем, что контекст сжат: появилось резюме
      expect(session.contextSummary, isNotNull);
      expect(session.contextSummary, contains('Сжатая выжимка контекста'));
      expect(session.summaryTokenCount, greaterThan(0));

      // Проверяем, что в сыром виде осталось ровно 4 последних сообщения
      expect(session.messages.length, 4);
    });

    test('Sandwich prompt assembly correctly structures the 4 layers', () {
      final session = store.activeSession;
      final settings = AiSettings();

      final sandwich = store.buildSandwichPrompt(
        session,
        settings,
        'Сделай экспорт данных',
      );

      // Слой 1: Директивы и системный промпт (верхний хлеб)
      expect(sandwich['systemSlice'], contains('SYSTEM DIRECTIVES & AGENT ROLE'));
      expect(sandwich['systemSlice'], contains(session.agentRole));
      expect(sandwich['systemTokens'], greaterThan(0));

      // Слой 2: Сжатое саммари (начинка 1)
      expect(sandwich['summarySlice'], isNotNull);
      expect(sandwich['summaryTokens'], greaterThan(0));

      // Слой 3: Сырые сообщения (начинка 2)
      final rawList = sandwich['rawSlice'] as List<CopilotMessage>;
      expect(rawList.length, 4);
      expect(sandwich['rawTokens'], greaterThan(0));

      // Слой 4: Запрос пользователя (нижний хлеб)
      expect(sandwich['bottomSlice'], contains('Сделай экспорт данных'));
      expect(sandwich['bottomTokens'], greaterThan(0));

      // Суммарный объем
      expect(sandwich['totalTokens'], greaterThan(100));
    });

    test('Renaming and deleting sessions works cleanly', () {
      final session = store.activeSession;
      store.renameSession(session.id, 'Обновленное название');
      expect(store.activeSession.title, 'Обновленное название');

      final countBefore = store.sessions.value.length;
      final toDeleteId = session.id;
      store.deleteSession(toDeleteId);

      expect(store.sessions.value.length, countBefore - 1);
      expect(store.activeSessionId.value, isNot(toDeleteId));
    });

    test('CopilotSession serialization toJson and fromJson preserves all fields', () {
      final msg = CopilotMessage(
        id: 'msg-1',
        text: 'Привет от пользователя',
        isUser: true,
        toolName: 'search',
        toolOutput: 'result',
      );
      final session = CopilotSession(
        id: 'session-serialize-test',
        title: 'Тестовая сессия',
        agentRole: 'Tester',
        systemPrompt: 'Будь краток',
        avatarIcon: Icons.bolt,
        avatarColor: Colors.blue,
        messages: [msg],
        contextSummary: 'Краткая выжимка',
        summaryTokenCount: 15,
        messageLimit: 40,
        ragPrompt: 'Факты',
        ragFactSummary: 'Сухие факты',
        ragFactSummaryCount: 5,
        autoCompressEnabled: false,
        autoCompressThreshold: 25,
        keepRawCount: 8,
      );

      final json = session.toJson();
      final restored = CopilotSession.fromJson(json);

      expect(restored.id, session.id);
      expect(restored.title, session.title);
      expect(restored.agentRole, session.agentRole);
      expect(restored.systemPrompt, session.systemPrompt);
      expect(restored.avatarIcon.codePoint, session.avatarIcon.codePoint);
      expect(restored.avatarColor.value, session.avatarColor.value);
      expect(restored.messages.length, 1);
      expect(restored.messages.first.id, msg.id);
      expect(restored.messages.first.text, msg.text);
      expect(restored.messages.first.toolName, msg.toolName);
      expect(restored.contextSummary, session.contextSummary);
      expect(restored.summaryTokenCount, 15);
      expect(restored.messageLimit, 40);
      expect(restored.autoCompressEnabled, isFalse);
      expect(restored.keepRawCount, 8);
    });
  });
}
