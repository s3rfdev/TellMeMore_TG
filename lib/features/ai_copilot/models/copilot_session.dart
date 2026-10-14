import 'package:flutter/material.dart';

/// Модель отдельного сообщения в сессии Copilot.
class CopilotMessage {
  CopilotMessage({
    String? id,
    required this.text,
    required this.isUser,
    this.toolName,
    this.toolOutput,
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
    DateTime? time,
    int? tokenCount,
  }) {
    return CopilotMessage(
      id: id,
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      toolName: toolName ?? this.toolName,
      toolOutput: toolOutput ?? this.toolOutput,
      time: time ?? this.time,
      tokenCount: tokenCount ?? this.tokenCount,
    );
  }
}

/// Модель чата/сессии с автономным агентом Copilot.
class CopilotSession {
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
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : messages = messages ?? [],
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
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
