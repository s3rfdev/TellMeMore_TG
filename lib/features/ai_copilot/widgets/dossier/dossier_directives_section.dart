import 'package:flutter/material.dart';

import '../../../../core/localization/app_locale.dart';
import '../../../../core/theme/tg_theme.dart';

/// Секция настройки системных инструкций (директив агента) для диалога с контактом.
class DossierDirectivesSection extends StatelessWidget {
  const DossierDirectivesSection({
    super.key,
    required this.promptController,
  });

  final TextEditingController promptController;

  @override
  Widget build(BuildContext context) {
    final isRu = I18n.instance.isRu;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.tune_rounded, size: 14, color: Tg.accent),
            const SizedBox(width: 6),
            Text(
              isRu ? 'Системные инструкции (Директивы агента)' : 'System Instructions (Agent Directives)',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Tg.text,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        TextFormField(
          controller: promptController,
          maxLines: 4,
          minLines: 2,
          style: const TextStyle(fontSize: 11, color: Tg.text, height: 1.3),
          decoration: InputDecoration(
            filled: true,
            fillColor: Tg.field,
            hintText: isRu
                ? 'Например: Отвечай коротко и вежливо. Главная задача — выяснить дедлайн проекта и предложить встречу.'
                : 'E.g.: Reply concisely and professionally. Primary goal is to clarify deadline and propose call.',
            hintStyle: const TextStyle(color: Tg.textDim, fontSize: 10.5),
            contentPadding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: const BorderSide(color: Tg.accent, width: 1.2),
            ),
          ),
        ),
      ],
    );
  }
}
