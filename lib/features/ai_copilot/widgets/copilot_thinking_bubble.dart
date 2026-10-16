import 'package:flutter/material.dart';

import '../../../core/localization/app_locale.dart';
import '../models/copilot_session.dart';

/// Анимированный бабл прогресса выполнения запроса (STT транскрибация / инференс нейросети).
class CopilotThinkingBubble extends StatelessWidget {
  const CopilotThinkingBubble({
    super.key,
    required this.session,
    this.statusText,
  });

  final CopilotSession session;
  final String? statusText;

  @override
  Widget build(BuildContext context) {
    final isRu = I18n.instance.isRu;
    final text = statusText ?? (isRu ? '🧠 Формирование ответа...' : '🧠 Thinking...');

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF182533),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: session.avatarColor.withValues(alpha: 0.35),
          ),
          boxShadow: [
            BoxShadow(
              color: session.avatarColor.withValues(alpha: 0.08),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(session.avatarColor),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 12.5,
                  color: session.avatarColor.withValues(alpha: 0.95),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
