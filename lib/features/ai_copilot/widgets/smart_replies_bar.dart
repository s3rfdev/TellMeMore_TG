import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../core/localization/app_locale.dart';
import '../../../core/theme/tg_theme.dart';
import '../../../core/widgets/tg_toast.dart';
import '../../../data/models/tg_chat.dart';
import '../../../state/app_state.dart';
import '../models/contact_dossier.dart';
import '../models/copilot_session.dart';
import '../services/copilot_session_store.dart';
import '../services/smart_reply_engine.dart';
import '../services/voice_transcription_service.dart';

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
  bool _isTranscribing = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  bool _isGenerating = false;
  String? _generatingStatus;
  String? _voicePath;
  final AudioRecorder _audioRecorder = AudioRecorder();

  final TextEditingController _instructionController = TextEditingController();

  @override
  void dispose() {
    _recordTimer?.cancel();
    _audioRecorder.dispose();
    _instructionController.dispose();
    super.dispose();
  }

  void _handleAutoReply() async {
    final isRu = I18n.instance.isRu;
    setState(() {
      _isGenerating = true;
      _generatingStatus = isRu ? '🧠 Генерация ответа по контексту диалога...' : '🧠 Generating contextual reply...';
    });
    AppState.aiProcessingStatus.value = _generatingStatus;
    final dossier = ContactDossierStore.instance.getDossier(widget.chat.id).value;
    try {
      final reply = await SmartReplyEngine.generateAutoReplyAsync(
        chatTitle: widget.chat.title,
        messages: widget.messages,
        dossier: dossier,
      );
      if (!mounted) return;
      widget.onSelected(reply);
    } catch (e) {
      if (!mounted) return;
      final reply = SmartReplyEngine.generateAutoReply(
        chatTitle: widget.chat.title,
        messages: widget.messages,
        dossier: dossier,
      );
      TgToast.show(
        context,
        isRu ? '⚠️ Использован локальный ответ (ошибка AI: $e)' : '⚠️ Used fallback reply (AI error: $e)',
      );
      widget.onSelected(reply);
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _generatingStatus = null;
        });
      }
      AppState.aiProcessingStatus.value = null;
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      _recordTimer?.cancel();
      final path = await _audioRecorder.stop();
      final finalPath = path ?? _voicePath;
      final sec = _recordSeconds;

      setState(() {
        _isRecording = false;
        _recordSeconds = 0;
        _isTranscribing = true;
      });

      if (finalPath != null &&
          File(finalPath).existsSync() &&
          (sec > 0 || File(finalPath).lengthSync() > 1000)) {
        AppState.aiProcessingStatus.value = I18n.instance.isRu
            ? '🎤 Распознавание голосовой инструкции...'
            : '🎤 Transcribing voice instruction...';
        if (mounted) {
          TgToast.show(
            context,
            I18n.instance.isRu ? '🎤 Распознавание речи...' : '🎤 Transcribing speech...',
            icon: Icons.mic_rounded,
          );
        }
        try {
          final text = await VoiceTranscriptionService.instance.transcribeVoiceFile(
            filePath: finalPath,
            durationSeconds: sec,
          );
          if (mounted) {
            if (text.isNotEmpty && !text.startsWith('[')) {
              _instructionController.text = text;
              TgToast.show(
                context,
                I18n.instance.isRu ? '✓ Текст распознан' : '✓ Speech recognized',
                icon: Icons.check_circle_rounded,
              );
            } else {
              TgToast.show(
                context,
                I18n.instance.isRu
                    ? 'Не удалось распознать речь'
                    : 'Could not transcribe speech',
                icon: Icons.mic_off_rounded,
              );
            }
          }
        } catch (e) {
          if (mounted) TgToast.show(context, 'Ошибка STT: $e');
        } finally {
          AppState.aiProcessingStatus.value = null;
        }
      } else {
        if (mounted) {
          TgToast.show(
            context,
            I18n.instance.isRu ? 'Аудиозапись слишком короткая' : 'Audio recording is too short',
            icon: Icons.mic_none_rounded,
          );
        }
      }
      if (mounted) {
        setState(() => _isTranscribing = false);
      }
    } else {
      try {
        if (!await _audioRecorder.hasPermission()) {
          if (mounted) {
            TgToast.show(
              context,
              tr('no_mic_permission'),
              icon: Icons.mic_off_rounded,
            );
          }
          return;
        }
        final tempDir = await getTemporaryDirectory();
        final path = '${tempDir.path}/smart_reply_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000, sampleRate: 44100),
          path: path,
        );
        setState(() {
          _isRecording = true;
          _recordSeconds = 0;
          _voicePath = path;
        });
        _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (!mounted) return;
          setState(() => _recordSeconds++);
        });
      } catch (e) {
        if (mounted) {
          TgToast.show(
            context,
            tr('recording_error', {'error': e.toString()}),
            icon: Icons.error_outline_rounded,
          );
        }
      }
    }
  }

  void _handleInstructionSubmit() async {
    final isRu = I18n.instance.isRu;
    if (_isRecording) {
      await _toggleRecording();
    }
    final text = _instructionController.text.trim();
    if (text.isEmpty) {
      if (mounted) {
        TgToast.show(
          context,
          isRu ? 'Надиктуйте или введите инструкцию' : 'Dictate or enter instruction',
        );
      }
      return;
    }

    final dossier = ContactDossierStore.instance.getDossier(widget.chat.id).value;
    setState(() {
      _isGenerating = true;
      _generatingStatus = isRu
          ? '🧠 Генерация ответа по инструкции: "$text"...'
          : '🧠 Generating reply by instruction: "$text"...';
    });
    AppState.aiProcessingStatus.value = _generatingStatus;

    try {
      final reply = await SmartReplyEngine.generateInstructionReplyAsync(
        chatTitle: widget.chat.title,
        messages: widget.messages,
        instruction: text,
        dossier: dossier,
      );
      if (!mounted) return;
      widget.onSelected(reply);
    } catch (e) {
      if (!mounted) return;
      final reply = SmartReplyEngine.generateInstructionReply(
        chatTitle: widget.chat.title,
        messages: widget.messages,
        instruction: text,
        dossier: dossier,
      );
      TgToast.show(
        context,
        isRu ? '⚠️ Использован локальный ответ (ошибка AI: $e)' : '⚠️ Used fallback reply (AI error: $e)',
      );
      widget.onSelected(reply);
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _generatingStatus = null;
        });
      }
      AppState.aiProcessingStatus.value = null;
    }
  }

  void _openCopilotSession(BuildContext context) {
    widget.onClose();
    final dossier = ContactDossierStore.instance.getDossier(widget.chat.id).value;
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

🎯 Цель общения с контактом: ${dossier.goal.isNotEmpty ? dossier.goal : defaultGoal}
🗣️ Тон и стиль общения: ${dossier.tone}
🧠 Психотип и особенности восприятия: ${dossier.psychotype.isNotEmpty ? dossier.psychotype : defaultPsycho}
📋 Известные факты из CRM:
${dossier.facts.map((f) => '• $f').join('\n')}
📊 Резюме переписки (Шерлок): ${dossier.summary}
''' : '''
You are a personal AI assistant for communicating with contact "${widget.chat.title}".
Your mission is to assist with conversations, analyze implicit motives, draft precise replies, and steer the dialogue towards the goal.

🎯 Contact goal: ${dossier.goal.isNotEmpty ? dossier.goal : defaultGoal}
🗣️ Tone of Voice: ${dossier.tone}
🧠 Psychotype & perception traits: ${dossier.psychotype.isNotEmpty ? dossier.psychotype : defaultPsycho}
📋 Known CRM facts:
${dossier.facts.map((f) => '• $f').join('\n')}
📊 Chat summary (Sherlock): ${dossier.summary}
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
                    '🎯 **Наша цель**: *"${dossier.goal.isNotEmpty ? dossier.goal : "Установить контакт"}"*\n'
                    '🧠 **Психотип**: *"${dossier.psychotype.isNotEmpty ? dossier.psychotype : "Прагматик"}"*\n'
                    '🗣️ **Тон**: *"${dossier.tone}"*\n\n'
                    'Я держу в контексте всю историю вашей переписки, CRM-факты и досье. '
                    'Ты можешь надиктовать мне любую задачу (например: *"как ему мягко отказать"*, *"составь оффер"* или *"проанализируй его последнее сообщение"*), и я помогу сформулировать идеальный ответ!'
                : 'Hello! I am your personal AI Copilot for contact **${widget.chat.title}**.\n\n'
                    '🎯 **Our goal**: *"${dossier.goal.isNotEmpty ? dossier.goal : "Establish contact"}"*\n'
                    '🧠 **Psychotype**: *"${dossier.psychotype.isNotEmpty ? dossier.psychotype : "Pragmatic"}"*\n'
                    '🗣️ **Tone**: *"${dossier.tone}"*\n\n'
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

    AppState.activeSidebarTab.value = SidebarTab.copilot;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 6),
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 8),
      decoration: BoxDecoration(
        color: Tg.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Tg.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 12, color: Tg.accent),
              const SizedBox(width: 5),
              Text(
                tr('ai_reply_title'),
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: Tg.fontMedium,
                  color: Tg.accent,
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
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Tg.accent),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _generatingStatus ?? tr('ai_reply_generating'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Tg.accent,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
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

  /// Кнопки действий
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
                color: Tg.accentDark,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Tg.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bolt_rounded, size: 14, color: Colors.white),
                  const SizedBox(width: 5),
                  Text(
                    tr('ai_reply_auto'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: Tg.fontMedium,
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
                color: Tg.field,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Tg.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.mic_rounded, size: 14, color: Tg.accent),
                  const SizedBox(width: 5),
                  Text(
                    tr('ai_reply_dictate'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: Tg.fontMedium,
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
                color: Tg.field,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Tg.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.forum_outlined, size: 14, color: Tg.accent),
                  const SizedBox(width: 5),
                  Text(
                    tr('ai_reply_copilot_chat'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: Tg.fontMedium,
                      color: Tg.text,
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
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Кнопка записи микрофона
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: GestureDetector(
                onTap: _toggleRecording,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: _isRecording
                        ? Tg.danger.withValues(alpha: 0.2)
                        : Tg.field,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _isRecording ? Tg.danger : Tg.border,
                    ),
                  ),
                  child: Icon(
                    _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                    size: 15,
                    color: _isRecording ? Tg.danger : Tg.accent,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Поле для инструкции / распознанного текста (1..5 строк с автоматическим ростом и скроллом)
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 32, maxHeight: 110),
                decoration: BoxDecoration(
                  color: Tg.field,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Tg.border),
                ),
                child: TextField(
                  controller: _instructionController,
                  minLines: 1,
                  maxLines: 5,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  style: const TextStyle(fontSize: 12, color: Tg.text, height: 1.35),
                  decoration: InputDecoration(
                    hintText: _isRecording
                        ? tr('ai_recording_status', {'sec': '$_recordSeconds'})
                        : (_isTranscribing
                            ? (I18n.instance.isRu ? 'Распознавание речи...' : 'Transcribing speech...')
                            : tr('ai_dictate_placeholder')),
                    hintStyle: const TextStyle(fontSize: 11.5, color: Tg.textFaint),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),

            // Кнопка применить / сгенерировать ответ
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _handleInstructionSubmit,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: Tg.accentDark,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Tg.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_awesome, size: 13, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          tr('ai_submit_reply'),
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: Tg.fontMedium,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
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
