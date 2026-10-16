import 'package:flutter/material.dart';

import '../../../core/localization/app_locale.dart';
import '../../../core/theme/tg_theme.dart';
import '../../../core/widgets/tg_toast.dart';
import '../../../data/models/tg_chat.dart';
import '../../../data/tdlib/tdlib_service.dart';
import '../../../state/app_state.dart';
import '../models/contact_dossier.dart';
import '../models/copilot_session.dart';
import '../services/copilot_session_store.dart';
import '../services/sherlock_analysis_service.dart';
import 'dossier/dossier_bottom_actions.dart';
import 'dossier/dossier_crm_facts_section.dart';
import 'dossier/dossier_directives_section.dart';
import 'dossier/dossier_goals_and_tone_section.dart';
import 'dossier/dossier_header.dart';
import 'dossier/dossier_memory_section.dart';
import 'dossier/dossier_rag_section.dart';
import 'dossier/dossier_sherlock_card.dart';

/// Диалог управления досье контакта, целями общения, RAG-сбором и памятью Copilot.
class ContactDossierDialog extends StatefulWidget {
  const ContactDossierDialog({
    super.key,
    required this.chat,
  });

  final TgChat chat;

  static void show(BuildContext context, TgChat chat) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => ContactDossierDialog(chat: chat),
    );
  }

  @override
  State<ContactDossierDialog> createState() => _ContactDossierDialogState();
}

class _ContactDossierDialogState extends State<ContactDossierDialog>
    with SingleTickerProviderStateMixin {
  late final ValueNotifier<ContactDossier> _dossierNotifier;
  late final TextEditingController _goalController;
  late final TextEditingController _psychotypeController;
  late final TextEditingController _promptController;
  late final TextEditingController _newFactController;
  late final TextEditingController _ragPromptController;
  late final TextEditingController _dialogueCompressionController;
  late final TabController _tabController;

  bool _isAnalyzing = false;
  late int _messageLimit;

  String? _currentRagSummary;
  int _currentRagCount = 0;
  DateTime? _currentRagDate;

  late bool _autoCompressEnabled;
  late int _autoCompressThreshold;
  late int _keepRawCount;

  @override
  void initState() {
    super.initState();
    _dossierNotifier = ContactDossierStore.instance.getDossier(widget.chat.id);
    final initial = _dossierNotifier.value;

    _goalController = TextEditingController(text: initial.goal);
    _psychotypeController = TextEditingController(text: initial.psychotype);
    _promptController = TextEditingController(text: initial.systemPrompt);
    _newFactController = TextEditingController();

    _tabController = TabController(length: 2, vsync: this);
    _messageLimit = initial.analysisMessageLimit > 0 ? initial.analysisMessageLimit : 30;

    _ragPromptController = TextEditingController(
      text: initial.ragPrompt.isNotEmpty
          ? initial.ragPrompt
          : CopilotSession.defaultRagPrompt,
    );

    _dialogueCompressionController = TextEditingController(
      text: CopilotSession.defaultDialogueCompressionPrompt,
    );

    _currentRagSummary = initial.ragFactSummary;
    _currentRagCount = initial.ragFactSummaryCount;
    _currentRagDate = initial.ragFactUpdatedAt;

    final sessionId = 'contact_${widget.chat.id}';
    final existingSession = CopilotSessionStore.instance.sessions.value
        .where((s) => s.id == sessionId)
        .firstOrNull;

    _autoCompressEnabled = existingSession?.autoCompressEnabled ?? false;
    _autoCompressThreshold = existingSession?.autoCompressThreshold ?? 25;
    _keepRawCount = existingSession?.keepRawCount ?? 8;
    if (existingSession?.dialogueCompressionPrompt.isNotEmpty == true) {
      _dialogueCompressionController.text = existingSession!.dialogueCompressionPrompt;
    }
  }

  @override
  void dispose() {
    _goalController.dispose();
    _psychotypeController.dispose();
    _promptController.dispose();
    _newFactController.dispose();
    _ragPromptController.dispose();
    _dialogueCompressionController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _saveAll({bool close = true}) {
    final goal = _goalController.text.trim();
    final psychotype = _psychotypeController.text.trim();
    final prompt = _promptController.text.trim();
    final ragPrompt = _ragPromptController.text.trim();
    final dialoguePrompt = _dialogueCompressionController.text.trim();

    final store = ContactDossierStore.instance;
    final current = _dossierNotifier.value;

    _dossierNotifier.value = current.copyWith(
      goal: goal,
      psychotype: psychotype,
      systemPrompt: prompt,
      ragPrompt: ragPrompt,
      analysisMessageLimit: _messageLimit,
      autoCompressEnabled: _autoCompressEnabled,
      autoCompressThreshold: _autoCompressThreshold,
      keepRawCount: _keepRawCount,
      dialogueCompressionPrompt: dialoguePrompt,
      ragFactSummary: _currentRagSummary,
      ragFactSummaryCount: _currentRagCount,
      ragFactUpdatedAt: _currentRagDate,
    );

    store.updateSystemPrompt(widget.chat.id, prompt);
    store.updateGoal(widget.chat.id, goal);
    store.updateTone(widget.chat.id, _dossierNotifier.value.tone);
    store.updateAnalysisMessageLimit(widget.chat.id, _messageLimit);
    store.updateRagPrompt(widget.chat.id, ragPrompt);
    if (_currentRagSummary != null) {
      store.updateRagSummary(widget.chat.id, _currentRagSummary!, _currentRagCount);
    }
    store.updateCompressionConfig(
      widget.chat.id,
      enabled: _autoCompressEnabled,
      threshold: _autoCompressThreshold,
      keepRaw: _keepRawCount,
      prompt: dialoguePrompt,
    );

    // Синхронизация с Copilot
    final sessionId = 'contact_${widget.chat.id}';
    CopilotSessionStore.instance.updateSessionPrompt(sessionId, prompt);
    CopilotSessionStore.instance.updateSessionMessageLimit(sessionId, _messageLimit);
    CopilotSessionStore.instance.updateSessionRagConfig(
      sessionId,
      prompt: ragPrompt,
      summary: _currentRagSummary,
      count: _currentRagCount,
    );
    CopilotSessionStore.instance.updateSessionCompressionConfig(
      sessionId,
      enabled: _autoCompressEnabled,
      threshold: _autoCompressThreshold,
      keepRaw: _keepRawCount,
      prompt: dialoguePrompt,
    );

    if (close && mounted) {
      TgToast.show(context, tr('ai_dossier_saved_toast'));
      Navigator.of(context).pop();
    }
  }

  void _openOrCreateCopilotChat() {
    _saveAll(close: false);

    final goal = _goalController.text.trim();
    final psychotype = _psychotypeController.text.trim();
    final prompt = _promptController.text.trim();
    final ragPrompt = _ragPromptController.text.trim();
    final dialoguePrompt = _dialogueCompressionController.text.trim();

    final sessionId = 'contact_${widget.chat.id}';
    final existing = CopilotSessionStore.instance.sessions.value
        .where((s) => s.id == sessionId)
        .firstOrNull;

    final isRu = I18n.instance.isRu;
    final defaultGoal = isRu ? "Установить контакт и выявить потребности" : "Establish contact and identify needs";
    final defaultPsycho = isRu ? "Не определен (требуется анализ)" : "Not analyzed yet";

    final effectiveSystemPrompt = prompt.isNotEmpty
        ? prompt
        : (isRu
            ? '''
Ты персональный AI-ассистент по общению с контактом "${widget.chat.title}".
Твоя задача — помогать вести диалог, анализировать скрытые мотивы, составлять точные ответы и вести контакт к цели.

🎯 Цель общения с контактом: ${goal.isNotEmpty ? goal : defaultGoal}
🗣️ Тон и стиль общения: ${_dossierNotifier.value.tone}
🧠 Психотип и особенности восприятия: ${psychotype.isNotEmpty ? psychotype : defaultPsycho}
📋 Известные факты из CRM:
${_dossierNotifier.value.facts.map((f) => '• $f').join('\n')}
📊 Резюме переписки (Шерлок): ${_dossierNotifier.value.summary}
'''
            : '''
You are a personal AI assistant for communicating with contact "${widget.chat.title}".
Your mission is to assist with conversations, analyze implicit motives, draft precise replies, and steer the dialogue towards the goal.

🎯 Contact goal: ${goal.isNotEmpty ? goal : defaultGoal}
🗣️ Tone of Voice: ${_dossierNotifier.value.tone}
🧠 Psychotype & perception traits: ${psychotype.isNotEmpty ? psychotype : defaultPsycho}
📋 Known CRM facts:
${_dossierNotifier.value.facts.map((f) => '• $f').join('\n')}
📊 Chat summary (Sherlock): ${_dossierNotifier.value.summary}
''');

    if (existing == null) {
      final newSession = CopilotSession(
        id: sessionId,
        title: '👤 ${widget.chat.title}',
        agentRole: isRu ? 'Ассистент по ${widget.chat.title}' : 'Assistant for ${widget.chat.title}',
        systemPrompt: effectiveSystemPrompt,
        avatarIcon: Icons.person_pin_rounded,
        avatarColor: Tg.accent,
        createdAt: DateTime.now(),
        messageLimit: _messageLimit,
        ragPrompt: ragPrompt,
        ragFactSummary: _currentRagSummary,
        ragFactSummaryCount: _currentRagCount,
        ragFactUpdatedAt: _currentRagDate,
        autoCompressEnabled: _autoCompressEnabled,
        autoCompressThreshold: _autoCompressThreshold,
        keepRawCount: _keepRawCount,
        dialogueCompressionPrompt: dialoguePrompt,
        messages: [
          CopilotMessage(
            text: isRu
                ? 'Привет! Я твой персональный AI-копилот по контакту **${widget.chat.title}**.\n\n'
                    '🎯 **Наша цель**: *"${goal.isNotEmpty ? goal : defaultGoal}"*\n'
                    '🧠 **Психотип**: *"${psychotype.isNotEmpty ? psychotype : defaultPsycho}"*\n'
                    '🗣️ **Тон**: *"${_dossierNotifier.value.tone}"*\n\n'
                    'Я держу в контексте всю историю вашей переписки, CRM-факты и досье. '
                    'Ты можешь надиктовать мне любую задачу (например: *"манипулирует ли он мной?"*, *"какие у него мотивы?"*, *"составь жесткий ответ"*), и я помогу!'
                : 'Hello! I am your personal AI Copilot for contact **${widget.chat.title}**.\n\n'
                    '🎯 **Our goal**: *"${goal.isNotEmpty ? goal : "Establish contact"}"*\n'
                    '🧠 **Psychotype**: *"${psychotype.isNotEmpty ? psychotype : "Pragmatic"}"*\n'
                    '🗣️ **Tone**: *"${_dossierNotifier.value.tone}"*\n\n'
                    'I maintain the full context of your chat history, CRM facts, and dossier. '
                    'You can prompt or dictate any task, and I will help formulate the ideal reply!',
            isUser: false,
          ),
        ],
      );
      final updated = List<CopilotSession>.from(CopilotSessionStore.instance.sessions.value)..insert(0, newSession);
      CopilotSessionStore.instance.sessions.value = updated;
      CopilotSessionStore.instance.activeSessionId.value = sessionId;
    } else {
      CopilotSessionStore.instance.updateSessionPrompt(sessionId, effectiveSystemPrompt);
      CopilotSessionStore.instance.updateSessionMessageLimit(sessionId, _messageLimit);
      CopilotSessionStore.instance.updateSessionRagConfig(
        sessionId,
        prompt: ragPrompt,
        summary: _currentRagSummary,
        count: _currentRagCount,
      );
      CopilotSessionStore.instance.updateSessionCompressionConfig(
        sessionId,
        enabled: _autoCompressEnabled,
        threshold: _autoCompressThreshold,
        keepRaw: _keepRawCount,
        prompt: dialoguePrompt,
      );
      CopilotSessionStore.instance.selectSession(sessionId);
    }

    Navigator.of(context).pop();
    AppState.activeSidebarTab.value = SidebarTab.copilot;
  }

  void _openExportDialog() {
    final dossier = _dossierNotifier.value;
    final isRu = I18n.instance.isRu;

    final buffer = StringBuffer();
    buffer.writeln('====================================');
    buffer.writeln(isRu ? 'КАРТОЧКА AI-СОВЕТНИКА ПО КОНТАКТУ' : 'AI ADVISOR CONTACT DOSSIER');
    buffer.writeln('====================================');
    buffer.writeln('${isRu ? "Имя контакта" : "Contact name"}: ${widget.chat.title}');
    buffer.writeln('${isRu ? "Статус" : "Status"}: ${widget.chat.headerSubtitle}');
    buffer.writeln('${isRu ? "Цель общения" : "Conversation goal"}: ${dossier.goal}');
    buffer.writeln('${isRu ? "Рекомендуемый тон" : "Recommended tone"}: ${dossier.tone}');
    buffer.writeln('${isRu ? "Психотип" : "Psychotype"}: ${dossier.psychotype}');
    buffer.writeln('------------------------------------');
    buffer.writeln('${isRu ? "Резюме / Sherlock Анализ" : "Summary / Sherlock Analysis"}:');
    buffer.writeln(dossier.summary.isNotEmpty ? dossier.summary : '—');
    buffer.writeln('------------------------------------');
    buffer.writeln('${isRu ? "Факты" : "Extracted facts"}:');
    for (final f in dossier.facts) {
      buffer.writeln('• $f');
    }
    buffer.writeln('====================================');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Tg.sidebar,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            const Icon(Icons.badge_outlined, color: Tg.accentHover, size: 20),
            const SizedBox(width: 8),
            Text(isRu ? 'Экспорт карточки советника' : 'Export Advisor Dossier', style: Tg.title),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: SelectableText(
              buffer.toString(),
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Tg.text, height: 1.4),
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Tg.accent),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(tr('close')),
          ),
        ],
      ),
    );
  }

  void _runAutoAnalysis() async {
    setState(() => _isAnalyzing = true);

    try {
      final current = _dossierNotifier.value;
      final targetGoal = _goalController.text.trim();

      final tdlibMsgs = TdlibService.instance.messagesOf(widget.chat.id).value.messages;
      final allMessages = tdlibMsgs.isNotEmpty ? tdlibMsgs : widget.chat.messages;

      final result = await SherlockAnalysisService.instance.analyzeChat(
        chatTitle: widget.chat.title,
        messages: allMessages,
        userGoal: targetGoal,
        messageLimit: _messageLimit,
        isRu: I18n.instance.isRu,
      );

      final mergedFacts = List<String>.from(current.facts);
      for (final f in result.extractedFacts) {
        if (!mergedFacts.contains(f)) {
          mergedFacts.add(f);
        }
      }

      _psychotypeController.text = result.psychotype;
      _dossierNotifier.value = current.copyWith(
        psychotype: result.psychotype,
        summary: result.summary,
        facts: mergedFacts,
        lastAnalyzed: result.analyzedAt,
      );

      if (mounted) {
        TgToast.show(context, tr('ai_dossier_analyzed_toast'));
      }
    } catch (e) {
      if (mounted) {
        TgToast.show(context, 'Ошибка анализа: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
    }
  }

  void _addFact() {
    final text = _newFactController.text.trim();
    if (text.isEmpty) return;

    final current = _dossierNotifier.value;
    if (!current.facts.contains(text)) {
      _dossierNotifier.value = current.copyWith(
        facts: [...current.facts, text],
      );
    }
    _newFactController.clear();
  }

  void _removeFact(int index) {
    final current = _dossierNotifier.value;
    final list = List<String>.from(current.facts)..removeAt(index);
    _dossierNotifier.value = current.copyWith(facts: list);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Tg.sidebar,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Tg.border),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 480,
          maxHeight: 640,
        ),
        child: ValueListenableBuilder<ContactDossier>(
          valueListenable: _dossierNotifier,
          builder: (context, dossier, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DossierHeader(
                  chat: widget.chat,
                  tabController: _tabController,
                  onClose: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // ВКЛАДКА 1: ДОСЬЕ КОНТАКТА
                      SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DossierSherlockCard(
                              chat: widget.chat,
                              dossier: dossier,
                              messageLimit: _messageLimit,
                              isAnalyzing: _isAnalyzing,
                              onLimitChanged: (val) {
                                setState(() => _messageLimit = val);
                                ContactDossierStore.instance.updateAnalysisMessageLimit(
                                  widget.chat.id,
                                  val,
                                );
                              },
                              onRunAnalysis: _runAutoAnalysis,
                            ),
                            const SizedBox(height: 11),
                            DossierGoalsAndToneSection(
                              dossier: dossier,
                              goalController: _goalController,
                              psychotypeController: _psychotypeController,
                              onGoalChanged: (val) {
                                _dossierNotifier.value = dossier.copyWith(goal: val);
                              },
                              onToneChanged: (val) {
                                _dossierNotifier.value = dossier.copyWith(tone: val);
                              },
                              onPsychotypeChanged: (val) {
                                _dossierNotifier.value = dossier.copyWith(psychotype: val);
                              },
                            ),
                            const SizedBox(height: 11),
                            DossierCrmFactsSection(
                              dossier: dossier,
                              newFactController: _newFactController,
                              onAddFact: _addFact,
                              onRemoveFact: _removeFact,
                            ),
                          ],
                        ),
                      ),

                      // ВКЛАДКА 2: ПРОМПТ И ПАМЯТЬ
                      SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DossierDirectivesSection(
                              promptController: _promptController,
                            ),
                            const SizedBox(height: 11),
                            DossierRagSection(
                              chat: widget.chat,
                              messageLimit: _messageLimit,
                              ragPromptController: _ragPromptController,
                              currentRagSummary: _currentRagSummary,
                              currentRagCount: _currentRagCount,
                              currentRagDate: _currentRagDate,
                              onLimitChanged: (val) => setState(() => _messageLimit = val),
                              onSummaryUpdated: (summary, count, date) {
                                setState(() {
                                  _currentRagSummary = summary;
                                  _currentRagCount = count;
                                  _currentRagDate = date;
                                });
                              },
                            ),
                            const SizedBox(height: 11),
                            DossierMemorySection(
                              chatId: widget.chat.id,
                              autoCompressEnabled: _autoCompressEnabled,
                              autoCompressThreshold: _autoCompressThreshold,
                              keepRawCount: _keepRawCount,
                              dialogueCompressionController: _dialogueCompressionController,
                              onAutoCompressChanged: (val) => setState(() => _autoCompressEnabled = val),
                              onThresholdChanged: (val) => setState(() => _autoCompressThreshold = val),
                              onKeepRawChanged: (val) => setState(() => _keepRawCount = val),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Tg.hairline),
                DossierBottomActions(
                  onOpenCopilotChat: _openOrCreateCopilotChat,
                  onOpenExportDialog: _openExportDialog,
                  onClose: () => Navigator.of(context).pop(),
                  onSave: () => _saveAll(close: true),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
