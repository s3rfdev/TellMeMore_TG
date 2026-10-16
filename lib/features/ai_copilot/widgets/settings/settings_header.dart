import 'package:flutter/material.dart';

import '../../../../core/localization/app_locale.dart';
import '../../../../core/theme/tg_theme.dart';
import '../../../../state/app_state.dart';

/// Верхняя панель текущего раздела настроек (иконка, заголовок, кнопка «Назад» для мобильных экранов и обновление моделей).
class SettingsHeader extends StatelessWidget {
  const SettingsHeader({
    super.key,
    required this.section,
    required this.showBack,
    this.onBack,
    this.loadingModels = false,
    this.onRefreshModels,
  });

  final SettingsSection section;
  final bool showBack;
  final VoidCallback? onBack;
  final bool loadingModels;
  final VoidCallback? onRefreshModels;

  @override
  Widget build(BuildContext context) {
    IconData icon;
    String title;
    switch (section) {
      case SettingsSection.profile:
        icon = Icons.person_outline_rounded;
        title = tr('settings_profile');
        break;
      case SettingsSection.general:
        icon = Icons.tune_rounded;
        title = tr('settings_general');
        break;
      case SettingsSection.autopilot:
        icon = Icons.smart_toy_outlined;
        title = tr('settings_autopilot');
        break;
      case SettingsSection.context:
        icon = Icons.psychology_outlined;
        title = tr('settings_context');
        break;
      case SettingsSection.voice:
        icon = Icons.mic_none_rounded;
        title = tr('settings_voice');
        break;
      case SettingsSection.cache:
        icon = Icons.storage_rounded;
        title = tr('settings_cache');
        break;
    }

    return Container(
      height: 48,
      margin: const EdgeInsets.fromLTRB(10, 10, 10, 6),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Tg.sidebar,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Tg.border),
      ),
      child: Row(
        children: [
          if (showBack) ...[
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: Tg.textDim),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              splashRadius: 18,
              tooltip: tr('back'),
              onPressed: onBack,
            ),
            const SizedBox(width: 4),
          ],
          Icon(icon, color: Tg.accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: Tg.fontMedium,
                color: Tg.text,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (section == SettingsSection.general && onRefreshModels != null)
            Tooltip(
              message: tr('ai_check_connection'),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: loadingModels ? null : onRefreshModels,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Tg.card,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Tg.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      loadingModels
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Tg.accent))
                          : const Icon(Icons.refresh_rounded, size: 16, color: Tg.accent),
                      if (MediaQuery.sizeOf(context).width > 480) ...[
                        const SizedBox(width: 6),
                        Text(
                          tr('ai_check_connection'),
                          style: const TextStyle(fontSize: 12, fontWeight: Tg.fontMedium, color: Tg.accent),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
