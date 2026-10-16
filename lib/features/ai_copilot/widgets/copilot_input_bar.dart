import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/localization/app_locale.dart';
import '../../../core/theme/tg_theme.dart';
import '../models/copilot_session.dart';

/// Виджет записи голосового сообщения для Copilot с таймером и кнопками отмены/отправки.
class CopilotVoiceBar extends StatelessWidget {
  const CopilotVoiceBar({
    super.key,
    required this.session,
    required this.recordSeconds,
    required this.onCancel,
    required this.onSend,
  });

  final CopilotSession session;
  final int recordSeconds;
  final VoidCallback onCancel;
  final VoidCallback onSend;

  String _formatDuration(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isRu = I18n.instance.isRu;
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 4, 10, 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Tg.sidebar,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: Tg.danger,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _formatDuration(recordSeconds),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Tg.text,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              isRu ? 'Говорите, идёт запись...' : 'Recording voice for Copilot...',
              style: const TextStyle(fontSize: 13, color: Tg.textDim),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20, color: Tg.textFaint),
            onPressed: onCancel,
            tooltip: tr('cancel'),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onSend,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: session.avatarColor,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.arrow_upward_rounded, size: 20, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

/// Виджет панели ввода текста и отправки запросов в Copilot с поддержкой вложений и голосового ввода.
class CopilotInputBar extends StatelessWidget {
  const CopilotInputBar({
    super.key,
    required this.session,
    required this.controller,
    required this.isLoading,
    required this.isRecordingVoice,
    required this.recordSeconds,
    this.attachedFilePath,
    this.attachedFileName,
    this.isAttachedImage = false,
    required this.onPickAttachment,
    required this.onClearAttachment,
    required this.onStartVoice,
    required this.onCancelVoice,
    required this.onSendVoice,
    required this.onSendMessage,
  });

  final CopilotSession session;
  final TextEditingController controller;
  final bool isLoading;
  final bool isRecordingVoice;
  final int recordSeconds;
  final String? attachedFilePath;
  final String? attachedFileName;
  final bool isAttachedImage;
  final VoidCallback onPickAttachment;
  final VoidCallback onClearAttachment;
  final VoidCallback onStartVoice;
  final VoidCallback onCancelVoice;
  final VoidCallback onSendVoice;
  final ValueChanged<String> onSendMessage;

  @override
  Widget build(BuildContext context) {
    if (isRecordingVoice) {
      return CopilotVoiceBar(
        session: session,
        recordSeconds: recordSeconds,
        onCancel: onCancelVoice,
        onSend: onSendVoice,
      );
    }

    final isTextEmpty = controller.text.trim().isEmpty && attachedFilePath == null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (attachedFilePath != null)
          Container(
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Tg.sidebar,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF51B2FF).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                if (isAttachedImage && File(attachedFilePath!).existsSync())
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.file(
                      File(attachedFilePath!),
                      width: 32,
                      height: 32,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  const Icon(Icons.attach_file_rounded, size: 20, color: Color(0xFF51B2FF)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    attachedFileName ?? 'Файл',
                    style: const TextStyle(fontSize: 12.5, color: Tg.text, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: onClearAttachment,
                  child: const Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Icon(Icons.close_rounded, size: 16, color: Tg.textFaint),
                  ),
                ),
              ],
            ),
          ),
        Container(
          margin: const EdgeInsets.fromLTRB(10, 4, 10, 10),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Tg.sidebar,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  Icons.attach_file_rounded,
                  size: 20,
                  color: isLoading ? Tg.textFaint : Tg.textDim,
                ),
                onPressed: isLoading ? null : onPickAttachment,
                tooltip: I18n.instance.isRu ? 'Прикрепить файл или фото' : 'Attach file or photo',
                splashRadius: 18,
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: controller,
                  readOnly: isLoading,
                  onSubmitted: isLoading ? null : onSendMessage,
                  style: const TextStyle(fontSize: 14, color: Tg.text),
                  decoration: InputDecoration(
                    hintText: isLoading
                        ? (I18n.instance.isRu ? '🧠 Нейросеть генерирует ответ...' : '🧠 AI is generating response...')
                        : tr('ask_agent_placeholder', {'role': session.agentRole}),
                    hintStyle: TextStyle(
                      fontSize: 13.5,
                      color: isLoading ? Tg.accent.withValues(alpha: 0.7) : Tg.textFaint,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (isTextEmpty)
                Tooltip(
                  message: I18n.instance.isRu ? 'Надиктовать голосом' : 'Voice dictation',
                  child: GestureDetector(
                    onTap: isLoading ? null : onStartVoice,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Tg.field,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Icon(
                        Icons.mic_none_rounded,
                        size: 20,
                        color: isLoading ? Tg.textFaint : session.avatarColor,
                      ),
                    ),
                  ),
                )
              else
                GestureDetector(
                  onTap: isLoading ? null : () => onSendMessage(controller.text),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isLoading ? session.avatarColor.withValues(alpha: 0.5) : session.avatarColor,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: isLoading
                        ? const Center(
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            ),
                          )
                        : const Icon(Icons.arrow_upward_rounded, size: 20, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
