import 'package:flutter/material.dart';

import '../../../core/localization/app_locale.dart';
import '../../../core/theme/tg_theme.dart';
import '../../../core/widgets/tg_avatar.dart';
import '../../../data/models/tg_account.dart';
import '../../../state/app_state.dart';

/// Левая колонка для раздела "Настройки":
/// Отображает разделы настроек вместо списка чатов в левой панели.
class SettingsSidebarView extends StatelessWidget {
  const SettingsSidebarView({super.key, this.onClose});

  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(context),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            children: [
              _buildAccountTile(context),
              const SizedBox(height: 10),
              Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
              const SizedBox(height: 10),
              ValueListenableBuilder<SettingsSection>(
                valueListenable: AppState.activeSettingsSection,
                builder: (context, activeSection, _) {
                  return Column(
                    children: [
                      _buildSectionTile(
                        section: SettingsSection.profile,
                        active: activeSection == SettingsSection.profile,
                        icon: Icons.person_outline_rounded,
                        title: tr('settings_profile'),
                        subtitle: tr('settings_profile_sub'),
                      ),
                      const SizedBox(height: 4),
                      _buildSectionTile(
                        section: SettingsSection.general,
                        active: activeSection == SettingsSection.general,
                        icon: Icons.tune_rounded,
                        title: tr('settings_general'),
                        subtitle: tr('settings_general_sub'),
                      ),
                      const SizedBox(height: 4),
                      _buildSectionTile(
                        section: SettingsSection.autopilot,
                        active: activeSection == SettingsSection.autopilot,
                        icon: Icons.smart_toy_outlined,
                        title: tr('settings_autopilot'),
                        subtitle: tr('settings_autopilot_sub'),
                      ),
                      const SizedBox(height: 4),
                      _buildSectionTile(
                        section: SettingsSection.context,
                        active: activeSection == SettingsSection.context,
                        icon: Icons.psychology_outlined,
                        title: tr('settings_context'),
                        subtitle: tr('settings_context_sub'),
                      ),
                      const SizedBox(height: 4),
                      _buildSectionTile(
                        section: SettingsSection.voice,
                        active: activeSection == SettingsSection.voice,
                        icon: Icons.mic_none_rounded,
                        title: tr('settings_voice'),
                        subtitle: tr('settings_voice_sub'),
                      ),
                      const SizedBox(height: 4),
                      _buildSectionTile(
                        section: SettingsSection.cache,
                        active: activeSection == SettingsSection.cache,
                        icon: Icons.storage_rounded,
                        title: tr('settings_cache'),
                        subtitle: tr('settings_cache_sub'),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: Row(
        children: [
          const Icon(Icons.settings_outlined, size: 20, color: Tg.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tr('settings'),
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: Tg.fontMedium,
                color: Tg.text,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 19, color: Tg.textDim),
            tooltip: tr('chats'),
            onPressed: () {
              if (onClose != null) {
                onClose!();
              } else {
                AppState.activeSidebarTab.value = SidebarTab.chats;
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAccountTile(BuildContext context) {
    return ValueListenableBuilder<TgAccount>(
      valueListenable: AccountManager.instance.currentAccount,
      builder: (context, acc, _) {
        return ValueListenableBuilder<SettingsSection>(
          valueListenable: AppState.activeSettingsSection,
          builder: (context, activeSection, _) {
            final isSelected = activeSection == SettingsSection.profile;
            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                AppState.activeSettingsSection.value = SettingsSection.profile;
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isSelected ? Tg.accent.withValues(alpha: 0.12) : Tg.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? Tg.accent.withValues(alpha: 0.4) : Tg.border,
                  ),
                ),
                child: Row(
                  children: [
                    TgAvatar(
                      emoji: acc.avatarEmoji,
                      color: acc.avatarColor,
                      imagePath: acc.avatarPath,
                      size: 40,
                      fontSize: 16,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            acc.name.isNotEmpty ? acc.name : tr('user_default'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: Tg.fontMedium,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            acc.phone.isNotEmpty
                                ? acc.phone
                                : (acc.username.isNotEmpty ? acc.username : tr('last_seen_recently')),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: Tg.fontRegular,
                              color: Tg.textDim,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: isSelected ? Tg.accent : Tg.textFaint,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSectionTile({
    required SettingsSection section,
    required bool active,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        AppState.activeSettingsSection.value = section;
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: active ? Tg.accent.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? Tg.accent.withValues(alpha: 0.35) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: active ? Tg.accent.withValues(alpha: 0.2) : Tg.card,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 18,
                color: active ? Tg.accent : Tg.textDim,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: active ? Tg.fontMedium : Tg.fontRegular,
                      color: active ? Colors.white : Tg.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: Tg.fontRegular,
                      color: Tg.textDim,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: active ? Tg.accent : Tg.textFaint,
            ),
          ],
        ),
      ),
    );
  }
}
