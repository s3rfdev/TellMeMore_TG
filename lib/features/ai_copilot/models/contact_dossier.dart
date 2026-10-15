import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../core/utils/session_paths.dart';

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

  Map<String, dynamic> toJson() => {
        'chatId': chatId,
        'systemPrompt': systemPrompt,
        'goal': goal,
        'tone': tone,
        'facts': facts,
        'summary': summary,
        'psychotype': psychotype,
        'analysisMessageLimit': analysisMessageLimit,
        'lastAnalyzed': lastAnalyzed?.toIso8601String(),
        'ragFactSummary': ragFactSummary,
        'ragFactSummaryCount': ragFactSummaryCount,
        'ragFactUpdatedAt': ragFactUpdatedAt?.toIso8601String(),
        'ragPrompt': ragPrompt,
        'autoCompressEnabled': autoCompressEnabled,
        'autoCompressThreshold': autoCompressThreshold,
        'keepRawCount': keepRawCount,
        'dialogueCompressionPrompt': dialogueCompressionPrompt,
      };

  factory ContactDossier.fromJson(Map<String, dynamic> json) {
    return ContactDossier(
      chatId: json['chatId'] as String? ?? '',
      systemPrompt: json['systemPrompt'] as String? ?? '',
      goal: json['goal'] as String? ?? '',
      tone: json['tone'] as String? ?? '',
      facts: (json['facts'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      summary: json['summary'] as String? ?? '',
      psychotype: json['psychotype'] as String? ?? '',
      analysisMessageLimit: json['analysisMessageLimit'] as int? ?? 50,
      lastAnalyzed: json['lastAnalyzed'] != null
          ? DateTime.tryParse(json['lastAnalyzed'] as String)
          : null,
      ragFactSummary: json['ragFactSummary'] as String?,
      ragFactSummaryCount: json['ragFactSummaryCount'] as int? ?? 0,
      ragFactUpdatedAt: json['ragFactUpdatedAt'] != null
          ? DateTime.tryParse(json['ragFactUpdatedAt'] as String)
          : null,
      ragPrompt: json['ragPrompt'] as String?,
      autoCompressEnabled: json['autoCompressEnabled'] as bool? ?? true,
      autoCompressThreshold: json['autoCompressThreshold'] as int? ?? 20,
      keepRawCount: json['keepRawCount'] as int? ?? 6,
      dialogueCompressionPrompt: json['dialogueCompressionPrompt'] as String?,
    );
  }
}

class ContactDossierStore {
  ContactDossierStore._() {
    _initFuture = _loadFromDisk();
  }
  static final ContactDossierStore instance = ContactDossierStore._();

  late final Future<void> _initFuture;
  Future<void> init() => _initFuture;

  final Map<String, ValueNotifier<ContactDossier>> _cache = {};
  bool _isLoading = false;
  bool _isSaving = false;
  bool _hasPendingSave = false;

  Future<void> _loadFromDisk() async {
    try {
      _isLoading = true;
      final base = await SessionPaths.getAppStorageDirectory();
      final file = File('$base/contact_dossiers.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final data = jsonDecode(content);
          if (data is Map<String, dynamic>) {
            data.forEach((chatId, dossierJson) {
              if (dossierJson is Map<String, dynamic>) {
                final dossier = ContactDossier.fromJson(dossierJson);
                _cache[chatId] = ValueNotifier<ContactDossier>(dossier);
              }
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading contact dossiers: $e');
    } finally {
      _isLoading = false;
    }
  }

  Future<void> saveToDisk() async {
    if (_isLoading) return;
    if (_isSaving) {
      _hasPendingSave = true;
      return;
    }
    _isSaving = true;
    try {
      final base = await SessionPaths.getAppStorageDirectory();
      final file = File('$base/contact_dossiers.json');
      final tempFile = File('$base/contact_dossiers_${DateTime.now().microsecondsSinceEpoch}.tmp');
      final map = <String, dynamic>{};
      _cache.forEach((chatId, notifier) {
        map[chatId] = notifier.value.toJson();
      });
      await tempFile.writeAsString(jsonEncode(map), encoding: utf8, flush: true);
      if (await tempFile.exists()) {
        await tempFile.rename(file.path);
      }
    } catch (e) {
      debugPrint('Error saving contact dossiers: $e');
    } finally {
      _isSaving = false;
      if (_hasPendingSave) {
        _hasPendingSave = false;
        saveToDisk();
      }
    }
  }

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
    saveToDisk();
  }

  void updateGoal(String chatId, String goal) {
    final dossierNotifier = getDossier(chatId);
    dossierNotifier.value = dossierNotifier.value.copyWith(goal: goal.trim());
    saveToDisk();
  }

  void updateTone(String chatId, String tone) {
    final dossierNotifier = getDossier(chatId);
    dossierNotifier.value = dossierNotifier.value.copyWith(tone: tone.trim());
    saveToDisk();
  }

  void updateAnalysisMessageLimit(String chatId, int limit) {
    final dossierNotifier = getDossier(chatId);
    dossierNotifier.value = dossierNotifier.value.copyWith(analysisMessageLimit: limit);
    saveToDisk();
  }

  void updateRagSummary(String chatId, String summary, int count) {
    final dossierNotifier = getDossier(chatId);
    dossierNotifier.value = dossierNotifier.value.copyWith(
      ragFactSummary: summary,
      ragFactSummaryCount: count,
      ragFactUpdatedAt: DateTime.now(),
    );
    saveToDisk();
  }

  void updateRagPrompt(String chatId, String prompt) {
    final dossierNotifier = getDossier(chatId);
    dossierNotifier.value = dossierNotifier.value.copyWith(
      ragPrompt: prompt.trim(),
    );
    saveToDisk();
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
    saveToDisk();
  }
}
