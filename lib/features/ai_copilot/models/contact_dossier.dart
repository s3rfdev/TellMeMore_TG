import 'package:flutter/foundation.dart';

class ContactDossier {
  ContactDossier({
    required this.chatId,
    this.systemPrompt = '',
    this.goal = '',
    this.tone = '',
    this.facts = const [],
    this.summary = '',
    this.psychotype = '',
    this.lastAnalyzed,
  });

  final String chatId;
  String systemPrompt;
  String goal;
  String tone;
  List<String> facts;
  String summary;
  String psychotype;
  DateTime? lastAnalyzed;

  ContactDossier copyWith({
    String? systemPrompt,
    String? goal,
    String? tone,
    List<String>? facts,
    String? summary,
    String? psychotype,
    DateTime? lastAnalyzed,
  }) {
    return ContactDossier(
      chatId: chatId,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      goal: goal ?? this.goal,
      tone: tone ?? this.tone,
      facts: facts ?? List.from(this.facts),
      summary: summary ?? this.summary,
      psychotype: psychotype ?? this.psychotype,
      lastAnalyzed: lastAnalyzed ?? this.lastAnalyzed,
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
}
