import 'package:flutter/material.dart';

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
    final list = [
      CopilotSession(
        id: 'lead_hunter',
        title: '💼 Поиск вакансий & Лидов',
        agentRole: 'Lead Hunter',
        systemPrompt:
            'Ты автономный Lead Hunter агент. Ищи вакансии, заказы и лиды в Telegram группах через TDLib. Форматируй результаты со ставками, стеком и контактами.',
        avatarIcon: Icons.work_outline_rounded,
        avatarColor: const Color(0xFF51B2FF),
        messages: [
          CopilotMessage(
            text: 'Привет! Я агент Lead Hunter. Мониторю открытые каналы и чаты на предмет вакансий и заказов.',
            isUser: false,
          ),
          CopilotMessage(
            text: 'Спарси последние предложения о работе по Flutter из открытых каналов',
            isUser: true,
          ),
          CopilotMessage(
            text: 'Выполнил поиск по публичным каналам через TDLib. Вот последние актуальные варианты:',
            isUser: false,
            toolName: 'tdlib.searchPublicChats("flutter jobs remote")',
            toolOutput: 'Найдено 4 релевантных канала, просканировано 120 сообщений',
          ),
          CopilotMessage(
            text: '1. **Senior Flutter Architect** (Remote, \$5000-\$7000)\n'
                '   • Проект: FinTech / Crypto кошелек\n'
                '   • Стек: Flutter, BLoC, FFI, WebRTC, Native C++\n'
                '   • Контакт: @crypto_fin_hr\n\n'
                '2. **Flutter / Dart Engineer (AI Apps)** (Remote / Бали, \$4000+)\n'
                '   • Проект: Desktop & Mobile клиент с интеграцией локальных LLM\n'
                '   • Контакт: @asmirnov_ai\n\n'
                'Подготовить отклик с учетом твоего профиля и опыта работы с TDLib?',
            isUser: false,
          ),
        ],
      ),
      CopilotSession(
        id: 'crm_analyst',
        title: '📊 CRM & Саммари чатов',
        agentRole: 'CRM Analyst',
        systemPrompt:
            'Ты CRM-аналитик переписок. Анализируй контекст чатов, выделяй договорённости, дедлайны и формируй краткие структурированные саммари переписок.',
        avatarIcon: Icons.analytics_outlined,
        avatarColor: const Color(0xFF8774E1),
        messages: [
          CopilotMessage(
            text: 'Я CRM-аналитик. Могу сформировать досье контактов, выжать главное из длинных переписок и зафиксировать договорённости.',
            isUser: false,
          ),
          CopilotMessage(
            text: 'Сделай саммари переписки с Тарасом',
            isUser: true,
          ),
          CopilotMessage(
            text: '📌 **Краткое саммари переписки с Тарасом:**\n'
                '• Обсуждали проект Telegram клиента с LLM и Шерлоком на аватарах.\n'
                '• Договорились о тестировании Claude и китайских моделей.\n'
                '• Следующий шаг: оформление открытого репозитория на GitHub.',
            isUser: false,
            toolName: 'tdlib.getChatHistory(chatId: "taras", limit: 30)',
            toolOutput: 'История чата получена и сжата через LLM Context Engine',
          ),
        ],
      ),
      CopilotSession(
        id: 'code_architect',
        title: '🛠️ Архитектура & Код-ревью',
        agentRole: 'Code Architect',
        systemPrompt:
            'Ты экспертный Flutter/Dart & C++ Native архитектор. Помогай с FFI, TDLib интеграцией, паттернами BLoC и оптимизацией производительности на Linux/Desktop.',
        avatarIcon: Icons.code_rounded,
        avatarColor: const Color(0xFF00C48C),
        messages: [
          CopilotMessage(
            text: 'Привет! Я архитектор кодовой базы tg_answer. Помогу с Native C++ хуками, WebRTC звонками, Dart FFI и оптимизацией сборки под Linux и macOS.',
            isUser: false,
          ),
        ],
      ),
      CopilotSession(
        id: 'personal_copilot',
        title: '🤖 Главный Telegram Копилот',
        agentRole: 'General Copilot',
        systemPrompt:
            'Ты персональный AI Копилот для Telegram. Помогай управлять чатами, писать ответы и автоматизировать рутину.',
        avatarIcon: Icons.auto_awesome,
        avatarColor: const Color(0xFFFF9F43),
        messages: [
          CopilotMessage(
            text: 'Привет! Я твой главный персональный ассистент. Могу отвечать на сообщения, анализировать группы и управлять задачами.',
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
    final newSession = CopilotSession(
      id: 'copilot_${DateTime.now().millisecondsSinceEpoch}',
      title: title.trim().isEmpty ? 'Новый чат с агентом' : title.trim(),
      agentRole: role.trim().isEmpty ? 'Custom Agent' : role.trim(),
      systemPrompt: prompt ?? '',
      model: model,
      avatarIcon: icon ?? Icons.auto_awesome,
      avatarColor: color ?? const Color(0xFF8774E1),
      messages: [
        CopilotMessage(
          text: 'Чат создан. Роль агента: **${role.trim().isEmpty ? "Custom Agent" : role.trim()}**.\nЧем могу помочь по этой задаче?',
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
    final current = sessions.value;
    final idx = current.indexWhere((s) => s.id == id);
    if (idx != -1) {
      final s = current[idx];
      s.messages.clear();
      s.contextSummary = null;
      s.summaryTokenCount = 0;
      s.messages.add(
        CopilotMessage(
          text: 'История диалога очищена. Готов к новым задачам.',
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

    final buffer = StringBuffer();
    if (session.contextSummary != null && session.contextSummary!.isNotEmpty) {
      buffer.writeln(session.contextSummary);
      buffer.writeln('\n--- [Предыдущее продолжение диалога] ---');
    }

    buffer.writeln('📌 **Сжатая выжимка контекста (${toCompress.length} ранних сообщ.):**');
    for (final msg in toCompress) {
      final sender = msg.isUser ? 'Пользователь' : 'Copilot';
      final snippet = msg.text.length > 180 ? '${msg.text.substring(0, 180)}...' : msg.text;
      buffer.writeln('• $sender: ${snippet.replaceAll("\n", " ")}');
      if (msg.toolName != null) {
        buffer.writeln('  ↳ [Инструмент: ${msg.toolName}]');
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
    // 1. Верхний слой (Directives & System)
    final systemSlice = StringBuffer();
    systemSlice.writeln('SYSTEM DIRECTIVES & AGENT ROLE:');
    systemSlice.writeln('Ты — автономный Copilot для Telegram. Роль: "${session.agentRole}".');
    if (session.systemPrompt.isNotEmpty) {
      systemSlice.writeln('Специфические инструкции агента:');
      systemSlice.writeln(session.systemPrompt);
    }
    systemSlice.writeln('Модель: ${session.model ?? settings.model}. Провайдер: ${settings.provider}.');

    // 2. Начинка: Сжатое саммари
    final summarySlice = session.contextSummary;

    // 3. Начинка: Сырые недавние сообщения
    final rawSlice = List<CopilotMessage>.from(session.messages);

    // 4. Нижний слой (User query & final instruction)
    final bottomSlice = 'USER TASK: $currentQuery\nОтвечай строго в соответствии с ролью и инструкциями.';

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
