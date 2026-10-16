import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/localization/app_locale.dart';
import '../../../core/theme/tg_theme.dart';
import '../../../core/utils/link_handler.dart';
import '../models/copilot_session.dart';

/// Виджет сообщения (бабл) в диалоге с Copilot: поддерживает роли пользователя и агента,
/// лог вызова тулов, прикрепленные изображения/файлы, форматирование ссылок и кнопку ретрая.
class CopilotMessageBubble extends StatelessWidget {
  const CopilotMessageBubble({
    super.key,
    required this.session,
    required this.msg,
    this.lastUserQuery,
    this.isLoading = false,
    this.onRetry,
    this.onOpenSettings,
  });

  final CopilotSession session;
  final CopilotMessage msg;
  final String? lastUserQuery;
  final bool isLoading;
  final VoidCallback? onRetry;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final isRu = I18n.instance.isRu;

    if (msg.isError) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          constraints: const BoxConstraints(maxWidth: 580),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF2C191D),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.redAccent.withValues(alpha: 0.4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.error_outline_rounded, size: 16, color: Colors.redAccent),
                  const SizedBox(width: 8),
                  Text(
                    isRu ? 'Ошибка генерации ответа' : 'Response generation failed',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.redAccent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SelectableText(
                msg.text,
                style: const TextStyle(fontSize: 13, color: Tg.text, height: 1.35),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (lastUserQuery != null && onRetry != null)
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: isLoading ? null : onRetry,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Tg.accent.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Tg.accent.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.refresh_rounded, size: 14, color: Tg.accent),
                            const SizedBox(width: 6),
                            Text(
                              isRu ? 'Повторить попытку' : 'Retry',
                              style: const TextStyle(fontSize: 12, color: Tg.accent, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (onOpenSettings != null)
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: onOpenSettings,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.tune_rounded, size: 14, color: Tg.textDim),
                            const SizedBox(width: 6),
                            Text(
                              isRu ? 'Настройки AI' : 'AI Settings',
                              style: const TextStyle(fontSize: 12, color: Tg.textDim, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        constraints: const BoxConstraints(maxWidth: 580),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: msg.isUser ? const Color(0xFF2B5278) : const Color(0xFF182533),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: msg.isUser
                ? Colors.transparent
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!msg.isUser) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(session.avatarIcon, size: 13, color: session.avatarColor),
                  const SizedBox(width: 6),
                  Text(
                    session.agentRole,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: session.avatarColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
            if (msg.toolName != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF51B2FF).withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.terminal_rounded, size: 13, color: Color(0xFF51B2FF)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            msg.toolName!,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: Color(0xFF51B2FF),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (msg.toolOutput != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        msg.toolOutput!,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Tg.textDim,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            if (msg.attachmentPath != null) ...[
              if (msg.isImageAttachment && File(msg.attachmentPath!).existsSync())
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320, maxHeight: 220),
                      child: Image.file(
                        File(msg.attachmentPath!),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                )
              else
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        (msg.attachmentName?.toLowerCase().endsWith('.m4a') == true ||
                         msg.attachmentName?.toLowerCase().endsWith('.ogg') == true ||
                         msg.attachmentName?.toLowerCase().endsWith('.mp3') == true ||
                         msg.attachmentName?.contains('voice_') == true)
                            ? Icons.mic_rounded
                            : Icons.insert_drive_file_rounded,
                        size: 16,
                        color: const Color(0xFF51B2FF),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          msg.attachmentName ?? (isRu ? 'Файл' : 'File'),
                          style: const TextStyle(fontSize: 12, color: Tg.text),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            SelectableText.rich(
              TextSpan(
                style: const TextStyle(fontSize: 13.5, color: Tg.text, height: 1.35),
                children: LinkHandler.buildSpans(
                  context: context,
                  text: msg.text,
                  outgoing: msg.isUser,
                  linkColor: msg.isUser ? const Color(0xFFE0D8FF) : const Color(0xFF51B2FF),
                  baseStyle: const TextStyle(fontSize: 13.5, color: Tg.text, height: 1.35),
                ),
              ),
              cursorColor: Tg.accent,
              selectionColor: Tg.accent.withValues(alpha: 0.35),
            ),
          ],
        ),
      ),
    );
  }
}
