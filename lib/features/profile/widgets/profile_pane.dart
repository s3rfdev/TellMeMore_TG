import 'package:flutter/material.dart';

import '../../../data/models/tg_account.dart';
import '../../../data/tdlib/tdlib_service.dart';
import 'profile_accounts_section.dart';
import 'profile_action_buttons.dart';
import 'profile_avatar_section.dart';
import 'profile_info_card.dart';
import 'profile_posts_section.dart';
import 'profile_posts_tabs.dart';

/// Полноразмерная панель профиля для раздела настроек "Профиль и аккаунт".
class ProfilePane extends StatefulWidget {
  const ProfilePane({super.key});

  @override
  State<ProfilePane> createState() => _ProfilePaneState();
}

class _ProfilePaneState extends State<ProfilePane> {
  int _activeTab = 0; // 0: Posts, 1: Archived Posts

  @override
  void initState() {
    super.initState();
    TdlibService.instance.syncUserProfile();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TgAccount>(
      valueListenable: AccountManager.instance.currentAccount,
      builder: (context, acc, _) {
        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          children: [
            ProfileAvatarSection(account: acc),
            const SizedBox(height: 16),
            const ProfileActionButtons(),
            const SizedBox(height: 16),
            ProfileInfoCard(account: acc),
            const SizedBox(height: 16),
            ProfileAccountsSection(currentAccount: acc),
            const SizedBox(height: 16),
            ProfilePostsTabs(
              activeTab: _activeTab,
              onTabChanged: (tab) => setState(() => _activeTab = tab),
            ),
            const SizedBox(height: 14),
            ProfilePostsSection(activeTab: _activeTab),
          ],
        );
      },
    );
  }
}
