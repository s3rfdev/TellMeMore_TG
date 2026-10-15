import 'package:flutter/material.dart';

import '../../../core/localization/app_locale.dart';
import '../../../data/models/tg_chat.dart';
import '../models/ai_settings_model.dart';
import '../models/contact_dossier.dart';
import '../models/copilot_session.dart';
import 'ai_model_service.dart';
import 'voice_transcription_service.dart';

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
                ? 'Привет! Я твой AI-копилот. Напиши мне задачу своими словами — например: *"изучи последние сообщения чата"*, *"найди вакансии"* или *"помоги составить ответ"*.'
                : 'Hello! I am your AI Copilot. Give me any task in your own words — e.g.: *"study recent chat messages"*, *"find job postings"*, or *"draft a reply"*.',
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

  /// Обновить лимит сообщений чата, анализируемых агентом в сессии.
  void updateSessionMessageLimit(String id, int limit) {
    final current = sessions.value;
    final idx = current.indexWhere((s) => s.id == id);
    if (idx != -1) {
      current[idx].messageLimit = limit;
      current[idx].updatedAt = DateTime.now();
      sessions.value = List.from(current);
    }
  }

  /// Обновить конфигурацию сбора фактов RAG для сессии.
  void updateSessionRagConfig(
    String id, {
    String? prompt,
    String? summary,
    int? count,
  }) {
    final current = sessions.value;
    final idx = current.indexWhere((s) => s.id == id);
    if (idx != -1) {
      final s = current[idx];
      if (prompt != null) s.ragPrompt = prompt.trim();
      if (summary != null) {
        s.ragFactSummary = summary.trim();
        s.ragFactUpdatedAt = DateTime.now();
      }
      if (count != null) s.ragFactSummaryCount = count;
      s.updatedAt = DateTime.now();
      sessions.value = List.from(current);
    }
  }

  /// Обновить конфигурацию компрессии диалога для сессии.
  void updateSessionCompressionConfig(
    String id, {
    bool? enabled,
    int? threshold,
    int? keepRaw,
    String? prompt,
  }) {
    final current = sessions.value;
    final idx = current.indexWhere((s) => s.id == id);
    if (idx != -1) {
      final s = current[idx];
      if (enabled != null) s.autoCompressEnabled = enabled;
      if (threshold != null) s.autoCompressThreshold = threshold;
      if (keepRaw != null) s.keepRawCount = keepRaw;
      if (prompt != null) s.dialogueCompressionPrompt = prompt.trim();
      s.updatedAt = DateTime.now();
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

  /// Выполнить компрессию контекста сессии (синхронный базовый метод).
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

  /// Интеллектуальное сжатие истории диалога с Копилотом (фоновое или ручное).
  Future<bool> compressSessionIntelligent(String sessionId, {AiSettings? settings}) async {
    final current = sessions.value;
    final idx = current.indexWhere((s) => s.id == sessionId);
    if (idx == -1) return false;

    final session = current[idx];
    final keepRaw = session.keepRawCount > 0 ? session.keepRawCount : 6;
    if (session.messages.length <= keepRaw) return false;

    final toCompress = session.messages.sublist(0, session.messages.length - keepRaw);
    final rawRemaining = session.messages.sublist(session.messages.length - keepRaw);

    final isRu = I18n.instance.isRu;
    final historyLines = <String>[];
    for (final m in toCompress) {
      final sender = m.isUser ? (isRu ? 'Пользователь' : 'User') : 'Copilot';
      historyLines.add('$sender: ${m.text.replaceAll('\n', ' ')}');
    }
    final dialogueText = historyLines.join('\n');

    String summaryText = '';
    final aiSettings = settings ?? AiSettingsStore.instance.settings.value;

    try {
      final systemPrompt = session.dialogueCompressionPrompt.isNotEmpty
          ? session.dialogueCompressionPrompt
          : CopilotSession.defaultDialogueCompressionPrompt;

      final prompt = isRu
          ? 'Сожми следующий диалог в структурированную сухую выжимку по хронологии (темы, аргументы, решения и гипотезы). Без воды:\n\n$dialogueText'
          : 'Summarize the following conversation chronologically into a dry structured summary (topics, decisions, findings). No fluff:\n\n$dialogueText';

      final result = await AiModelService.instance.generateChatCompletion(
        prompt: prompt,
        systemPrompt: systemPrompt,
        history: [],
        settings: aiSettings,
      );
      if (result.trim().isNotEmpty) {
        summaryText = result.trim();
      }
    } catch (_) {}

    if (summaryText.isEmpty) {
      final buffer = StringBuffer();
      buffer.writeln(
        isRu
            ? '📌 **Выжимка диалога (${toCompress.length} ранних сообщ.):**'
            : '📌 **Dialogue summary (${toCompress.length} earlier msgs):**',
      );
      for (final m in toCompress) {
        final sender = m.isUser ? (isRu ? 'Пользователь' : 'User') : 'Copilot';
        final snippet = m.text.length > 140 ? '${m.text.substring(0, 140)}...' : m.text;
        buffer.writeln('• $sender: ${snippet.replaceAll("\n", " ")}');
      }
      summaryText = buffer.toString();
    }

    if (session.contextSummary != null && session.contextSummary!.isNotEmpty) {
      summaryText = '${session.contextSummary}\n\n$summaryText';
    }

    session.contextSummary = summaryText;
    session.summaryTokenCount = CopilotMessage.estimateTokens(summaryText);
    session.messages = rawRemaining;
    session.updatedAt = DateTime.now();

    sessions.value = List.from(current);
    return true;
  }

  /// Извлечение сухих фактов из истории переписки (RAG).
  Future<String> runRagFactExtraction({
    required String sessionId,
    String? chatId,
    required List<TgMessage> messages,
    required int limit,
    required String ragPrompt,
    required String chatTitle,
    AiSettings? settings,
  }) async {
    final aiSettings = settings ?? AiSettingsStore.instance.settings.value;
    final msgsToAnalyze = messages.take(limit).toList();
    final isRu = I18n.instance.isRu;

    final formatted = <String>[];
    for (final m in msgsToAnalyze.reversed) {
      final sender = m.outgoing ? (isRu ? 'Вы' : 'You') : chatTitle;
      String content = m.text.replaceAll('\n', ' ').trim();
      if (m.kind == MessageKind.voice) {
        String? trans = VoiceTranscriptionService.instance.getCachedTranscription(m.id) ??
            VoiceTranscriptionService.instance.getCachedTranscription(m.mediaPath);
        if (trans != null && trans.isNotEmpty && !trans.startsWith('[')) {
          content = '[🎤 Voice: "$trans"]';
        } else {
          content = '[🎤 Voice note (${m.duration}s)]';
        }
      }
      formatted.add('$sender: $content');
    }

    final transcript = formatted.join('\n');
    final prompt = isRu
        ? 'Вот история переписки ($chatTitle, ${msgsToAnalyze.length} сообщ.):\n\n$transcript\n\nИзвлеки сухие факты согласно директиве.'
        : 'Here is conversation history ($chatTitle, ${msgsToAnalyze.length} msgs):\n\n$transcript\n\nExtract dry facts per instructions.';

    String result = '';
    try {
      final res = await AiModelService.instance.generateChatCompletion(
        prompt: prompt,
        systemPrompt: ragPrompt.isNotEmpty ? ragPrompt : CopilotSession.defaultRagPrompt,
        history: [],
        settings: aiSettings,
      );
      if (res.trim().isNotEmpty) {
        result = res.trim();
      }
    } catch (_) {}

    if (result.isEmpty) {
      final buffer = StringBuffer();
      buffer.writeln(isRu ? '📌 Факты чата «$chatTitle» (сжато ${msgsToAnalyze.length} сообщ.):' : '📌 Facts of "$chatTitle" (${msgsToAnalyze.length} msgs):');
      for (final m in msgsToAnalyze.take(20)) {
        if (m.text.trim().isNotEmpty) {
          buffer.writeln('• ${m.outgoing ? (isRu ? "Вы" : "You") : chatTitle}: ${m.text.trim().replaceAll("\n", " ")}');
        }
      }
      result = buffer.toString();
    }

    updateSessionRagConfig(
      sessionId,
      prompt: ragPrompt,
      summary: result,
      count: msgsToAnalyze.length,
    );

    if (chatId != null) {
      ContactDossierStore.instance.updateRagSummary(chatId, result, msgsToAnalyze.length);
      ContactDossierStore.instance.updateRagPrompt(chatId, ragPrompt);
    }

    return result;
  }

  /// Проверить условия и выполнить автокомпрессию по объёму или количеству.
  /// Возвращает true, если компрессия была выполнена.
  bool checkAndAutoCompress(String sessionId, AiSettings settings) {
    final current = sessions.value;
    final idx = current.indexWhere((s) => s.id == sessionId);
    if (idx == -1) return false;

    final session = current[idx];
    if (!session.autoCompressEnabled && !settings.contextCompression) return false;

    final threshold = session.autoCompressThreshold > 0
        ? session.autoCompressThreshold
        : settings.contextMessageCount;
    final keep = settings.compressionKeepRawCount > 0
        ? settings.compressionKeepRawCount
        : (session.keepRawCount > 0 ? session.keepRawCount : 6);

    if (session.messages.length <= keep) return false;

    bool shouldCompress = false;
    if (settings.compressionMode == 'volume') {
      // Оценка по суммарному объему токенов
      shouldCompress = session.totalTokens >= settings.compressionVolumeThreshold;
    } else {
      // Оценка по количеству сообщений
      final threshold = session.autoCompressThreshold > 0
          ? session.autoCompressThreshold
          : settings.contextMessageCount;
      shouldCompress = session.rawMessagesCount >= threshold;
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
