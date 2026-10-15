import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/localization/app_locale.dart';
import '../../../core/theme/tg_theme.dart';
import '../../../core/widgets/tg_avatar.dart';
import '../../../core/widgets/tg_toast.dart';
import '../../../data/models/tg_chat.dart';
import '../../../data/tdlib/tdlib_service.dart';
import '../../../state/app_state.dart';
import '../../chat/services/chat_export_service.dart';
import '../../chat/widgets/chat_export_dialog.dart';
import '../models/contact_dossier.dart';
import '../models/copilot_session.dart';
import '../services/ai_model_service.dart';
import '../services/copilot_session_store.dart';
import '../services/voice_transcription_service.dart';

/// Единый центр AI-управления контактом (Вариант Б):
/// Вкладка 1: 👤 Досье контакта (CRM & Психология: цель, психотип, тон, CRM-факты, Шерлок)
/// Вкладка 2: ⚙️ Промпт и память (LLM & RAG: системные директивы, сбор RAG-фактов, автокомпрессия)
class ContactDossierDialog extends StatefulWidget {
  const ContactDossierDialog({
    super.key,
    required this.chat,
    this.initialTab = 0,
  });

  final TgChat chat;
  final int initialTab;

  static Future<void> show(BuildContext context, TgChat chat, {int initialTab = 0}) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (_) => ContactDossierDialog(chat: chat, initialTab: initialTab),
    );
  }

  @override
  State<ContactDossierDialog> createState() => _ContactDossierDialogState();
}

class _ContactDossierDialogState extends State<ContactDossierDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final ValueNotifier<ContactDossier> _dossierNotifier;

  // Контроллеры Вкладки 1 (Досье CRM)
  late final TextEditingController _goalController;
  late final TextEditingController _psychotypeController;
  final TextEditingController _newFactController = TextEditingController();
  final ScrollController _dossierScrollController = ScrollController();
  bool _isAnalyzing = false;

  // Контроллеры Вкладки 2 (Промпт и Память)
  late final TextEditingController _promptController;
  late final TextEditingController _ragPromptController;
  late final TextEditingController _dialogueCompressionController;
  final ScrollController _promptScrollController = ScrollController();

  int _messageLimit = 30;
  bool _autoCompressEnabled = true;
  int _autoCompressThreshold = 20;
  int _keepRawCount = 6;
  bool _isExtractingRag = false;
  bool _isCompressingDialogue = false;

  String? _currentRagSummary;
  int _currentRagCount = 0;
  DateTime? _currentRagDate;

  final List<String> _goalPresetKeys = [
    'ai_goal_deal',
    'ai_goal_hire',
    'ai_goal_date',
    'ai_goal_friendship',
    'ai_goal_network',
    'ai_goal_invest',
  ];

  final List<String> _tonePresetKeys = [
    'ai_tone_friendly_dev',
    'ai_tone_business',
    'ai_tone_playful',
    'ai_tone_expert',
    'ai_tone_empathic',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTab.clamp(0, 1));
    _dossierNotifier = ContactDossierStore.instance.getDossier(widget.chat.id);
    final dossier = _dossierNotifier.value;

    final sessionId = 'contact_${widget.chat.id}';
    final existingSession = CopilotSessionStore.instance.sessions.value
        .where((s) => s.id == sessionId)
        .firstOrNull;

    _goalController = TextEditingController(text: dossier.goal);
    _psychotypeController = TextEditingController(text: dossier.psychotype);
    _promptController = TextEditingController(
      text: dossier.systemPrompt.isNotEmpty
          ? dossier.systemPrompt
          : (existingSession?.systemPrompt ?? ''),
    );

    _messageLimit = dossier.analysisMessageLimit > 0 ? dossier.analysisMessageLimit : 30;

    _ragPromptController = TextEditingController(
      text: dossier.ragPrompt.isNotEmpty ? dossier.ragPrompt : ContactDossier.defaultRagPrompt,
    );

    _dialogueCompressionController = TextEditingController(
      text: dossier.dialogueCompressionPrompt.isNotEmpty
          ? dossier.dialogueCompressionPrompt
          : (existingSession?.dialogueCompressionPrompt.isNotEmpty == true
              ? existingSession!.dialogueCompressionPrompt
              : CopilotSession.defaultDialogueCompressionPrompt),
    );

    _autoCompressEnabled = dossier.autoCompressEnabled;
    _autoCompressThreshold = dossier.autoCompressThreshold;
    _keepRawCount = dossier.keepRawCount;

    _currentRagSummary = dossier.ragFactSummary ?? existingSession?.ragFactSummary;
    _currentRagCount = dossier.ragFactSummaryCount > 0
        ? dossier.ragFactSummaryCount
        : (existingSession?.ragFactSummaryCount ?? 0);
    _currentRagDate = dossier.ragFactUpdatedAt ?? existingSession?.ragFactUpdatedAt;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _goalController.dispose();
    _psychotypeController.dispose();
    _newFactController.dispose();
    _promptController.dispose();
    _ragPromptController.dispose();
    _dialogueCompressionController.dispose();
    _dossierScrollController.dispose();
    _promptScrollController.dispose();
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
        ragPrompt: ragPrompt,
        ragFactSummary: _currentRagSummary,
        ragFactSummaryCount: _currentRagCount,
        ragFactUpdatedAt: _currentRagDate,
        autoCompressEnabled: _autoCompressEnabled,
        autoCompressThreshold: _autoCompressThreshold,
        keepRawCount: _keepRawCount,
        dialogueCompressionPrompt: dialoguePrompt,
        avatarIcon: Icons.person_pin_rounded,
        avatarColor: Tg.accent,
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
    _saveAll(close: false);
    ChatExportDialog.show(
      context,
      widget.chat,
      initialType: ExportContentType.advisorProfile,
    );
  }

  void _runAutoAnalysis() async {
    setState(() => _isAnalyzing = true);

    try {
      final current = _dossierNotifier.value;
      final targetGoal = _goalController.text.trim();

      final tdlibMsgs = TdlibService.instance.messagesOf(widget.chat.id).value.messages;
      final allMessages = tdlibMsgs.isNotEmpty ? tdlibMsgs : widget.chat.messages;

      final limit = _messageLimit > 0 ? _messageLimit : 50;
      final messagesToAnalyze = allMessages.take(limit).toList();

      if (messagesToAnalyze.isEmpty) {
        if (mounted) {
          TgToast.show(context, I18n.instance.isRu ? 'История переписки пуста' : 'Chat history is empty');
          setState(() => _isAnalyzing = false);
        }
        return;
      }

      final isRu = I18n.instance.isRu;
      final formattedList = <String>[];
      for (final m in messagesToAnalyze.reversed) {
        final sender = m.outgoing ? (isRu ? 'Вы' : 'You') : widget.chat.title;
        String content = m.text.replaceAll('\n', ' ').trim();
        if (m.kind == MessageKind.voice) {
          String? trans = VoiceTranscriptionService.instance.getCachedTranscription(m.id) ??
              VoiceTranscriptionService.instance.getCachedTranscription(m.mediaPath);
          if (trans == null || trans.isEmpty) {
            if (m.mediaPath.isNotEmpty && File(m.mediaPath).existsSync()) {
              try {
                trans = await VoiceTranscriptionService.instance.transcribeVoiceFile(
                  filePath: m.mediaPath,
                  messageId: m.id,
                  durationSeconds: m.duration,
                );
              } catch (_) {}
            }
          }
          if (trans != null && trans.isNotEmpty && !trans.startsWith('[')) {
            content = isRu ? '[🎤 Расшифровка голосового: "$trans"]' : '[🎤 Voice transcript: "$trans"]';
          } else {
            content = isRu ? '[🎤 Голосовое сообщение (${m.duration} сек)]' : '[🎤 Voice note (${m.duration}s)]';
          }
        } else if (m.kind == MessageKind.image) {
          content = isRu ? '[🖼 Изображение${content.isNotEmpty ? ": $content" : ""}]' : '[🖼 Image${content.isNotEmpty ? ": $content" : ""}]';
        } else if (m.kind == MessageKind.video) {
          content = isRu ? '[🎬 Видео (${m.duration} сек)${content.isNotEmpty ? ": $content" : ""}]' : '[🎬 Video (${m.duration}s)${content.isNotEmpty ? ": $content" : ""}]';
        } else if (m.kind == MessageKind.document) {
          content = isRu ? '[📎 Документ: ${m.fileName} (${m.fileSize})${content.isNotEmpty ? ": $content" : ""}]' : '[📎 Document: ${m.fileName} (${m.fileSize})${content.isNotEmpty ? ": $content" : ""}]';
        }
        formattedList.add('$sender: $content');
      }
      final transcript = formattedList.join('\n');

      final prompt = isRu
          ? '''
Проведи объективный психологический анализ человека и диалога с "${widget.chat.title}" по реальной истории переписки (изучено ${messagesToAnalyze.length} сообщений):
$transcript

Цель пользователя: "${targetGoal.isNotEmpty ? targetGoal : 'Выяснить позицию и защитить свои интересы'}"

Выведи ответ строго по структуре:
[ПСИХОТИП]: 1-2 предложения, честный психологический портрет и стиль общения
[РЕЗЮМЕ]: 3-4 предложения: истинные мотивы, манипуляции, токсичность или ее отсутствие, уровень адекватности
[ФАКТЫ]:
- Реальный факт 1 из текста диалога
- Реальный факт 2 из текста диалога
'''
          : '''
Analyze the contact "${widget.chat.title}" based on conversation history (${messagesToAnalyze.length} messages):
$transcript

User goal: "${targetGoal.isNotEmpty ? targetGoal : 'Clarify terms and safeguard interests'}"

Format strictly as:
[PSYCHOTYPE]: 1-2 sentences candid profile
[SUMMARY]: Motives and manipulation analysis
[FACTS]:
- Extracted fact 1
- Extracted fact 2
''';

      final aiResponse = await AiModelService.instance.generateChatCompletion(
        prompt: prompt,
        systemPrompt: 'Ты — независимый психолог и эксперт по переговорам. Анализируешь людей честно, без цензуры и корпоративных штампов.',
      );

      String extractedPsycho = '';
      String extractedSummary = '';
      final extractedFacts = <String>[];

      final lines = aiResponse.split('\n');
      String currentSection = '';
      final summaryBuffer = StringBuffer();

      for (final line in lines) {
        final t = line.trim();
        if (t.startsWith('[ПСИХОТИП]:') || t.startsWith('[PSYCHOTYPE]:') || t.startsWith('ПСИХОТИП:')) {
          extractedPsycho = t.replaceFirst(RegExp(r'^\[?(ПСИХОТИП|PSYCHOTYPE)\]?:?\s*'), '').trim();
          currentSection = 'psycho';
        } else if (t.startsWith('[РЕЗЮМЕ]:') || t.startsWith('[SUMMARY]:') || t.startsWith('РЕЗЮМЕ:')) {
          currentSection = 'summary';
          final rest = t.replaceFirst(RegExp(r'^\[?(РЕЗЮМЕ|SUMMARY)\]?:?\s*'), '').trim();
          if (rest.isNotEmpty) summaryBuffer.writeln(rest);
        } else if (t.startsWith('[ФАКТЫ]:') || t.startsWith('[FACTS]:') || t.startsWith('ФАКТЫ:')) {
          currentSection = 'facts';
        } else if (currentSection == 'summary') {
          if (t.isNotEmpty && !t.startsWith('[') && !t.startsWith('ФАКТЫ:')) {
            summaryBuffer.writeln(t);
          }
        } else if (currentSection == 'facts') {
          if (t.startsWith('-') || t.startsWith('•') || t.startsWith('*')) {
            final fact = t.replaceFirst(RegExp(r'^[-•*]\s*'), '').trim();
            if (fact.isNotEmpty && !fact.startsWith('[')) extractedFacts.add(fact);
          }
        }
      }

      if (extractedPsycho.isEmpty) {
        extractedPsycho = aiResponse.split('\n').first.trim();
      }
      extractedSummary = summaryBuffer.toString().trim();

      final mergedFacts = List<String>.from(current.facts);
      for (final f in extractedFacts) {
        if (!mergedFacts.contains(f)) {
          mergedFacts.add(f);
        }
      }

      _psychotypeController.text = extractedPsycho;
      _dossierNotifier.value = current.copyWith(
        psychotype: extractedPsycho,
        summary: extractedSummary,
        facts: mergedFacts,
        lastAnalyzed: DateTime.now(),
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
    final updatedFacts = List<String>.from(current.facts)..add(text);
    _dossierNotifier.value = current.copyWith(facts: updatedFacts);
    _newFactController.clear();
    setState(() {});
  }

  void _removeFact(int index) {
    final current = _dossierNotifier.value;
    final updatedFacts = List<String>.from(current.facts)..removeAt(index);
    _dossierNotifier.value = current.copyWith(facts: updatedFacts);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final maxModalHeight = (screenHeight * 0.9).clamp(440.0, 780.0);

    return Dialog(
      backgroundColor: Tg.sidebar,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Tg.border),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 620,
          maxHeight: maxModalHeight,
        ),
        child: ValueListenableBuilder<ContactDossier>(
          valueListenable: _dossierNotifier,
          builder: (context, dossier, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Шапка контакта с переключателем вкладок
                _buildHeader(dossier),
                const Divider(height: 1, color: Tg.hairline),

                // Содержимое активной вкладки
                Flexible(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Таб 0: 👤 Досье контакта (CRM & Психология)
                      RawScrollbar(
                        controller: _dossierScrollController,
                        thumbVisibility: true,
                        thumbColor: Colors.white.withValues(alpha: 0.15),
                        radius: const Radius.circular(3),
                        thickness: 5,
                        child: ListView(
                          controller: _dossierScrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          children: [
                            _buildSherlockCard(dossier),
                            const SizedBox(height: 12),
                            _buildGoalSection(dossier),
                            const SizedBox(height: 12),
                            _buildToneSection(dossier),
                            const SizedBox(height: 12),
                            _buildPsychotypeSection(dossier),
                            const SizedBox(height: 12),
                            _buildFactsSection(dossier),
                          ],
                        ),
                      ),

                      // Таб 1: ⚙️ Промпт и память (LLM & RAG)
                      RawScrollbar(
                        controller: _promptScrollController,
                        thumbVisibility: true,
                        thumbColor: Colors.white.withValues(alpha: 0.15),
                        radius: const Radius.circular(3),
                        thickness: 5,
                        child: ListView(
                          controller: _promptScrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          children: [
                            _buildDirectivesSection(),
                            const SizedBox(height: 12),
                            _buildRagSection(),
                            const SizedBox(height: 12),
                            _buildMemorySection(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1, color: Tg.hairline),
                _buildBottomActions(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(ContactDossier dossier) {
    final isRu = I18n.instance.isRu;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 0),
      child: Column(
        children: [
          Row(
            children: [
              TgAvatar(
                emoji: widget.chat.avatarEmoji,
                color: Color(widget.chat.avatarColor),
                imagePath: widget.chat.avatarPath,
                size: 38,
                fontSize: 15,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.chat.title,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: Tg.text,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: Tg.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            isRu ? 'AI-Ассистент' : 'AI Assistant',
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: Tg.accent,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      widget.chat.headerSubtitle.isNotEmpty
                          ? widget.chat.headerSubtitle
                          : (isRu ? 'Управление досье и контекстом' : 'Dossier & context management'),
                      style: const TextStyle(fontSize: 11, color: Tg.textDim),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 19, color: Tg.textFaint),
                splashRadius: 16,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TabBar(
            controller: _tabController,
            labelColor: Tg.accent,
            unselectedLabelColor: Tg.textDim,
            indicatorColor: Tg.accent,
            indicatorWeight: 2,
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            tabs: [
              Tab(text: isRu ? '👤 Досье контакта (CRM)' : '👤 Contact Dossier (CRM)'),
              Tab(text: isRu ? '⚙️ Промпт и память (LLM)' : '⚙️ Prompt & Memory (LLM)'),
            ],
          ),
        ],
      ),
    );
  }

  // --- ВКЛАДКА 1: ДОСЬЕ КОНТАКТА ---

  Widget _buildSherlockCard(ContactDossier dossier) {
    final tdlibMsgs = TdlibService.instance.messagesOf(widget.chat.id).value.messages;
    final totalMsgs = tdlibMsgs.isNotEmpty ? tdlibMsgs.length : widget.chat.messages.length;
    final limit = _messageLimit.clamp(5, 500);
    final effectiveCount = totalMsgs > 0 ? (limit > totalMsgs ? totalMsgs : limit) : 0;
    final isRu = I18n.instance.isRu;

    return Container(
      decoration: BoxDecoration(
        color: Tg.field,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology_rounded, size: 16, color: Tg.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tr('ai_sherlock_header'),
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Tg.accent,
                  ),
                ),
              ),
              if (dossier.lastAnalyzed != null)
                Text(
                  tr('ai_sherlock_updated', {'time': _formatTime(dossier.lastAnalyzed!)}),
                  style: const TextStyle(fontSize: 10.5, color: Tg.textDim),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Слайдер сообщений для анализа
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isRu ? 'Глубина анализа переписки:' : 'Analysis message depth:',
                style: const TextStyle(fontSize: 11.5, color: Tg.textDim),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: Tg.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isRu ? '$effectiveCount из $totalMsgs сообщ.' : '$effectiveCount of $totalMsgs msgs',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Tg.accent),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
            ),
            child: Slider(
              value: limit.toDouble(),
              min: 5,
              max: totalMsgs > 100 ? totalMsgs.toDouble().clamp(100, 500) : 100,
              divisions: 19,
              activeColor: Tg.accent,
              inactiveColor: Colors.white.withValues(alpha: 0.08),
              onChanged: (val) {
                setState(() => _messageLimit = val.round());
                ContactDossierStore.instance.updateAnalysisMessageLimit(
                  widget.chat.id,
                  val.round(),
                );
              },
            ),
          ),
          const SizedBox(height: 6),

          if (dossier.summary.isNotEmpty) ...[
            Text(
              dossier.summary,
              style: const TextStyle(fontSize: 12, color: Tg.text, height: 1.35),
            ),
            const SizedBox(height: 10),
          ] else ...[
            Text(
              isRu
                  ? 'Запустите анализ, чтобы нейросеть изучила характер собеседника, скрытые мотивы и наличие манипуляций.'
                  : 'Run analysis to examine interlocutor motives, psychotype, and manipulation markers.',
              style: const TextStyle(fontSize: 11, color: Tg.textFaint, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 10),
          ],

          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _isAnalyzing ? null : _runAutoAnalysis,
              style: ElevatedButton.styleFrom(
                backgroundColor: Tg.accentDark,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: _isAnalyzing
                  ? const SizedBox(
                      width: 13,
                      height: 13,
                      child: CircularProgressIndicator(strokeWidth: 1.8, color: Colors.white),
                    )
                  : const Icon(Icons.refresh_rounded, size: 15),
              label: Text(
                _isAnalyzing ? tr('ai_sherlock_analyzing') : tr('ai_sherlock_refresh'),
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalSection(ContactDossier dossier) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.flag_outlined, size: 15, color: Tg.accent),
            const SizedBox(width: 7),
            Text(
              tr('ai_goal_title'),
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Tg.text),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _goalPresetKeys.map((key) {
            final label = tr(key);
            final active = dossier.goal == label || dossier.goal == key;
            return ChoiceChip(
              label: Text(label),
              selected: active,
              selectedColor: Tg.accent.withValues(alpha: 0.2),
              backgroundColor: Tg.field,
              labelStyle: TextStyle(
                fontSize: 11,
                color: active ? Tg.accent : Tg.textDim,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              ),
              side: BorderSide(
                color: active ? Tg.accent : Tg.borderSubtle,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
              onSelected: (selected) {
                if (selected) {
                  _dossierNotifier.value = dossier.copyWith(goal: label);
                  _goalController.text = label;
                }
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Tg.field,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          child: TextField(
            controller: _goalController,
            minLines: 1,
            maxLines: 7,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            onChanged: (val) {
              _dossierNotifier.value = dossier.copyWith(goal: val);
            },
            style: const TextStyle(fontSize: 12, color: Tg.text, height: 1.35),
            decoration: InputDecoration(
              hintText: tr('ai_goal_hint'),
              hintStyle: const TextStyle(fontSize: 11.5, color: Tg.textFaint),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 6),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToneSection(ContactDossier dossier) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.record_voice_over_outlined, size: 15, color: Tg.accent),
            const SizedBox(width: 7),
            Text(
              tr('ai_tone_title'),
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Tg.text),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _tonePresetKeys.map((key) {
            final label = tr(key);
            final active = dossier.tone == label || dossier.tone == key;
            return ChoiceChip(
              label: Text(label),
              selected: active,
              selectedColor: Tg.accent.withValues(alpha: 0.2),
              backgroundColor: Tg.field,
              labelStyle: TextStyle(
                fontSize: 11,
                color: active ? Tg.accent : Tg.textDim,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              ),
              side: BorderSide(
                color: active ? Tg.accent : Colors.transparent,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
              onSelected: (selected) {
                if (selected) {
                  _dossierNotifier.value = dossier.copyWith(tone: label);
                }
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPsychotypeSection(ContactDossier dossier) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.fingerprint_rounded, size: 15, color: Tg.accent),
            const SizedBox(width: 7),
            Text(
              tr('ai_psychotype_title'),
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Tg.text),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Tg.field,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          child: TextField(
            controller: _psychotypeController,
            minLines: 1,
            maxLines: 7,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            onChanged: (val) {
              _dossierNotifier.value = dossier.copyWith(psychotype: val);
            },
            style: const TextStyle(fontSize: 12, color: Tg.text, height: 1.35),
            decoration: InputDecoration(
              hintText: tr('ai_psychotype_hint'),
              hintStyle: const TextStyle(fontSize: 11.5, color: Tg.textFaint),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 6),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFactsSection(ContactDossier dossier) {
    return _CollapsibleCard(
      title: tr('ai_facts_title'),
      icon: Icons.checklist_rounded,
      badge: '${dossier.facts.length}',
      initiallyExpanded: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...dossier.facts.asMap().entries.map((entry) {
            final idx = entry.key;
            final fact = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                children: [
                  const Icon(Icons.circle, size: 5, color: Tg.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      fact,
                      style: const TextStyle(fontSize: 11.5, color: Tg.text),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 14, color: Tg.textFaint),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                    splashRadius: 12,
                    onPressed: () => _removeFact(idx),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 32,
                  decoration: BoxDecoration(
                    color: Tg.sidebar,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: TextField(
                    controller: _newFactController,
                    style: const TextStyle(fontSize: 11.5, color: Tg.text),
                    decoration: InputDecoration(
                      hintText: tr('ai_facts_add_hint'),
                      hintStyle: const TextStyle(fontSize: 11, color: Tg.textFaint),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                    ),
                    onSubmitted: (_) => _addFact(),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded, color: Tg.accent, size: 20),
                splashRadius: 16,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: _addFact,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- ВКЛАДКА 2: ПРОМПТ И ПАМЯТЬ ---

  Widget _buildDirectivesSection() {
    final isRu = I18n.instance.isRu;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.tune_rounded, size: 15, color: Tg.accent),
            const SizedBox(width: 7),
            Text(
              isRu ? 'Системные инструкции (Директивы агента)' : 'System Instructions (Agent Directives)',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Tg.text,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _promptController,
          maxLines: 4,
          minLines: 2,
          style: const TextStyle(fontSize: 12, color: Tg.text, height: 1.35),
          decoration: InputDecoration(
            filled: true,
            fillColor: Tg.field,
            hintText: isRu
                ? 'Например: Отвечай коротко и вежливо. Главная задача — выяснить дедлайн проекта и предложить встречу.'
                : 'E.g.: Reply concisely and professionally. Primary goal is to clarify deadline and propose call.',
            hintStyle: const TextStyle(color: Tg.textDim, fontSize: 11.5),
            contentPadding: const EdgeInsets.all(10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Tg.accent, width: 1.2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRagSection() {
    final isRu = I18n.instance.isRu;

    return _CollapsibleCard(
      title: isRu ? 'RAG-сбор сухих фактов из чата' : 'Chat RAG & Fact Extraction',
      icon: Icons.hub_outlined,
      badge: _currentRagSummary != null ? (isRu ? 'Активно' : 'Active') : null,
      subtitle: isRu
          ? 'Сжатие истории сообщений в факты по заданной призме'
          : 'Compress chat history into facts per custom filter',
      initiallyExpanded: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isRu ? 'Глубина сбора фактов (RAG):' : 'Fact extraction depth (RAG):',
                style: const TextStyle(fontSize: 11.5, color: Tg.text, fontWeight: FontWeight.w500),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Tg.accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  isRu ? '$_messageLimit сообщ.' : '$_messageLimit msgs',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Tg.accent),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
            ),
            child: Slider(
              value: _messageLimit.toDouble().clamp(10.0, 500.0),
              min: 10,
              max: 500,
              divisions: 49,
              activeColor: Tg.accent,
              inactiveColor: Colors.white.withValues(alpha: 0.08),
              onChanged: (val) {
                setState(() => _messageLimit = val.round());
              },
            ),
          ),
          const SizedBox(height: 2),
          Text(
            isRu ? 'Призма взгляда для RAG (какие факты извлекать):' : 'RAG filter lens (what facts to gather):',
            style: const TextStyle(fontSize: 11, color: Tg.text, fontWeight: FontWeight.w400),
          ),
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: Tg.sidebar,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: TextField(
              controller: _ragPromptController,
              maxLines: 2,
              style: const TextStyle(color: Tg.text, fontSize: 11.5),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: isRu ? 'Укажите фокус: договоренности, условия, спорные реплики...' : 'Extraction focus...',
                hintStyle: const TextStyle(color: Tg.textFaint, fontSize: 11),
              ),
            ),
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Tg.accent.withValues(alpha: 0.18),
                  foregroundColor: Tg.accent,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(7),
                    side: BorderSide(color: Tg.accent.withValues(alpha: 0.35)),
                  ),
                ),
                icon: _isExtractingRag
                    ? const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 1.8, color: Tg.accent))
                    : const Icon(Icons.bolt_rounded, size: 15),
                label: Text(
                  _isExtractingRag
                      ? (isRu ? 'Сбор фактов...' : 'Extracting...')
                      : (isRu ? 'Собрать RAG-выжимку ($_messageLimit сообщ.)' : 'Extract RAG Facts ($_messageLimit msgs)'),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
                onPressed: _isExtractingRag
                    ? null
                    : () async {
                        setState(() => _isExtractingRag = true);
                        try {
                          final realHistory = TdlibService.instance.messagesOf(widget.chat.id).value;
                          final msgs = realHistory.messages.isNotEmpty ? realHistory.messages : widget.chat.messages;
                          final sessionId = 'contact_${widget.chat.id}';
                          final summary = await CopilotSessionStore.instance.runRagFactExtraction(
                            sessionId: sessionId,
                            chatId: widget.chat.id,
                            messages: msgs,
                            limit: _messageLimit,
                            ragPrompt: _ragPromptController.text,
                            chatTitle: widget.chat.title,
                          );
                          setState(() {
                            _currentRagSummary = summary;
                            _currentRagCount = msgs.take(_messageLimit).length;
                            _currentRagDate = DateTime.now();
                          });
                          if (!mounted) return;
                          TgToast.show(
                            context,
                            isRu ? '⚡ RAG-выжимка из $_currentRagCount сообщений собрана!' : '⚡ RAG summary extracted!',
                          );
                        } catch (e) {
                          if (!mounted) return;
                          TgToast.show(context, 'Ошибка RAG: $e');
                        } finally {
                          if (mounted) {
                            setState(() => _isExtractingRag = false);
                          }
                        }
                      },
              ),
              const Spacer(),
              if (_currentRagSummary != null && _currentRagSummary!.isNotEmpty)
                IconButton(
                  tooltip: isRu ? 'Очистить RAG-выжимку' : 'Clear RAG summary',
                  icon: const Icon(Icons.delete_outline, size: 17, color: Tg.textDim),
                  splashRadius: 16,
                  onPressed: () {
                    setState(() {
                      _currentRagSummary = null;
                      _currentRagCount = 0;
                      _currentRagDate = null;
                    });
                    ContactDossierStore.instance.updateRagSummary(widget.chat.id, '', 0);
                  },
                ),
            ],
          ),

          if (_currentRagSummary != null && _currentRagSummary!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF00C48C).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF00C48C).withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle_outline, size: 13, color: Color(0xFF00C48C)),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          _currentRagDate != null
                              ? (isRu
                                  ? 'RAG-выжимка активна (сжато $_currentRagCount сообщ., в ${_currentRagDate!.hour.toString().padLeft(2, "0")}:${_currentRagDate!.minute.toString().padLeft(2, "0")})'
                                  : 'Active RAG summary ($_currentRagCount msgs, at ${_currentRagDate!.hour.toString().padLeft(2, "0")}:${_currentRagDate!.minute.toString().padLeft(2, "0")})')
                              : (isRu ? 'RAG-выжимка активна (сжато $_currentRagCount сообщ.)' : 'Active RAG summary ($_currentRagCount msgs)'),
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF00C48C)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _currentRagSummary!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10.5, color: Tg.textDim, height: 1.25),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMemorySection() {
    final isRu = I18n.instance.isRu;
    final sessionId = 'contact_${widget.chat.id}';
    final existingSession = CopilotSessionStore.instance.sessions.value
        .where((s) => s.id == sessionId)
        .firstOrNull;

    return _CollapsibleCard(
      title: isRu ? 'Автокомпрессия и память контекста' : 'Auto-compression & Context Memory',
      icon: Icons.memory_rounded,
      subtitle: isRu
          ? 'Сжатие длинной истории диалога при переполнении лимита'
          : 'Compress conversation history upon reaching threshold',
      initiallyExpanded: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isRu ? 'Автокомпрессия при переполнении:' : 'Auto-compress on threshold:',
                style: const TextStyle(fontSize: 11.5, color: Tg.text, fontWeight: FontWeight.w400),
              ),
              Transform.scale(
                scale: 0.72,
                child: Switch.adaptive(
                  value: _autoCompressEnabled,
                  activeTrackColor: Tg.accent.withValues(alpha: 0.35),
                  activeThumbColor: Tg.accent,
                  onChanged: (val) {
                    setState(() => _autoCompressEnabled = val);
                  },
                ),
              ),
            ],
          ),

          if (_autoCompressEnabled) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isRu ? 'Порог срабатывания сжатия:' : 'Compression trigger threshold:',
                  style: const TextStyle(fontSize: 11, color: Tg.textDim),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: Tg.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isRu ? '$_autoCompressThreshold сообщ.' : '$_autoCompressThreshold msgs',
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500, color: Tg.accent),
                  ),
                ),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
              ),
              child: Slider(
                value: _autoCompressThreshold.toDouble().clamp(10.0, 80.0),
                min: 10,
                max: 80,
                divisions: 14,
                activeColor: Tg.accent,
                inactiveColor: Colors.white.withValues(alpha: 0.08),
                onChanged: (val) {
                  setState(() => _autoCompressThreshold = val.round());
                },
              ),
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isRu ? 'Свежих сообщений без сжатия (окно):' : 'Raw recent window:',
                  style: const TextStyle(fontSize: 11, color: Tg.textDim),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: Tg.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isRu ? '$_keepRawCount сообщ.' : '$_keepRawCount msgs',
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500, color: Tg.accent),
                  ),
                ),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
              ),
              child: Slider(
                value: _keepRawCount.toDouble().clamp(3.0, 20.0),
                min: 3,
                max: 20,
                divisions: 17,
                activeColor: Tg.accent,
                inactiveColor: Colors.white.withValues(alpha: 0.08),
                onChanged: (val) {
                  setState(() => _keepRawCount = val.round());
                },
              ),
            ),

            const SizedBox(height: 2),
            Text(
              isRu ? 'Призма сжатия диалога:' : 'Dialogue compression lens:',
              style: const TextStyle(fontSize: 11, color: Tg.text, fontWeight: FontWeight.w400),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: Tg.sidebar,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: TextField(
                controller: _dialogueCompressionController,
                maxLines: 2,
                style: const TextStyle(color: Tg.text, fontSize: 11),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  hintText: isRu ? 'Инструкция для сжатия диалога...' : 'Compression instructions...',
                  hintStyle: const TextStyle(color: Tg.textFaint, fontSize: 10.5),
                ),
              ),
            ),
          ],

          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Tg.accent,
                  side: BorderSide(color: Tg.accent.withValues(alpha: 0.35)),
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                icon: _isCompressingDialogue
                    ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.8, color: Tg.accent))
                    : const Icon(Icons.archive_outlined, size: 14),
                label: Text(
                  _isCompressingDialogue
                      ? (isRu ? 'Сжатие...' : 'Compressing...')
                      : (isRu
                          ? 'Сжать диалог сейчас (${existingSession?.messages.length ?? 0} сообщ.)'
                          : 'Compress dialogue now (${existingSession?.messages.length ?? 0} msgs)'),
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500),
                ),
                onPressed: _isCompressingDialogue
                    ? null
                    : () async {
                        setState(() => _isCompressingDialogue = true);
                        try {
                          final compressed = await CopilotSessionStore.instance.compressSessionIntelligent(sessionId);
                          if (!mounted) return;
                          if (compressed) {
                            TgToast.show(context, isRu ? '🗜️ Диалог сжат и сохранен в памяти!' : '🗜️ Dialogue compressed to memory!');
                          } else {
                            TgToast.show(
                              context,
                              isRu
                                  ? 'В диалоге мало сообщений (меньше окна $_keepRawCount)'
                                  : 'Dialogue has fewer messages than window ($_keepRawCount)',
                            );
                          }
                        } catch (e) {
                          if (!mounted) return;
                          TgToast.show(context, 'Ошибка сжатия: $e');
                        } finally {
                          if (mounted) {
                            setState(() => _isCompressingDialogue = false);
                          }
                        }
                      },
              ),
              const Spacer(),
              if (existingSession?.contextSummary != null && existingSession!.contextSummary!.isNotEmpty)
                Text(
                  isRu ? '⚡ Память: активна' : '⚡ Memory: active',
                  style: const TextStyle(fontSize: 10.5, color: Color(0xFF00C48C), fontWeight: FontWeight.w500),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // --- НИЖНЯЯ ПАНЕЛЬ ДЕЙСТВИЙ ---

  Widget _buildBottomActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 10,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: _openOrCreateCopilotChat,
            icon: const Icon(Icons.forum_outlined, size: 15, color: Tg.accent),
            label: Text(
              tr('ai_chat_about_contact'),
              style: const TextStyle(
                color: Tg.accent,
                fontSize: 11.5,
                fontWeight: Tg.fontMedium,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Tg.accent.withValues(alpha: 0.35)),
              backgroundColor: Tg.field,
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          OutlinedButton.icon(
            onPressed: _openExportDialog,
            icon: const Icon(Icons.badge_outlined, size: 15, color: Tg.accentHover),
            label: Text(
              tr('ai_export_advisor'),
              style: const TextStyle(
                color: Tg.accentHover,
                fontSize: 11.5,
                fontWeight: Tg.fontMedium,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Tg.accent.withValues(alpha: 0.25)),
              backgroundColor: Tg.accentSubtle,
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(tr('close'), style: const TextStyle(color: Tg.textDim, fontSize: 12.5)),
              ),
              const SizedBox(width: 6),
              ElevatedButton(
                onPressed: () => _saveAll(close: true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Tg.accentDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(tr('ai_save_changes'), style: const TextStyle(fontSize: 12.5, fontWeight: Tg.fontMedium)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

/// Компактная сворачиваемая карточка с аккуратным разворотом
class _CollapsibleCard extends StatefulWidget {
  const _CollapsibleCard({
    required this.title,
    required this.icon,
    this.badge,
    this.subtitle,
    required this.initiallyExpanded,
    required this.child,
  });

  final String title;
  final IconData icon;
  final String? badge;
  final String? subtitle;
  final bool initiallyExpanded;
  final Widget child;

  @override
  State<_CollapsibleCard> createState() => _CollapsibleCardState();
}

class _CollapsibleCardState extends State<_CollapsibleCard> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Tg.field,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              child: Row(
                children: [
                  Icon(widget.icon, size: 15, color: Tg.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              widget.title,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Tg.text,
                              ),
                            ),
                            if (widget.badge != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: Tg.accent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  widget.badge!,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Tg.accent,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (widget.subtitle != null) ...[
                          const SizedBox(height: 1),
                          Text(
                            widget.subtitle!,
                            style: const TextStyle(fontSize: 10.5, color: Tg.textDim),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    size: 17,
                    color: Tg.textDim,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1, color: Tg.hairline),
            Padding(
              padding: const EdgeInsets.all(11),
              child: widget.child,
            ),
          ],
        ],
      ),
    );
  }
}
