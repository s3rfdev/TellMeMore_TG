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
import '../models/contact_dossier.dart';
import '../models/copilot_session.dart';
import '../services/copilot_session_store.dart';

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
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    final current = _dossierNotifier.value;
    final targetGoal = _goalController.text.trim();
    final updatedFacts = List<String>.from(current.facts);

    // Многофакторный анализ реальных сообщений диалога
    final messages = widget.chat.messages;
    int questionCount = 0;
    bool hasPriceTerms = false;
    bool hasTechTerms = false;
    bool hasFriendlyTerms = false;

    final isRu = I18n.instance.isRu;

    for (final m in messages) {
      final t = m.text.toLowerCase();
      if (t.contains('?')) questionCount++;
      if (t.contains('сколько') ||
          t.contains('цена') ||
          t.contains('руб') ||
          t.contains('\$') ||
          t.contains('оплат') ||
          t.contains('стоим') ||
          t.contains('price') ||
          t.contains('cost') ||
          t.contains('pay')) {
        hasPriceTerms = true;
      }
      if (t.contains('flutter') ||
          t.contains('dart') ||
          t.contains('api') ||
          t.contains('код') ||
          t.contains('git') ||
          t.contains('сервер') ||
          t.contains('code') ||
          t.contains('server')) {
        hasTechTerms = true;
      }
      if (t.contains('😊') ||
          t.contains('спасибо') ||
          t.contains('привет') ||
          t.contains('здорово') ||
          t.contains('рад') ||
          t.contains('thanks') ||
          t.contains('hello') ||
          t.contains('great')) {
        hasFriendlyTerms = true;
      }

      // Извлечение CRM-фактов из сообщений
      if (t.contains('нячанг') && !updatedFacts.any((f) => f.contains('Нячанг') || f.contains('Nha Trang'))) {
        updatedFacts.add(isRu ? '📍 Локация: Нячанг, Вьетнам' : '📍 Location: Nha Trang, Vietnam');
      }
      if (t.contains('flutter') && !updatedFacts.any((f) => f.contains('Flutter'))) {
        updatedFacts.add(isRu ? '💻 Стек: Flutter, Dart, мобильная и Desktop разработка' : '💻 Stack: Flutter, Dart, mobile & desktop development');
      }
      if (t.contains('github') && !updatedFacts.any((f) => f.contains('GitHub'))) {
        updatedFacts.add(isRu ? '🐙 Разработка открытых библиотек и репозиториев на GitHub' : '🐙 Open-source repository and library development on GitHub');
      }
      if (t.contains('вилл') && !updatedFacts.any((f) => f.contains('вилл') || f.contains('villa'))) {
        updatedFacts.add(isRu ? '🏡 Фокус: аренда апартаментов и вилл у моря' : '🏡 Focus: sea-view villas and apartments rental');
      }
    }

    if (!updatedFacts.any((f) => f.contains('быстрые решения') || f.contains('prompt decisions'))) {
      updatedFacts.add(isRu ? '⚡ Предпочитает быстрые решения без бюрократии' : '⚡ Prefers prompt decisions without bureaucracy');
    }
    if (!updatedFacts.any((f) => f.contains('вовлеченность') || f.contains('engagement'))) {
      updatedFacts.add(isRu ? '🎯 Высокая вовлеченность в обсуждение продукта' : '🎯 High product discussion engagement');
    }

    // Выведение психотипа на основе стиля общения собеседника
    String newPsychotype;
    if (hasPriceTerms) {
      newPsychotype = isRu
          ? 'Прагматик-контролёр. Внимателен к бюджетам, срокам и гарантиям. Принимает решения на основе прозрачных цифр.'
          : 'Pragmatic Controller. Attentive to budgets, timelines, and guarantees. Makes decisions based on transparent metrics.';
    } else if (hasTechTerms) {
      newPsychotype = isRu
          ? 'Технический архитектор / инноватор. Горит пет-проектами, ценит чистый код, открытые библиотеки и скорость.'
          : 'Technical Architect / Innovator. Passionate about projects, values clean code, open libraries, and development velocity.';
    } else if (hasFriendlyTerms) {
      newPsychotype = isRu
          ? 'Эмоциональный коммуникатор. Открыт к нетворкингу, ценит доверие, партнерские отношения и быструю обратную связь.'
          : 'Empathetic Communicator. Open to networking, values trust, long-term partnerships, and prompt feedback.';
    } else {
      newPsychotype = isRu
          ? 'Прагматичный новатор. Ориентирован на результат, открытость и надежность без бюрократии.'
          : 'Pragmatic Innovator. Goal-oriented, values transparency and reliability without red tape.';
    }

    _psychotypeController.text = newPsychotype;

    final summary = targetGoal.isNotEmpty
        ? (isRu
            ? 'Анализ диалога показал готовность к достижению цели "$targetGoal". Собеседник задал $questionCount уточняющих вопросов. Рекомендуется зафиксировать условия и перейти к следующему этапу.'
            : 'Conversation analysis shows readiness towards goal "$targetGoal". Contact asked $questionCount clarifying questions. Recommended to fix terms and proceed to next stage.')
        : (isRu
            ? 'Анализ переписки показал готовность к прямому сотрудничеству. Собеседник ценит оперативную обратную связь и экспертизу.'
            : 'Chat analysis indicates readiness for direct collaboration. Contact appreciates quick responses and technical expertise.');

    _dossierNotifier.value = current.copyWith(
      psychotype: newPsychotype,
      summary: summary,
      facts: updatedFacts,
      lastAnalyzed: DateTime.now(),
    );

    setState(() => _isAnalyzing = false);
    TgToast.show(context, tr('ai_dossier_analyzed_toast'));
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
    final defaultPsycho = isRu ? "Прагматик" : "Pragmatic";

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
        avatarColor: const Color(0xFF8774E1),
        messages: [
          CopilotMessage(
            text: isRu
                ? 'Привет! Я твой персональный AI-копилот по контакту **${widget.chat.title}**.\n\n'
                    '🎯 **Наша цель**: *"${goal.isNotEmpty ? goal : "Установить контакт"}"*\n'
                    '🧠 **Психотип**: *"${psychotype.isNotEmpty ? psychotype : "Прагматик"}"*\n'
                    '🗣️ **Тон**: *"${_dossierNotifier.value.tone}"*\n\n'
                    'Я держу в контексте всю историю вашей переписки, CRM-факты и досье. '
                    'Ты можешь надиктовать мне любую задачу (например: *"как ему мягко отказать"*, *"составь оффер"* или *"проанализируй его последнее сообщение"*), и я помогу сформулировать идеальный ответ!'
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
            size: 44,
            fontSize: 18,
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
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Tg.text,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8774E1).withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.auto_awesome, size: 12, color: Color(0xFF8774E1)),
                          const SizedBox(width: 4),
                          Text(
                            tr('ai_dossier_crm_badge'),
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF8774E1),
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
                  style: const TextStyle(fontSize: 12, color: Tg.textFaint),
                ),
              ],
            ),
          ),
          Tooltip(
            message: tr('ai_dossier_export_tooltip'),
            child: CircleIconButton(
              icon: Icons.ios_share_rounded,
              iconSize: 18,
              color: const Color(0xFF8774E1),
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF8774E1).withValues(alpha: 0.18),
            const Color(0xFF2F6FA8).withValues(alpha: 0.14),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF8774E1).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology_outlined, size: 20, color: Color(0xFF8774E1)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tr('ai_sherlock_header'),
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF8774E1),
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
          const SizedBox(height: 8),
          Text(
            dossier.summary,
            style: const TextStyle(fontSize: 12.5, color: Tg.text, height: 1.35),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _isAnalyzing ? null : _runAutoAnalysis,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8774E1),
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
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
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
            const Icon(Icons.flag_outlined, size: 17, color: Color(0xFF51B2FF)),
            const SizedBox(width: 8),
            Text(
              tr('ai_goal_title'),
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Tg.text),
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
              selectedColor: const Color(0xFF8774E1).withValues(alpha: 0.3),
              backgroundColor: Tg.field,
              labelStyle: TextStyle(
                fontSize: 12,
                color: active ? const Color(0xFF8774E1) : Tg.textDim,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              ),
              side: BorderSide(
                color: active ? const Color(0xFF8774E1) : Colors.transparent,
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
            const Icon(Icons.checklist_rounded, size: 17, color: Color(0xFF8774E1)),
            const SizedBox(width: 8),
            Text(
              tr('ai_facts_title'),
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Tg.text),
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
                const Icon(Icons.circle, size: 6, color: Color(0xFF8774E1)),
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
              icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF8774E1), size: 24),
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
            icon: const Icon(Icons.forum_outlined, size: 16, color: Color(0xFF8774E1)),
            label: Text(
              tr('ai_chat_about_contact'),
              style: const TextStyle(
                color: Color(0xFF8774E1),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF8774E1)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          OutlinedButton.icon(
            onPressed: _openExportDialog,
            icon: const Icon(Icons.badge_outlined, size: 16, color: Color(0xFFB1A4FF)),
            label: Text(
              tr('ai_export_advisor'),
              style: const TextStyle(
                color: Color(0xFFB1A4FF),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: const Color(0xFF8774E1).withValues(alpha: 0.6)),
              backgroundColor: const Color(0xFF8774E1).withValues(alpha: 0.1),
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
                  backgroundColor: Tg.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(tr('ai_save_changes'), style: const TextStyle(fontSize: 13)),
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
