import 'package:flutter/material.dart';

import '../../../core/localization/app_locale.dart';
import '../../../core/theme/tg_theme.dart';
import '../../../data/models/tg_chat.dart';
import '../../ai_copilot/models/contact_dossier.dart';
import '../../ai_copilot/models/copilot_session.dart';
import '../../ai_copilot/services/copilot_session_store.dart';
import '../../../core/widgets/tg_toast.dart';

/// Диалог настройки системного промпта и целей AI для конкретного чата.
class ChatSystemPromptDialog extends StatefulWidget {
  const ChatSystemPromptDialog({super.key, required this.chat});

  final TgChat chat;

  static Future<void> show(BuildContext context, TgChat chat) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (context) => ChatSystemPromptDialog(chat: chat),
    );
  }

  @override
  State<ChatSystemPromptDialog> createState() => _ChatSystemPromptDialogState();
}

class _ChatSystemPromptDialogState extends State<ChatSystemPromptDialog> {
  late final TextEditingController _promptController;
  late final TextEditingController _goalController;
  late final TextEditingController _toneController;

  @override
  void initState() {
    super.initState();
    final dossier = ContactDossierStore.instance.getDossier(widget.chat.id).value;
    _promptController = TextEditingController(text: dossier.systemPrompt);
    _goalController = TextEditingController(text: dossier.goal);
    _toneController = TextEditingController(text: dossier.tone);
  }

  @override
  void dispose() {
    _promptController.dispose();
    _goalController.dispose();
    _toneController.dispose();
    super.dispose();
  }

  void _save() {
    final store = ContactDossierStore.instance;
    final prompt = _promptController.text.trim();
    final goal = _goalController.text.trim();
    final tone = _toneController.text.trim();

    store.updateSystemPrompt(widget.chat.id, prompt);
    store.updateGoal(widget.chat.id, goal);
    store.updateTone(widget.chat.id, tone);

    // Если уже открыта сессия Копилота для этого чата, обновляем её системный промпт
    final sessionId = 'contact_${widget.chat.id}';
    CopilotSessionStore.instance.updateSessionPrompt(sessionId, prompt);

    final isRu = I18n.instance.isRu;
    TgToast.show(
      context,
      isRu ? '✓ Системный промпт чата сохранён' : '✓ Chat system prompt saved',
      icon: Icons.check_circle_rounded,
    );

    Navigator.of(context).pop();
  }

  void _openInCopilot() {
    _save();
    final sessionId = 'contact_${widget.chat.id}';
    final existing = CopilotSessionStore.instance.sessions.value
        .where((s) => s.id == sessionId)
        .firstOrNull;

    final isRu = I18n.instance.isRu;
    final prompt = _promptController.text.trim();

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
                ? 'Чат с агентом по контакту **${widget.chat.title}** создан.\n'
                    '${prompt.isNotEmpty ? "Установлены директивы:\n*$prompt*\n\n" : ""}'
                    'Напишите мне задачу: составить ответ, изучить переписку или проанализировать позицию собеседника.'
                : 'Agent chat for **${widget.chat.title}** created.\n'
                    '${prompt.isNotEmpty ? "Configured directives:\n*$prompt*\n\n" : ""}'
                    'Tell me your task: draft a response, study chat history, or analyze contact stances.',
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
  }

  @override
  Widget build(BuildContext context) {
    final isRu = I18n.instance.isRu;

    return Dialog(
      backgroundColor: Tg.sidebar,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 540,
        constraints: const BoxConstraints(maxHeight: 680),
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Заголовок
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8774E1).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF8774E1).withValues(alpha: 0.5)),
                  ),
                  child: const Icon(Icons.psychology_rounded, color: Color(0xFF8774E1), size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isRu ? 'Системный промпт AI' : 'AI System Prompt',
                        style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w600,
                          color: Tg.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isRu
                            ? 'Директивы и инструкции для диалога с «${widget.chat.title}»'
                            : 'Directives and instructions for dialogue with "${widget.chat.title}"',
                        style: const TextStyle(fontSize: 12, color: Tg.textDim),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Tg.textDim, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Поля ввода
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Поле системного промпта
                    Text(
                      isRu ? 'Системные инструкции (Директивы агента)' : 'System Instructions (Agent Directives)',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Tg.text,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _promptController,
                      maxLines: 7,
                      minLines: 4,
                      style: const TextStyle(fontSize: 13.5, color: Tg.text, height: 1.4),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Tg.field,
                        hintText: isRu
                            ? 'Например: Отвечай коротко и вежливо. Главная задача — выяснить дедлайн проекта и предложить встречу в понедельник.'
                            : 'E.g.: Reply concisely and professionally. Primary goal is to clarify project deadline and propose a call on Monday.',
                        hintStyle: const TextStyle(color: Tg.textDim, fontSize: 13),
                        contentPadding: const EdgeInsets.all(14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF8774E1), width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Цель общения
                    Text(
                      isRu ? 'Цель общения' : 'Communication Goal',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Tg.text,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _goalController,
                      style: const TextStyle(fontSize: 13.5, color: Tg.text),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Tg.field,
                        hintText: isRu ? 'Договориться о встрече / Закрыть сделку' : 'Schedule a meeting / Close deal',
                        hintStyle: const TextStyle(color: Tg.textDim, fontSize: 13),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF8774E1), width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Тон и стиль
                    Text(
                      isRu ? 'Тон и стиль общения' : 'Tone & Style of Voice',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Tg.text,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _toneController,
                      style: const TextStyle(fontSize: 13.5, color: Tg.text),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Tg.field,
                        hintText: isRu ? 'Деловой / Дружелюбный / Экспертный' : 'Business / Friendly / Expert',
                        hintStyle: const TextStyle(color: Tg.textDim, fontSize: 13),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF8774E1), width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Кнопки действий
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: _openInCopilot,
                  icon: const Icon(Icons.forum_outlined, size: 16),
                  label: Text(isRu ? 'Открыть в Copilot' : 'Open in Copilot'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF8774E1),
                    side: const BorderSide(color: Color(0xFF8774E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        isRu ? 'Отмена' : 'Cancel',
                        style: const TextStyle(color: Tg.textDim),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8774E1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                        isRu ? 'Сохранить' : 'Save',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
