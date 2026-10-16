import 'package:flutter/material.dart';

import '../../core/localization/app_locale.dart';
import '../../core/theme/tg_theme.dart';
import '../../data/models/tg_account.dart';
import '../../data/tdlib/tdlib_service.dart';
import 'widgets/profile_action_buttons.dart';
import 'widgets/profile_avatar_section.dart';
import 'widgets/profile_header.dart';
import 'widgets/profile_info_card.dart';
import 'widgets/profile_posts_section.dart';
import 'widgets/profile_posts_tabs.dart';

/// Модальный диалог профиля пользователя (информация об аккаунте, действия, посты и архив).
class ProfileDialog extends StatefulWidget {
  const ProfileDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (_) => const ProfileDialog(),
    );
  }

  @override
  State<ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<ProfileDialog> {
  int _activeTab = 0; // 0: Posts, 1: Archived Posts

  @override
  void initState() {
    super.initState();
    // Auto-sync real Telegram profile data upon opening dialog
    TdlibService.instance.syncUserProfile();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ValueListenableBuilder<AppLanguage>(
        valueListenable: I18n.instance.currentLanguage,
        builder: (context, lang, child) {
          return ValueListenableBuilder<TgAccount>(
            valueListenable: AccountManager.instance.currentAccount,
            builder: (context, acc, _) {
              return Container(
                width: 440,
                constraints: const BoxConstraints(maxHeight: 740),
                decoration: BoxDecoration(
                  color: Tg.sidebar,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Tg.border),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Column(
                    children: [
                      ProfileHeader(account: acc),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                          children: [
                            ProfileAvatarSection(account: acc),
                            const SizedBox(height: 18),
                            const ProfileActionButtons(),
                            const SizedBox(height: 18),
                            ProfileInfoCard(account: acc),
                            const SizedBox(height: 18),
                            ProfilePostsTabs(
                              activeTab: _activeTab,
                              onTabChanged: (tab) => setState(() => _activeTab = tab),
                            ),
                            const SizedBox(height: 18),
                            ProfilePostsSection(activeTab: _activeTab),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
