import 'package:flutter/foundation.dart';

class ContactDossier {
  static const String defaultRagPrompt =
      'Извлеки ключевые сухие факты из истории переписки: кто что сказал, биографические и контактные детали, договоренности, условия, спорные моменты и скрытые мотивы участников. Без оценочной шелухи, структурированным списком.';

  ContactDossier({
    required this.chatId,
    this.systemPrompt = '',
    this.goal = '',
    this.tone = '',
    this.facts = const [],
    this.summary = '',
    this.psychotype = '',
    this.analysisMessageLimit = 50,
    this.lastAnalyzed,
    this.ragFactSummary,
    this.ragFactSummaryCount = 0,
    this.ragFactUpdatedAt,
    String? ragPrompt,
    this.autoCompressEnabled = true,
    this.autoCompressThreshold = 20,
    this.keepRawCount = 6,
    String? dialogueCompressionPrompt,
  })  : ragPrompt = ragPrompt ?? defaultRagPrompt,
        dialogueCompressionPrompt = dialogueCompressionPrompt ??
            'Сформируй связную хронологическую выжимку диалога с пользователем: ключевые вопросы пользователя, предложенные выводы, гипотезы и принятые решения. Сохрани суть контекста без потери договоренностей.';

  final String chatId;
  String systemPrompt;
  String goal;
  String tone;
  List<String> facts;
  String summary;
  String psychotype;
  int analysisMessageLimit;
  DateTime? lastAnalyzed;
  String? ragFactSummary;
  int ragFactSummaryCount;
  DateTime? ragFactUpdatedAt;
  String ragPrompt;
  bool autoCompressEnabled;
  int autoCompressThreshold;
  int keepRawCount;
  String dialogueCompressionPrompt;

  ContactDossier copyWith({
    String? systemPrompt,
    String? goal,
    String? tone,
    List<String>? facts,
    String? summary,
    String? psychotype,
    int? analysisMessageLimit,
    DateTime? lastAnalyzed,
    String? ragFactSummary,
    int? ragFactSummaryCount,
    DateTime? ragFactUpdatedAt,
    String? ragPrompt,
    bool? autoCompressEnabled,
    int? autoCompressThreshold,
    int? keepRawCount,
    String? dialogueCompressionPrompt,
  }) {
    return ContactDossier(
      chatId: chatId,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      goal: goal ?? this.goal,
      tone: tone ?? this.tone,
      facts: facts ?? List.from(this.facts),
      summary: summary ?? this.summary,
      psychotype: psychotype ?? this.psychotype,
      analysisMessageLimit: analysisMessageLimit ?? this.analysisMessageLimit,
      lastAnalyzed: lastAnalyzed ?? this.lastAnalyzed,
      ragFactSummary: ragFactSummary ?? this.ragFactSummary,
      ragFactSummaryCount: ragFactSummaryCount ?? this.ragFactSummaryCount,
      ragFactUpdatedAt: ragFactUpdatedAt ?? this.ragFactUpdatedAt,
      ragPrompt: ragPrompt ?? this.ragPrompt,
      autoCompressEnabled: autoCompressEnabled ?? this.autoCompressEnabled,
      autoCompressThreshold: autoCompressThreshold ?? this.autoCompressThreshold,
      keepRawCount: keepRawCount ?? this.keepRawCount,
      dialogueCompressionPrompt: dialogueCompressionPrompt ?? this.dialogueCompressionPrompt,
    );
  }
}

class ContactDossierStore {
  ContactDossierStore._();
  static final ContactDossierStore instance = ContactDossierStore._();

  final Map<String, ValueNotifier<ContactDossier>> _cache = {};

  ValueNotifier<ContactDossier> getDossier(String chatId) {
    return _cache.putIfAbsent(chatId, () {
      return ValueNotifier<ContactDossier>(
        ContactDossier(
          chatId: chatId,
          systemPrompt: '',
          goal: '',
          tone: '',
          facts: [],
          summary: '',
          psychotype: '',
        ),
      );
    });
  }

  void updateSystemPrompt(String chatId, String prompt) {
    final dossierNotifier = getDossier(chatId);
    dossierNotifier.value = dossierNotifier.value.copyWith(systemPrompt: prompt.trim());
  }

  void updateGoal(String chatId, String goal) {
    final dossierNotifier = getDossier(chatId);
    dossierNotifier.value = dossierNotifier.value.copyWith(goal: goal.trim());
  }

  void updateTone(String chatId, String tone) {
    final dossierNotifier = getDossier(chatId);
    dossierNotifier.value = dossierNotifier.value.copyWith(tone: tone.trim());
  }

  void updateAnalysisMessageLimit(String chatId, int limit) {
    final dossierNotifier = getDossier(chatId);
    dossierNotifier.value = dossierNotifier.value.copyWith(analysisMessageLimit: limit);
  }

  void updateRagSummary(String chatId, String summary, int count) {
    final dossierNotifier = getDossier(chatId);
    dossierNotifier.value = dossierNotifier.value.copyWith(
      ragFactSummary: summary,
      ragFactSummaryCount: count,
      ragFactUpdatedAt: DateTime.now(),
    );
  }

  void updateRagPrompt(String chatId, String prompt) {
    final dossierNotifier = getDossier(chatId);
    dossierNotifier.value = dossierNotifier.value.copyWith(
      ragPrompt: prompt.trim(),
    );
  }

  void updateCompressionConfig(
    String chatId, {
    bool? enabled,
    int? threshold,
    int? keepRaw,
    String? prompt,
  }) {
    final dossierNotifier = getDossier(chatId);
    dossierNotifier.value = dossierNotifier.value.copyWith(
      autoCompressEnabled: enabled,
      autoCompressThreshold: threshold,
      keepRawCount: keepRaw,
      dialogueCompressionPrompt: prompt?.trim(),
    );
  }
}
