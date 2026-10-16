import 'package:flutter/material.dart';

import '../../../../core/localization/app_locale.dart';
import '../../../../core/theme/tg_theme.dart';

/// Нижняя панель действий диалога досье: переход в чат с Copilot, экспорт карточки, закрытие и сохранение.
class DossierBottomActions extends StatelessWidget {
  const DossierBottomActions({
    super.key,
    required this.onOpenCopilotChat,
    required this.onOpenExportDialog,
    required this.onClose,
    required this.onSave,
  });

  final VoidCallback onOpenCopilotChat;
  final VoidCallback onOpenExportDialog;
  final VoidCallback onClose;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 6,
        children: [
          OutlinedButton.icon(
            onPressed: onOpenCopilotChat,
            icon: const Icon(Icons.forum_outlined, size: 14, color: Tg.accent),
            label: Text(
              tr('ai_chat_about_contact'),
              style: const TextStyle(
                color: Tg.accent,
                fontSize: 10.5,
                fontWeight: Tg.fontMedium,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Tg.accent.withValues(alpha: 0.35)),
              backgroundColor: Tg.field,
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
            ),
          ),
          OutlinedButton.icon(
            onPressed: onOpenExportDialog,
            icon: const Icon(Icons.badge_outlined, size: 14, color: Tg.accentHover),
            label: Text(
              tr('ai_export_advisor'),
              style: const TextStyle(
                color: Tg.accentHover,
                fontSize: 10.5,
                fontWeight: Tg.fontMedium,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Tg.accent.withValues(alpha: 0.25)),
              backgroundColor: Tg.accentSubtle,
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: onClose,
                child: Text(tr('close'), style: const TextStyle(color: Tg.textDim, fontSize: 11)),
              ),
              const SizedBox(width: 4),
              ElevatedButton(
                onPressed: onSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Tg.accentDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                ),
                child: Text(tr('ai_save_changes'), style: const TextStyle(fontSize: 11, fontWeight: Tg.fontMedium)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
