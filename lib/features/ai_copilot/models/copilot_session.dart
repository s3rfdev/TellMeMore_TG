import 'package:flutter/material.dart';

/// Модель отдельного сообщения в сессии Copilot.
class CopilotMessage {
  CopilotMessage({
    String? id,
    required this.text,
    required this.isUser,
    this.toolName,
    this.toolOutput,
    this.attachmentPath,
    this.attachmentName,
    this.isImageAttachment = false,
    this.isError = false,
    DateTime? time,
    int? tokenCount,
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        time = time ?? DateTime.now(),
        tokenCount = tokenCount ?? estimateTokens(text);

  final String id;
  final String text;
  final bool isUser;
  final String? toolName;
  final String? toolOutput;
  final String? attachmentPath;
  final String? attachmentName;
  final bool isImageAttachment;
  final bool isError;
  final DateTime time;
  final int tokenCount;

  /// Оценка объёма токенов текста (с учетом кириллицы и ASCII/кода).
  static int estimateTokens(String text) {
    if (text.isEmpty) return 0;
    int cyrillic = 0;
    for (final rune in text.runes) {
      if (rune >= 0x0400 && rune <= 0x04FF) {
        cyrillic++;
      }
    }
    final int ascii = text.length - cyrillic;
    final int estimated = (cyrillic / 2.2 + ascii / 3.8).ceil();
    return estimated < 1 ? 1 : estimated;
  }

  CopilotMessage copyWith({
    String? text,
    bool? isUser,
    String? toolName,
    String? toolOutput,
    String? attachmentPath,
    String? attachmentName,
    bool? isImageAttachment,
    bool? isError,
    DateTime? time,
    int? tokenCount,
  }) {
    return CopilotMessage(
      id: id,
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      toolName: toolName ?? this.toolName,
      toolOutput: toolOutput ?? this.toolOutput,
      attachmentPath: attachmentPath ?? this.attachmentPath,
      attachmentName: attachmentName ?? this.attachmentName,
      isImageAttachment: isImageAttachment ?? this.isImageAttachment,
      isError: isError ?? this.isError,
      time: time ?? this.time,
      tokenCount: tokenCount ?? this.tokenCount,
    );
  }
}

/// Модель чата/сессии с автономным агентом Copilot.
class CopilotSession {
  static const String defaultRagPrompt =
      'Извлеки ключевые сухие факты из истории переписки: кто что сказал, биографические и контактные детали, договоренности, условия, спорные моменты и скрытые мотивы участников. Без оценочной шелухи, структурированным списком.';

  static const String defaultDialogueCompressionPrompt =
      'Сформируй связную хронологическую выжимку диалога с пользователем: ключевые вопросы пользователя, предложенные выводы, гипотезы и принятые решения. Сохрани суть контекста без потери договоренностей.';

  CopilotSession({
    required this.id,
    required this.title,
    required this.agentRole,
    this.systemPrompt = '',
    this.model,
    required this.avatarIcon,
    required this.avatarColor,
    List<CopilotMessage>? messages,
    this.contextSummary,
    this.summaryTokenCount = 0,
    this.messageLimit = 30,
    String? ragPrompt,
    this.ragFactSummary,
    this.ragFactSummaryCount = 0,
    this.ragFactUpdatedAt,
    this.autoCompressEnabled = true,
    this.autoCompressThreshold = 20,
    this.keepRawCount = 6,
    String? dialogueCompressionPrompt,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : ragPrompt = ragPrompt ?? defaultRagPrompt,
        dialogueCompressionPrompt = dialogueCompressionPrompt ?? defaultDialogueCompressionPrompt,
        messages = messages ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  String title;
  String agentRole;
  String systemPrompt;
  String? model;
  IconData avatarIcon;
  Color avatarColor;
  List<CopilotMessage> messages;
  String? contextSummary;
  int summaryTokenCount;
  int messageLimit;
  String ragPrompt;
  String? ragFactSummary;
  int ragFactSummaryCount;
  DateTime? ragFactUpdatedAt;
  bool autoCompressEnabled;
  int autoCompressThreshold;
  int keepRawCount;
  String dialogueCompressionPrompt;
  final DateTime createdAt;
  DateTime updatedAt;

  /// Суммарный объем токенов сессии (сжатое саммари + сырые сообщения).
  int get totalTokens {
    final msgTokens = messages.fold<int>(0, (sum, m) => sum + m.tokenCount);
    return summaryTokenCount + msgTokens;
  }

  /// Количество сырых сообщений в активном окне.
  int get rawMessagesCount => messages.length;

  /// Последнее сообщение в диалоге.
  CopilotMessage? get lastMessage => messages.isEmpty ? null : messages.last;

  /// Создать копию сессии.
  CopilotSession copyWith({
    String? title,
    String? agentRole,
    String? systemPrompt,
    String? model,
    IconData? avatarIcon,
    Color? avatarColor,
    List<CopilotMessage>? messages,
    String? contextSummary,
    int? summaryTokenCount,
    int? messageLimit,
    String? ragPrompt,
    String? ragFactSummary,
    int? ragFactSummaryCount,
    DateTime? ragFactUpdatedAt,
    bool? autoCompressEnabled,
    int? autoCompressThreshold,
    int? keepRawCount,
    String? dialogueCompressionPrompt,
    DateTime? updatedAt,
  }) {
    return CopilotSession(
      id: id,
      title: title ?? this.title,
      agentRole: agentRole ?? this.agentRole,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      model: model ?? this.model,
      avatarIcon: avatarIcon ?? this.avatarIcon,
      avatarColor: avatarColor ?? this.avatarColor,
      messages: messages ?? List.from(this.messages),
      contextSummary: contextSummary ?? this.contextSummary,
      summaryTokenCount: summaryTokenCount ?? this.summaryTokenCount,
      messageLimit: messageLimit ?? this.messageLimit,
      ragPrompt: ragPrompt ?? this.ragPrompt,
      ragFactSummary: ragFactSummary ?? this.ragFactSummary,
      ragFactSummaryCount: ragFactSummaryCount ?? this.ragFactSummaryCount,
      ragFactUpdatedAt: ragFactUpdatedAt ?? this.ragFactUpdatedAt,
      autoCompressEnabled: autoCompressEnabled ?? this.autoCompressEnabled,
      autoCompressThreshold: autoCompressThreshold ?? this.autoCompressThreshold,
      keepRawCount: keepRawCount ?? this.keepRawCount,
      dialogueCompressionPrompt: dialogueCompressionPrompt ?? this.dialogueCompressionPrompt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
