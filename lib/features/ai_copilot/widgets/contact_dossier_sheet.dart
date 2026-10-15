import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/localization/app_locale.dart';
import '../../../core/theme/tg_theme.dart';
import '../../../core/widgets/circle_icon_button.dart';
import '../../../core/widgets/tg_avatar.dart';
import '../../../core/widgets/tg_toast.dart';
import '../../../data/models/tg_chat.dart';
import '../../../state/app_state.dart';
import '../../chat/services/chat_export_service.dart';
import '../../chat/widgets/chat_export_dialog.dart';
import '../../../data/tdlib/tdlib_service.dart';
import '../models/contact_dossier.dart';
import '../models/copilot_session.dart';
import '../services/ai_model_service.dart';
import '../services/copilot_session_store.dart';
import '../services/voice_transcription_service.dart';

class ContactDossierDialog extends StatefulWidget {
  const ContactDossierDialog({super.key, required this.chat});

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

class _ContactDossierDialogState extends State<ContactDossierDialog> {
  late final ValueNotifier<ContactDossier> _dossierNotifier;
  final TextEditingController _goalController = TextEditingController();
  final TextEditingController _psychotypeController = TextEditingController();
  final TextEditingController _newFactController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isAnalyzing = false;

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
    _dossierNotifier = ContactDossierStore.instance.getDossier(widget.chat.id);
    _goalController.text = _dossierNotifier.value.goal;
    _psychotypeController.text = _dossierNotifier.value.psychotype;
  }

  @override
  void dispose() {
    _goalController.dispose();
    _psychotypeController.dispose();
    _newFactController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _runAutoAnalysis() async {
    setState(() => _isAnalyzing = true);

    try {
      final current = _dossierNotifier.value;
      final targetGoal = _goalController.text.trim();

      // Получаем реальные сообщения из TDLib (или чата)
      final tdlibMsgs = TdlibService.instance.messagesOf(widget.chat.id).value.messages;
      final allMessages = tdlibMsgs.isNotEmpty ? tdlibMsgs : widget.chat.messages;

      final limit = current.analysisMessageLimit > 0 ? current.analysisMessageLimit : 50;
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

Цель пользователя по контакту: "${targetGoal.isNotEmpty ? targetGoal : 'Выяснить суть, мотивы и защитить свои интересы'}"

ИНСТРУКЦИЯ ПО АНАЛИЗУ:
1. Будь предельно честным, прямолинейным и независимым экспертом.
2. Никаких слащавых корпоративных комплиментов, шаблонной лести и выдуманных клише (категорически запрещено писать "прагматичный новатор", если человек ведет себя неадекватно, грубо, пассивно или некомпетентно).
3. Если человек проявляет токсичность, манипулирует, юлит, перекладывает вину, проявляет пассивную агрессию или ведет себя непрофессионально — назови вещи своими именами прямо и четко.
4. Выяви реальные скрытые или явные мотивы человека.

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
      if (extractedSummary.isEmpty) {
        extractedSummary = aiResponse.trim();
      }

      // Объединяем факты
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

  void _saveCurrentState() {
    final goal = _goalController.text.trim();
    final psychotype = _psychotypeController.text.trim();
    _dossierNotifier.value = _dossierNotifier.value.copyWith(
      goal: goal,
      psychotype: psychotype,
    );
  }

  void _openExportDialog() {
    _saveCurrentState();
    ChatExportDialog.show(
      context,
      widget.chat,
      initialType: ExportContentType.advisorProfile,
    );
  }

  void _openOrCreateCopilotChat() {
    // Сохраняем актуальные цель и психотип
    _saveCurrentState();
    final goal = _goalController.text.trim();
    final psychotype = _psychotypeController.text.trim();

    final sessionId = 'contact_${widget.chat.id}';
    final existing = CopilotSessionStore.instance.sessions.value
        .where((s) => s.id == sessionId)
        .firstOrNull;

    final isRu = I18n.instance.isRu;
    final defaultGoal = isRu ? "Установить контакт и выявить потребности" : "Establish contact and identify needs";
    final defaultPsycho = isRu ? "Не определен (требуется анализ)" : "Not analyzed yet";

    final prompt = isRu ? '''
Ты персональный AI-ассистент по общению с контактом "${widget.chat.title}".
Твоя задача — помогать вести диалог, анализировать скрытые мотивы, составлять точные ответы и вести контакт к цели.

🎯 Цель общения с контактом: ${goal.isNotEmpty ? goal : defaultGoal}
🗣️ Тон и стиль общения: ${_dossierNotifier.value.tone}
🧠 Психотип и особенности восприятия: ${psychotype.isNotEmpty ? psychotype : defaultPsycho}
📋 Известные факты из CRM:
${_dossierNotifier.value.facts.map((f) => '• $f').join('\n')}
📊 Резюме переписки (Шерлок): ${_dossierNotifier.value.summary}
''' : '''
You are a personal AI assistant for communicating with contact "${widget.chat.title}".
Your mission is to assist with conversations, analyze implicit motives, draft precise replies, and steer the dialogue towards the goal.

🎯 Contact goal: ${goal.isNotEmpty ? goal : defaultGoal}
🗣️ Tone of Voice: ${_dossierNotifier.value.tone}
🧠 Psychotype & perception traits: ${psychotype.isNotEmpty ? psychotype : defaultPsycho}
📋 Known CRM facts:
${_dossierNotifier.value.facts.map((f) => '• $f').join('\n')}
📊 Chat summary (Sherlock): ${_dossierNotifier.value.summary}
''';

    if (existing == null) {
      final newSession = CopilotSession(
        id: sessionId,
        title: '👤 ${widget.chat.title}',
        agentRole: isRu ? 'Ассистент по ${widget.chat.title}' : 'Assistant for ${widget.chat.title}',
        systemPrompt: prompt,
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
                    'Ты можешь надиктовать мне любую задачу (например: *"манипулирует ли он мной?"*, *"какие у него мотивы?"*, *"составь жесткий ответ"* или *"оцени его адекватность"*), и я помогу!'
                : 'Hello! I am your personal AI Copilot for contact **${widget.chat.title}**.\n\n'
                    '🎯 **Our goal**: *"${goal.isNotEmpty ? goal : "Establish contact"}"*\n'
                    '🧠 **Psychotype**: *"${psychotype.isNotEmpty ? psychotype : "Pragmatic"}"*\n'
                    '🗣️ **Tone**: *"${_dossierNotifier.value.tone}"*\n\n'
                    'I maintain the full context of your chat history, CRM facts, and dossier. '
                    'You can prompt or dictate any task (e.g.: *"how to politely decline"*, *"draft an offer"*, or *"analyze their latest message"*), and I will help formulate the ideal reply!',
            isUser: false,
          ),
        ],
      );
      final updated = List<CopilotSession>.from(CopilotSessionStore.instance.sessions.value)..insert(0, newSession);
      CopilotSessionStore.instance.sessions.value = updated;
      CopilotSessionStore.instance.activeSessionId.value = sessionId;
    } else {
      CopilotSessionStore.instance.updateSessionPrompt(sessionId, prompt);
      CopilotSessionStore.instance.selectSession(sessionId);
    }

    Navigator.of(context).pop();
    AppState.activeSidebarTab.value = SidebarTab.copilot;
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
    final maxModalHeight = (screenHeight * 0.88).clamp(380.0, 780.0);

    return Dialog(
      backgroundColor: Tg.sidebar,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Tg.border),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 640,
          maxHeight: maxModalHeight,
        ),
        child: ValueListenableBuilder<ContactDossier>(
          valueListenable: _dossierNotifier,
          builder: (context, dossier, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(dossier),
                const Divider(height: 1, color: Tg.hairline),
                Flexible(
                  child: RawScrollbar(
                    controller: _scrollController,
                    thumbVisibility: true,
                    trackVisibility: false,
                    thumbColor: Colors.white.withValues(alpha: 0.2),
                    radius: const Radius.circular(4),
                    thickness: 6,
                    child: ListView(
                      controller: _scrollController,
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                      children: [
                        _buildAiAnalysisBanner(dossier),
                        const SizedBox(height: 20),
                        _buildGoalSection(dossier),
                        const SizedBox(height: 20),
                        _buildToneSection(dossier),
                        const SizedBox(height: 20),
                        _buildPsychotypeSection(dossier),
                        const SizedBox(height: 20),
                        _buildFactsSection(dossier),
                      ],
                    ),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
      child: Row(
        children: [
          TgAvatar(
            emoji: widget.chat.avatarEmoji,
            color: Color(widget.chat.avatarColor),
            imagePath: widget.chat.avatarPath,
            size: 42,
            fontSize: 16,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      widget.chat.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: Tg.fontMedium,
                        color: Tg.text,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Tg.accentSubtle,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Tg.accent.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.auto_awesome, size: 12, color: Tg.accent),
                          const SizedBox(width: 4),
                          Text(
                            tr('ai_dossier_crm_badge'),
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: Tg.fontMedium,
                              color: Tg.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  tr('ai_dossier_desc'),
                  style: const TextStyle(fontSize: 11.5, color: Tg.textFaint),
                ),
              ],
            ),
          ),
          Tooltip(
            message: tr('ai_dossier_export_tooltip'),
            child: CircleIconButton(
              icon: Icons.ios_share_rounded,
              iconSize: 18,
              color: Tg.accent,
              onTap: _openExportDialog,
            ),
          ),
          const SizedBox(width: 6),
          CircleIconButton(
            icon: Icons.close_rounded,
            iconSize: 20,
            color: Tg.textDim,
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildAiAnalysisBanner(ContactDossier dossier) {
    final tdlibMsgs = TdlibService.instance.messagesOf(widget.chat.id).value.messages;
    final totalMsgs = tdlibMsgs.isNotEmpty ? tdlibMsgs.length : widget.chat.messages.length;
    final limit = dossier.analysisMessageLimit.clamp(5, 500);
    final effectiveCount = totalMsgs < limit ? totalMsgs : limit;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Tg.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Tg.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology_outlined, size: 20, color: Tg.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tr('ai_sherlock_header'),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: Tg.fontMedium,
                    color: Tg.accent,
                  ),
                ),
              ),
              if (dossier.lastAnalyzed != null)
                Text(
                  tr('ai_sherlock_updated', {'time': _formatTime(dossier.lastAnalyzed!)}),
                  style: const TextStyle(fontSize: 11, color: Tg.textDim),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Интерактивная ручка выбора глубины сообщений для анализа
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Tg.field,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      I18n.instance.isRu ? 'Глубина анализа переписки:' : 'Analysis message depth:',
                      style: const TextStyle(fontSize: 12, color: Tg.textDim),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Tg.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        I18n.instance.isRu
                            ? '$effectiveCount из $totalMsgs сообщ.'
                            : '$effectiveCount of $totalMsgs msgs',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Tg.accent),
                      ),
                    ),
                  ],
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                  ),
                  child: Slider(
                    value: limit.toDouble(),
                    min: 5,
                    max: totalMsgs > 100 ? totalMsgs.toDouble().clamp(100, 500) : 100,
                    divisions: 19,
                    activeColor: Tg.accent,
                    inactiveColor: Colors.white.withValues(alpha: 0.1),
                    onChanged: (val) {
                      ContactDossierStore.instance.updateAnalysisMessageLimit(
                        widget.chat.id,
                        val.round(),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          if (dossier.summary.isNotEmpty) ...[
            Text(
              dossier.summary,
              style: const TextStyle(fontSize: 12.5, color: Tg.text, height: 1.35),
            ),
            const SizedBox(height: 12),
          ] else ...[
            Text(
              I18n.instance.isRu
                  ? 'Запустите анализ, чтобы нейросеть изучила характер собеседника, скрытые мотивы и наличие манипуляций.'
                  : 'Run analysis to examine interlocutor motives, psychotype, and manipulation markers.',
              style: const TextStyle(fontSize: 12, color: Tg.textFaint, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 12),
          ],

          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _isAnalyzing ? null : _runAutoAnalysis,
              style: ElevatedButton.styleFrom(
                backgroundColor: Tg.accentDark,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: _isAnalyzing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.refresh_rounded, size: 16),
              label: Text(
                _isAnalyzing ? tr('ai_sherlock_analyzing') : tr('ai_sherlock_refresh'),
                style: const TextStyle(fontSize: 12, fontWeight: Tg.fontMedium),
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
            const Icon(Icons.flag_outlined, size: 17, color: Tg.accent),
            const SizedBox(width: 8),
            Text(
              tr('ai_goal_title'),
              style: const TextStyle(fontSize: 13, fontWeight: Tg.fontMedium, color: Tg.text),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _goalPresetKeys.map((key) {
            final label = tr(key);
            final active = dossier.goal == label || dossier.goal == key;
            return ChoiceChip(
              label: Text(label),
              selected: active,
              selectedColor: Tg.accent.withValues(alpha: 0.22),
              backgroundColor: Tg.field,
              labelStyle: TextStyle(
                fontSize: 12,
                color: active ? Tg.accent : Tg.textDim,
                fontWeight: active ? Tg.fontMedium : Tg.fontRegular,
              ),
              side: BorderSide(
                color: active ? Tg.accent : Tg.borderSubtle,
              ),
              onSelected: (selected) {
                if (selected) {
                  _dossierNotifier.value = dossier.copyWith(goal: label);
                  _goalController.text = label;
                }
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Tg.field,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: TextField(
            controller: _goalController,
            minLines: 1,
            maxLines: 7,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            onChanged: (val) {
              _dossierNotifier.value = dossier.copyWith(goal: val);
            },
            style: const TextStyle(fontSize: 13, color: Tg.text, height: 1.35),
            decoration: InputDecoration(
              hintText: tr('ai_goal_hint'),
              hintStyle: const TextStyle(fontSize: 13, color: Tg.textFaint),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
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
            const Icon(Icons.record_voice_over_outlined, size: 17, color: Color(0xFF43C053)),
            const SizedBox(width: 8),
            Text(
              tr('ai_tone_title'),
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Tg.text),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _tonePresetKeys.map((key) {
            final label = tr(key);
            final active = dossier.tone == label || dossier.tone == key;
            return ChoiceChip(
              label: Text(label),
              selected: active,
              selectedColor: const Color(0xFF43C053).withValues(alpha: 0.22),
              backgroundColor: Tg.field,
              labelStyle: TextStyle(
                fontSize: 12,
                color: active ? const Color(0xFF43C053) : Tg.textDim,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              ),
              side: BorderSide(
                color: active ? const Color(0xFF43C053) : Colors.transparent,
              ),
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
            const Icon(Icons.fingerprint_rounded, size: 17, color: Color(0xFFE5A93B)),
            const SizedBox(width: 8),
            Text(
              tr('ai_psychotype_title'),
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Tg.text),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Tg.field,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: TextField(
            controller: _psychotypeController,
            minLines: 1,
            maxLines: 7,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            onChanged: (val) {
              _dossierNotifier.value = dossier.copyWith(psychotype: val);
            },
            style: const TextStyle(fontSize: 13, color: Tg.text, height: 1.35),
            decoration: InputDecoration(
              hintText: tr('ai_psychotype_hint'),
              hintStyle: const TextStyle(fontSize: 13, color: Tg.textFaint),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFactsSection(ContactDossier dossier) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.checklist_rounded, size: 17, color: Tg.accent),
            const SizedBox(width: 8),
            Text(
              tr('ai_facts_title'),
              style: const TextStyle(fontSize: 13, fontWeight: Tg.fontMedium, color: Tg.text),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...dossier.facts.asMap().entries.map((entry) {
          final idx = entry.key;
          final fact = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                const Icon(Icons.circle, size: 6, color: Tg.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    fact,
                    style: const TextStyle(fontSize: 12.5, color: Tg.text),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 15, color: Tg.textFaint),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
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
                decoration: BoxDecoration(
                  color: Tg.field,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Tg.borderSubtle),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TextField(
                  controller: _newFactController,
                  onSubmitted: (_) => _addFact(),
                  style: const TextStyle(fontSize: 13, color: Tg.text),
                  decoration: InputDecoration(
                    hintText: tr('ai_facts_hint'),
                    hintStyle: const TextStyle(fontSize: 13, color: Tg.textFaint),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded, color: Tg.accent, size: 24),
              onPressed: _addFact,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 10,
        children: [
          OutlinedButton.icon(
            onPressed: _openOrCreateCopilotChat,
            icon: const Icon(Icons.forum_outlined, size: 16, color: Tg.accent),
            label: Text(
              tr('ai_chat_about_contact'),
              style: const TextStyle(
                color: Tg.accent,
                fontSize: 12,
                fontWeight: Tg.fontMedium,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Tg.border),
              backgroundColor: Tg.field,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          OutlinedButton.icon(
            onPressed: _openExportDialog,
            icon: const Icon(Icons.badge_outlined, size: 16, color: Tg.accentHover),
            label: Text(
              tr('ai_export_advisor'),
              style: const TextStyle(
                color: Tg.accentHover,
                fontSize: 12,
                fontWeight: Tg.fontMedium,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Tg.accent.withValues(alpha: 0.3)),
              backgroundColor: Tg.accentSubtle,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(tr('close'), style: const TextStyle(color: Tg.textDim, fontSize: 13)),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  _dossierNotifier.value = _dossierNotifier.value.copyWith(
                    goal: _goalController.text.trim(),
                    psychotype: _psychotypeController.text.trim(),
                  );
                  TgToast.show(context, tr('ai_dossier_saved_toast'));
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Tg.accentDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(tr('ai_save_changes'), style: const TextStyle(fontSize: 13, fontWeight: Tg.fontMedium)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return tr('time_just_now');
    if (diff.inMinutes < 60) return tr('time_minutes_ago', {'min': diff.inMinutes.toString()});
    return tr('time_hours_ago', {'hours': diff.inHours.toString()});
  }
}
