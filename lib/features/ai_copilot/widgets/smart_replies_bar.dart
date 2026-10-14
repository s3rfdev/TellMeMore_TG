import 'dart:async';
import 'package:flutter/material.dart';

import '../../../core/theme/tg_theme.dart';
import '../../../data/models/tg_chat.dart';
import '../../../state/app_state.dart';
import '../models/contact_dossier.dart';
import '../models/copilot_session.dart';
import '../services/copilot_session_store.dart';
import '../services/smart_reply_engine.dart';

/// Всплывающее меню AI Reply с тремя действиями:
/// 1. «Автоответ» — мгновенно формирует ответ на основе контекста чата и целей из досье.
/// 2. «Надиктовать» — позволяет надиктовать голосом или ввести личную инструкцию (контекст задачи) и сгенерировать ответ.
/// 3. «Copilot чат» — открывает или создает отдельный постоянный диалог с Copilot по данному контакту со всеми целями и досье.
class SmartRepliesBar extends StatefulWidget {
  const SmartRepliesBar({
    super.key,
    required this.chat,
    required this.messages,
    required this.onSelected,
    required this.onClose,
  });

  final TgChat chat;
  final List<TgMessage> messages;
  final ValueChanged<String> onSelected;
  final VoidCallback onClose;

  @override
  State<SmartRepliesBar> createState() => _SmartRepliesBarState();
}

class _SmartRepliesBarState extends State<SmartRepliesBar> {
  bool _isDictationMode = false;
  bool _isRecording = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  bool _isGenerating = false;

  final TextEditingController _instructionController = TextEditingController();

  @override
  void dispose() {
    _recordTimer?.cancel();
    _instructionController.dispose();
    super.dispose();
  }

  void _handleAutoReply() {
    setState(() => _isGenerating = true);
    final dossier = ContactDossierStore.instance.getDossier(widget.chat.id).value;
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final reply = SmartReplyEngine.generateAutoReply(
        chatTitle: widget.chat.title,
        messages: widget.messages,
        dossier: dossier,
      );
      setState(() => _isGenerating = false);
      widget.onSelected(reply);
    });
  }

  void _toggleRecording() {
    if (_isRecording) {
      // Остановить запись и подставить транскрибацию
      _recordTimer?.cancel();
      setState(() {
        _isRecording = false;
        if (_instructionController.text.trim().isEmpty) {
          _instructionController.text =
              'Мне этот человек неприятен, ответь вежливо, чтобы он отстал без грубости';
        }
      });
    } else {
      // Начать запись
      setState(() {
        _isRecording = true;
        _recordSeconds = 0;
      });
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        setState(() => _recordSeconds++);
      });
    }
  }

  void _handleInstructionSubmit() {
    final text = _instructionController.text.trim();
    if (text.isEmpty && !_isRecording) return;

    if (_isRecording) {
      _recordTimer?.cancel();
      _isRecording = false;
    }

    final query = text.isNotEmpty
        ? text
        : 'Мне этот человек неприятен, ответь вежливо, чтобы он отстал без грубости';

    final dossier = ContactDossierStore.instance.getDossier(widget.chat.id).value;
    setState(() => _isGenerating = true);
    Future.delayed(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      final reply = SmartReplyEngine.generateInstructionReply(
        chatTitle: widget.chat.title,
        messages: widget.messages,
        instruction: query,
        dossier: dossier,
      );
      setState(() => _isGenerating = false);
      widget.onSelected(reply);
    });
  }

  void _openCopilotSession(BuildContext context) {
    widget.onClose();
    final dossier = ContactDossierStore.instance.getDossier(widget.chat.id).value;
    final sessionId = 'contact_${widget.chat.id}';
    final existing = CopilotSessionStore.instance.sessions.value
        .where((s) => s.id == sessionId)
        .firstOrNull;

    final prompt = '''
Ты персональный AI-ассистент по общению с контактом "${widget.chat.title}".
Твоя задача — помогать вести диалог, анализировать скрытые мотивы, составлять точные ответы и вести контакт к цели.

🎯 Цель общения с контактом: ${dossier.goal.isNotEmpty ? dossier.goal : "Установить контакт и выявить потребности"}
🗣️ Тон и стиль общения: ${dossier.tone}
🧠 Психотип и особенности восприятия: ${dossier.psychotype.isNotEmpty ? dossier.psychotype : "Прагматик"}
📋 Известные факты из CRM:
${dossier.facts.map((f) => '• $f').join('\n')}
📊 Резюме переписки (Шерлок): ${dossier.summary}
''';

    if (existing == null) {
      final newSession = CopilotSession(
        id: sessionId,
        title: '👤 ${widget.chat.title}',
        agentRole: 'Ассистент по ${widget.chat.title}',
        systemPrompt: prompt,
        avatarIcon: Icons.person_pin_rounded,
        avatarColor: const Color(0xFF8774E1),
        messages: [
          CopilotMessage(
            text: 'Привет! Я твой персональный AI-копилот по контакту **${widget.chat.title}**.\n\n'
                '🎯 **Наша цель**: *"${dossier.goal.isNotEmpty ? dossier.goal : "Установить контакт"}"*\n'
                '🧠 **Психотип**: *"${dossier.psychotype.isNotEmpty ? dossier.psychotype : "Прагматик"}"*\n'
                '🗣️ **Тон**: *"${dossier.tone}"*\n\n'
                'Я держу в контексте всю историю вашей переписки, CRM-факты и досье. '
                'Ты можешь надиктовать мне любую задачу (например: *"как ему мягко отказать"*, *"составь оффер"* или *"проанализируй его последнее сообщение"*), и я помогу сформулировать идеальный ответ!',
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

    AppState.activeSidebarTab.value = SidebarTab.copilot;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 6),
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2735),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF8774E1).withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Заголовок более мелким шрифтом, чтобы занимать минимум места
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 12, color: Color(0xFF8774E1)),
              const SizedBox(width: 5),
              const Text(
                'AI reply на основе целей',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF8774E1),
                  letterSpacing: 0.1,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: widget.onClose,
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(Icons.close_rounded, size: 15, color: Tg.textFaint),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),

          if (_isGenerating)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: const [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8774E1)),
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Генерация ответа LLM...',
                    style: TextStyle(fontSize: 11.5, color: Tg.textDim),
                  ),
                ],
              ),
            )
          else if (!_isDictationMode)
            _buildTwoActionButtons()
          else
            _buildDictationBar(),
        ],
      ),
    );
  }

  /// Две кнопки вместо прежних пресетов
  Widget _buildTwoActionButtons() {
    return Row(
      children: [
        // Кнопка 1: Автоответ по контексту чата
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _handleAutoReply,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF8774E1).withValues(alpha: 0.25),
                    const Color(0xFF766AC8).withValues(alpha: 0.15),
                  ],
                ),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: const Color(0xFF8774E1).withValues(alpha: 0.4),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bolt_rounded, size: 14, color: Color(0xFF51B2FF)),
                  SizedBox(width: 5),
                  Text(
                    'Автоответ',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Кнопка 2: Надиктовать голосом с учётом сказанного
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _isDictationMode = true),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Tg.sidebar,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: const Color(0xFF51B2FF).withValues(alpha: 0.35),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.mic_rounded, size: 14, color: Color(0xFF51B2FF)),
                  SizedBox(width: 5),
                  Text(
                    'Надиктовать контекст',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Tg.text,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Кнопка 3: Открыть персональный чат с Copilot по контакту
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _openCopilotSession(context),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF8774E1).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: const Color(0xFF8774E1).withValues(alpha: 0.4),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.forum_outlined, size: 14, color: Color(0xFF8774E1)),
                  SizedBox(width: 5),
                  Text(
                    'Copilot чат',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF8774E1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Режим диктовки/ввода личной голосовой инструкции
  Widget _buildDictationBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            // Кнопка записи микрофона
            GestureDetector(
              onTap: _toggleRecording,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _isRecording
                      ? Colors.redAccent.withValues(alpha: 0.25)
                      : const Color(0xFF8774E1).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _isRecording ? Colors.redAccent : const Color(0xFF8774E1),
                  ),
                ),
                child: Icon(
                  _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                  size: 15,
                  color: _isRecording ? Colors.redAccent : const Color(0xFF8774E1),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Поле для инструкции / распознанного текста
            Expanded(
              child: Container(
                height: 30,
                decoration: BoxDecoration(
                  color: Tg.sidebar,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: TextField(
                  controller: _instructionController,
                  style: const TextStyle(fontSize: 11.5, color: Tg.text),
                  decoration: InputDecoration(
                    hintText: _isRecording
                        ? 'Идёт запись ($_recordSeconds с)... говорите задачу'
                        : 'Надиктовать: например, отшить вежливо без грубости',
                    hintStyle: const TextStyle(fontSize: 11, color: Tg.textFaint),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                  ),
                  onSubmitted: (_) => _handleInstructionSubmit(),
                ),
              ),
            ),
            const SizedBox(width: 6),

            // Кнопка применить / сгенерировать ответ
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _handleInstructionSubmit,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8774E1), Color(0xFF766AC8)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, size: 12, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'Ответить',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),

            // Отмена / возврат к двум кнопкам
            GestureDetector(
              onTap: () {
                _recordTimer?.cancel();
                setState(() {
                  _isRecording = false;
                  _isDictationMode = false;
                });
              },
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.arrow_back_rounded, size: 14, color: Tg.textFaint),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
