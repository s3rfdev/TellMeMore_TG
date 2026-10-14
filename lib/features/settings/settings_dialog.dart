import 'package:flutter/material.dart';

import '../../core/theme/tg_theme.dart';
import '../../core/widgets/tg_avatar.dart';
import '../../core/widgets/tg_toast.dart';
import '../../data/models/tg_account.dart';
import '../../state/app_state.dart';
import '../profile/edit_account_dialog.dart';
import '../profile/profile_dialog.dart';
import 'notifications_settings_dialog.dart';

class SettingsDialog extends StatelessWidget {
  const SettingsDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (_) => const SettingsDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ValueListenableBuilder<TgAccount>(
        valueListenable: AccountManager.instance.currentAccount,
        builder: (context, currentAcc, _) {
          return Container(
            width: 440,
            constraints: const BoxConstraints(maxHeight: 740),
            decoration: BoxDecoration(
              color: Tg.sidebar,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Column(
                children: [
                  _buildHeader(context),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(18),
                      children: [
                        _buildProfileCard(context, currentAcc),
                        const SizedBox(height: 14),
                        _buildAccountsCard(context, currentAcc),
                        const SizedBox(height: 14),
                        _buildSettingsOptions(context),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Tg.sidebar,
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Tg.textDim, size: 22),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Settings',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Tg.text,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search_rounded, color: Tg.textDim, size: 20),
            onPressed: () => TgToast.show(context, 'Поиск по настройкам'),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Tg.textDim, size: 22),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, TgAccount acc) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        ProfileDialog.show(context);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1F2B38),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                TgAvatar(
                  emoji: acc.avatarEmoji,
                  color: acc.avatarColor,
                  imagePath: acc.avatarPath,
                  size: 64,
                  fontSize: 26,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: Color(0xFF2F6FA8),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt_rounded, size: 12, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    acc.name,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${acc.phone} • ${acc.username}',
                    style: const TextStyle(fontSize: 12.5, color: Tg.textDim),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Tg.textDim),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountsCard(BuildContext context, TgAccount current) {
    final all = AccountManager.instance.accounts.value;
    final otherAccounts = all.where((a) => a.id != current.id).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 6, bottom: 6),
          child: Text(
            'Accounts',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF55A5EB)),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1F2B38),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            children: [
              ...otherAccounts.map((acc) {
                return InkWell(
                  onTap: () {
                    AccountManager.instance.switchAccount(acc.id);
                    TgToast.show(context, 'Активный аккаунт: ${acc.name}');
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        TgAvatar(
                          emoji: acc.avatarEmoji,
                          color: acc.avatarColor,
                          imagePath: acc.avatarPath,
                          size: 36,
                          fontSize: 15,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            acc.name,
                            style: const TextStyle(fontSize: 14.5, color: Colors.white, fontWeight: FontWeight.w500),
                          ),
                        ),
                        if (acc.unreadBadge > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2F6FA8),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${acc.unreadBadge}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                            ),
                          ),
                        const SizedBox(width: 8),
                        const Icon(Icons.chevron_right_rounded, color: Tg.textFaint, size: 18),
                      ],
                    ),
                  ),
                );
              }),
              Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
              InkWell(
                onTap: () => TgToast.show(context, 'Добавление нового аккаунта'),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  child: Row(
                    children: [
                      Icon(Icons.add_rounded, color: Color(0xFF55A5EB), size: 22),
                      SizedBox(width: 14),
                      Text('Add Account', style: TextStyle(fontSize: 14, color: Color(0xFF55A5EB), fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsOptions(BuildContext context) {
    final items = [
      (
        const Color(0xFF2F6FA8),
        Icons.person_outline_rounded,
        'Account',
        'Number, Username, Bio',
        () => EditAccountDialog.show(context),
      ),
      (
        const Color(0xFFFF9800),
        Icons.chat_bubble_outline_rounded,
        'Chat Settings',
        'Wallpaper, Night Mode, Animations',
        () => TgToast.show(context, 'Настройки чата'),
      ),
      (
        const Color(0xFF4CAF50),
        Icons.lock_outline_rounded,
        'Privacy & Security',
        'Last Seen, Devices, Passkeys',
        () => TgToast.show(context, 'Конфиденциальность'),
      ),
      (
        const Color(0xFFE53935),
        Icons.notifications_none_rounded,
        'Notifications',
        'Sounds, Calls, Badges',
        () => NotificationsSettingsDialog.show(context),
      ),
      (
        const Color(0xFF8774E1),
        Icons.auto_awesome_rounded,
        'AI Copilot & Auto-Pilot',
        'Z-AI, Gemini, Автоответчик',
        () {
          Navigator.of(context).pop();
          AppState.activeSidebarTab.value = SidebarTab.settings;
        },
      ),
      (
        const Color(0xFF1E88E5),
        Icons.pie_chart_outline_rounded,
        'Data and Storage',
        'Media download settings',
        () => TgToast.show(context, 'Данные и память'),
      ),
      (
        const Color(0xFF00ACC1),
        Icons.folder_open_rounded,
        'Chat Folders',
        'Sort chats into folders',
        () => TgToast.show(context, 'Папки с чатами'),
      ),
      (
        const Color(0xFF00897B),
        Icons.laptop_mac_rounded,
        'Devices',
        'Manage connected devices',
        () => TgToast.show(context, 'Устройства'),
      ),
      (
        const Color(0xFF7E57C2),
        Icons.language_rounded,
        'Language',
        'English / Русский',
        () => TgToast.show(context, 'Выбор языка'),
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1F2B38),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: items.map((it) {
          return InkWell(
            onTap: it.$5,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: it.$1,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(it.$2, size: 18, color: Colors.white),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(it.$3, style: const TextStyle(fontSize: 14.5, color: Colors.white, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 2),
                        Text(it.$4, style: const TextStyle(fontSize: 11.5, color: Tg.textDim)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Tg.textFaint, size: 18),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
