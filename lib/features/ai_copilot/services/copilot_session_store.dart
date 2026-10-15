import 'package:flutter/material.dart';

import '../../../core/localization/app_locale.dart';
import '../models/ai_settings_model.dart';
import '../models/copilot_session.dart';

/// Хранилище сессий и агентов мультиагентного Copilot.
class CopilotSessionStore {
  CopilotSessionStore._() {
    _initDefaultSessions();
  }

  static final CopilotSessionStore instance = CopilotSessionStore._();

  late final ValueNotifier<List<CopilotSession>> sessions;
  late final ValueNotifier<String> activeSessionId;

  void _initDefaultSessions() {
    final isRu = I18n.instance.isRu;
    final list = [
      CopilotSession(
        id: 'main_copilot',
        title: isRu ? '🤖 Главный Копилот' : '🤖 Main Copilot',
        agentRole: 'Copilot',
        systemPrompt: isRu
            ? 'Ты персональный AI-копилот для Telegram. Ты умеешь изучать любые переписки, отвечать на вопросы по чатам, анализировать сообщения и помогать в решении задач пользователя.'
            : 'You are a personal AI Copilot for Telegram. You can study any conversations, answer questions about chats, analyze messages, and assist with user tasks.',
        avatarIcon: Icons.auto_awesome,
        avatarColor: const Color(0xFF5288C1),
        messages: [
          CopilotMessage(
            text: isRu
                ? 'Привет! Я твой AI-копилот. Напиши мне задачу своими словами — например: *"изучи переписку с Тарасом"*, *"найди вакансии в чатах"* или *"напиши вежливый ответ"*.'
                : 'Hello! I am your AI Copilot. Give me any task in your own words — e.g.: *"study chat with Taras"*, *"find job postings in chats"*, or *"draft a polite reply"*.',
            isUser: false,
          ),
        ],
      ),
    ];

    sessions = ValueNotifier<List<CopilotSession>>(list);
    activeSessionId = ValueNotifier<String>(list.first.id);
  }

  /// Получить активную сессию Copilot.
  CopilotSession get activeSession {
    final id = activeSessionId.value;
    return sessions.value.firstWhere(
      (s) => s.id == id,
      orElse: () => sessions.value.first,
    );
  }

  /// Выбрать активную сессию по ID.
  void selectSession(String id) {
    if (sessions.value.any((s) => s.id == id)) {
      activeSessionId.value = id;
    }
  }

  /// Создать новую сессию агента.
  CopilotSession createSession({
    required String title,
    required String role,
    String? prompt,
    String? model,
    IconData? icon,
    Color? color,
  }) {
    final isRu = I18n.instance.isRu;
    final newSession = CopilotSession(
      id: 'copilot_${DateTime.now().millisecondsSinceEpoch}',
      title: title.trim().isEmpty ? (isRu ? 'Новый чат с агентом' : 'New Agent Chat') : title.trim(),
      agentRole: role.trim().isEmpty ? 'Custom Agent' : role.trim(),
      systemPrompt: prompt ?? '',
      model: model,
      avatarIcon: icon ?? Icons.auto_awesome,
      avatarColor: color ?? const Color(0xFF5288C1),
      messages: [
        CopilotMessage(
          text: isRu
              ? 'Чат создан. Роль агента: **${role.trim().isEmpty ? "Custom Agent" : role.trim()}**.\nЧем могу помочь по этой задаче?'
              : 'Chat created. Agent role: **${role.trim().isEmpty ? "Custom Agent" : role.trim()}**.\nHow can I help you with this task?',
          isUser: false,
        ),
      ],
    );

    final updated = List<CopilotSession>.from(sessions.value)..insert(0, newSession);
    sessions.value = updated;
    activeSessionId.value = newSession.id;
    return newSession;
  }

  /// Удалить сессию.
  void deleteSession(String id) {
    if (sessions.value.length <= 1) return; // Не удаляем последнюю
    final updated = List<CopilotSession>.from(sessions.value)..removeWhere((s) => s.id == id);
    sessions.value = updated;
    if (activeSessionId.value == id) {
      activeSessionId.value = updated.first.id;
    }
  }

  /// Переименовать сессию.
  void renameSession(String id, String newTitle) {
    final trimmed = newTitle.trim();
    if (trimmed.isEmpty) return;
    final current = sessions.value;
    final idx = current.indexWhere((s) => s.id == id);
    if (idx != -1) {
      current[idx].title = trimmed;
      current[idx].updatedAt = DateTime.now();
      sessions.value = List.from(current);
    }
  }

  /// Обновить системный промпт сессии.
  void updateSessionPrompt(String id, String newPrompt) {
    final current = sessions.value;
    final idx = current.indexWhere((s) => s.id == id);
    if (idx != -1) {
      current[idx].systemPrompt = newPrompt.trim();
      current[idx].updatedAt = DateTime.now();
      sessions.value = List.from(current);
    }
  }

  /// Очистить сообщения сессии.
  void clearSessionMessages(String id) {
    final isRu = I18n.instance.isRu;
    final current = sessions.value;
    final idx = current.indexWhere((s) => s.id == id);
    if (idx != -1) {
      final s = current[idx];
      s.messages.clear();
      s.contextSummary = null;
      s.summaryTokenCount = 0;
      s.messages.add(
        CopilotMessage(
          text: isRu
              ? 'История диалога очищена. Готов к новым задачам.'
              : 'Conversation history cleared. Ready for new tasks.',
          isUser: false,
        ),
      );
      s.updatedAt = DateTime.now();
      sessions.value = List.from(current);
    }
  }

  /// Добавить сообщение в сессию.
  void addMessage(String sessionId, CopilotMessage message) {
    final current = sessions.value;
    final idx = current.indexWhere((s) => s.id == sessionId);
    if (idx != -1) {
      final s = current[idx];
      s.messages.add(message);
      s.updatedAt = DateTime.now();
      sessions.value = List.from(current);
    }
  }

  /// Выполнить компрессию контекста сессии.
  /// Сохраняет [keepRawCount] последних сырых сообщений, а более ранние
  /// сообщения сжимает в структурированное резюме (Layer 1 начинки бутерброда).
  void compressSession(String sessionId, {int keepRawCount = 6}) {
    final current = sessions.value;
    final idx = current.indexWhere((s) => s.id == sessionId);
    if (idx == -1) return;

    final session = current[idx];
    if (session.messages.length <= keepRawCount) return;

    final toCompress = session.messages.sublist(0, session.messages.length - keepRawCount);
    final rawRemaining = session.messages.sublist(session.messages.length - keepRawCount);

    final isRu = I18n.instance.isRu;
    final buffer = StringBuffer();
    if (session.contextSummary != null && session.contextSummary!.isNotEmpty) {
      buffer.writeln(session.contextSummary);
      buffer.writeln(isRu ? '\n--- [Предыдущее продолжение диалога] ---' : '\n--- [Previous Conversation Continuation] ---');
    }

    buffer.writeln(
      isRu
          ? '📌 **Сжатая выжимка контекста (${toCompress.length} ранних сообщ.):**'
          : '📌 **Compressed context summary (${toCompress.length} earlier msgs):**',
    );
    for (final msg in toCompress) {
      final sender = msg.isUser ? (isRu ? 'Пользователь' : 'User') : 'Copilot';
      final snippet = msg.text.length > 180 ? '${msg.text.substring(0, 180)}...' : msg.text;
      buffer.writeln('• $sender: ${snippet.replaceAll("\n", " ")}');
      if (msg.toolName != null) {
        buffer.writeln(isRu ? '  ↳ [Инструмент: ${msg.toolName}]' : '  ↳ [Tool: ${msg.toolName}]');
      }
    }

    final newSummary = buffer.toString();
    session.contextSummary = newSummary;
    session.summaryTokenCount = CopilotMessage.estimateTokens(newSummary);
    session.messages = rawRemaining;
    session.updatedAt = DateTime.now();

    sessions.value = List.from(current);
  }

  /// Проверить условия и выполнить автокомпрессию по объёму или количеству.
  /// Возвращает true, если компрессия была выполнена.
  bool checkAndAutoCompress(String sessionId, AiSettings settings) {
    if (!settings.contextCompression) return false;

    final session = sessions.value.firstWhere(
      (s) => s.id == sessionId,
      orElse: () => activeSession,
    );

    final keep = settings.compressionKeepRawCount;
    if (session.messages.length <= keep) return false;

    bool shouldCompress = false;
    if (settings.compressionMode == 'volume') {
      // Оценка по суммарному объему токенов
      shouldCompress = session.totalTokens >= settings.compressionVolumeThreshold;
    } else {
      // Оценка по количеству сообщений
      shouldCompress = session.rawMessagesCount >= settings.contextMessageCount;
    }

    if (shouldCompress) {
      compressSession(sessionId, keepRawCount: keep);
      return true;
    }
    return false;
  }

  /// Собрать prompt по принципу «Бутерброд» (Sandwich Context Assembly):
  /// 1. Верхний хлеб: Системные директивы, персона агента, правила
  /// 2. Начинка 1: Сжатая выжимка ранней истории (если есть)
  /// 3. Начинка 2: Свежие сырые сообщения без потери деталей
  /// 4. Нижний хлеб: Текущий запрос пользователя и ограничения
  Map<String, dynamic> buildSandwichPrompt(
    CopilotSession session,
    AiSettings settings,
    String currentQuery,
  ) {
    final isRu = I18n.instance.isRu;
    // 1. Верхний слой (Directives & System)
    final systemSlice = StringBuffer();
    systemSlice.writeln('SYSTEM DIRECTIVES & AGENT ROLE:');
    systemSlice.writeln(
      isRu
          ? 'Ты — автономный Copilot для Telegram. Роль: "${session.agentRole}".'
          : 'You are an autonomous Copilot for Telegram. Role: "${session.agentRole}".',
    );
    if (session.systemPrompt.isNotEmpty) {
      systemSlice.writeln(isRu ? 'Специфические инструкции агента:' : 'Specific agent instructions:');
      systemSlice.writeln(session.systemPrompt);
    }
    systemSlice.writeln(
      isRu
          ? 'Модель: ${session.model ?? settings.model}. Провайдер: ${settings.provider}.'
          : 'Model: ${session.model ?? settings.model}. Provider: ${settings.provider}.',
    );

    // 2. Начинка: Сжатое саммари
    final summarySlice = session.contextSummary;

    // 3. Начинка: Сырые недавние сообщения
    final rawSlice = List<CopilotMessage>.from(session.messages);

    // 4. Нижний слой (User query & final instruction)
    final bottomSlice = isRu
        ? 'USER TASK: $currentQuery\nОтвечай строго в соответствии с ролью и инструкциями.'
        : 'USER TASK: $currentQuery\nRespond strictly in accordance with your role and instructions.';

    final systemTokens = CopilotMessage.estimateTokens(systemSlice.toString());
    final summaryTokens = summarySlice != null ? CopilotMessage.estimateTokens(summarySlice) : 0;
    final rawTokens = rawSlice.fold<int>(0, (sum, m) => sum + m.tokenCount);
    final bottomTokens = CopilotMessage.estimateTokens(bottomSlice);

    return {
      'systemSlice': systemSlice.toString(),
      'systemTokens': systemTokens,
      'summarySlice': summarySlice,
      'summaryTokens': summaryTokens,
      'rawSlice': rawSlice,
      'rawTokens': rawTokens,
      'bottomSlice': bottomSlice,
      'bottomTokens': bottomTokens,
      'totalTokens': systemTokens + summaryTokens + rawTokens + bottomTokens,
    };
  }
}
