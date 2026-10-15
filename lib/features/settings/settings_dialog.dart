import 'package:flutter/material.dart';

import '../../core/localization/app_locale.dart';
import '../../core/theme/tg_theme.dart';
import '../../core/widgets/tg_avatar.dart';
import '../../core/widgets/tg_toast.dart';
import '../../data/models/tg_account.dart';
import '../../data/tdlib/tdlib_service.dart';
import '../../state/app_state.dart';
import '../auth/add_account_dialog.dart';
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
      child: ValueListenableBuilder<AppLanguage>(
        valueListenable: I18n.instance.currentLanguage,
        builder: (context, lang, child) {
          return ValueListenableBuilder<TgAccount>(
            valueListenable: AccountManager.instance.currentAccount,
            builder: (context, currentAcc, _) {
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
                      _buildHeader(context),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.all(18),
                          children: [
                            _buildProfileCard(context, currentAcc),
                            const SizedBox(height: 14),
                            _buildAccountsCard(context, currentAcc),
                            const SizedBox(height: 14),
                            _buildSettingsOptions(context, currentAcc),
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
          Expanded(
            child: Text(
              tr('settings_title'),
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Tg.text,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search_rounded, color: Tg.textDim, size: 20),
            onPressed: () => TgToast.show(context, tr('search')),
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
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
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
        Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 6),
          child: Text(
            tr('accounts'),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF55A5EB)),
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
                    TgToast.show(context, '${tr('online')}: ${acc.name}');
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
              if (otherAccounts.isNotEmpty)
                Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => AddAccountDialog.show(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  child: Row(
                    children: [
                      const Icon(Icons.add_rounded, color: Color(0xFF55A5EB), size: 22),
                      const SizedBox(width: 14),
                      Text(
                        tr('add_account'),
                        style: const TextStyle(fontSize: 14, color: Color(0xFF55A5EB), fontWeight: FontWeight.w600),
                      ),
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

  Widget _buildSettingsOptions(BuildContext context, TgAccount current) {
    final items = [
      (
        const Color(0xFF2F6FA8),
        Icons.person_outline_rounded,
        tr('account_settings'),
        '${current.phone} • ${current.username}',
        () => EditAccountDialog.show(context),
        Tg.textDim,
      ),
      (
        const Color(0xFFFF9800),
        Icons.chat_bubble_outline_rounded,
        tr('chat_settings'),
        tr('chat_settings_sub'),
        () => TgToast.show(context, tr('chat_settings')),
        Tg.textDim,
      ),
      (
        const Color(0xFF4CAF50),
        Icons.lock_outline_rounded,
        tr('privacy_security'),
        tr('privacy_security_sub'),
        () => TgToast.show(context, tr('privacy_security')),
        Tg.textDim,
      ),
      (
        const Color(0xFFE53935),
        Icons.notifications_none_rounded,
        tr('notifications_sounds'),
        tr('notifications_sounds_sub'),
        () => NotificationsSettingsDialog.show(context),
        Tg.textDim,
      ),
      (
        Tg.accent,
        Icons.auto_awesome_rounded,
        tr('ai_copilot_settings'),
        tr('ai_copilot_sub'),
        () {
          Navigator.of(context).pop();
          AppState.activeSidebarTab.value = SidebarTab.settings;
        },
        Tg.textDim,
      ),
      (
        const Color(0xFF1E88E5),
        Icons.pie_chart_outline_rounded,
        tr('data_storage'),
        tr('data_storage_sub'),
        () => TgToast.show(context, tr('data_storage')),
        Tg.textDim,
      ),
      (
        const Color(0xFF00ACC1),
        Icons.folder_open_rounded,
        tr('chat_folders'),
        tr('chat_folders_sub'),
        () => TgToast.show(context, tr('chat_folders')),
        Tg.textDim,
      ),
      (
        const Color(0xFF00897B),
        Icons.laptop_mac_rounded,
        tr('devices'),
        tr('devices_sub'),
        () => TgToast.show(context, tr('devices')),
        Tg.textDim,
      ),
      (
        const Color(0xFF7E57C2),
        Icons.language_rounded,
        tr('language'),
        I18n.instance.isRu ? 'Русский' : 'English',
        () => _showLanguageDialog(context),
        Tg.textDim,
      ),
      (
        Colors.redAccent,
        Icons.logout_rounded,
        tr('log_out'),
        current.name,
        () => _showLogOutConfirm(context, current),
        Colors.redAccent.withValues(alpha: 0.8),
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
          final isLogOut = it.$2 == Icons.logout_rounded;
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
                        Text(
                          it.$3,
                          style: TextStyle(
                            fontSize: 14.5,
                            color: isLogOut ? Colors.redAccent : Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          it.$4,
                          style: TextStyle(fontSize: 11.5, color: it.$6),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: isLogOut ? Colors.redAccent.withValues(alpha: 0.5) : Tg.textFaint,
                    size: 18,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 320,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Tg.sidebar,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      tr('language'),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20, color: Tg.textDim),
                      onPressed: () => Navigator.of(ctx).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _langOption(
                  ctx,
                  flag: '🇷🇺',
                  name: 'Русский',
                  selected: I18n.instance.isRu,
                  onSelect: () {
                    I18n.instance.setLanguage(AppLanguage.ru);
                    Navigator.of(ctx).pop();
                    TgToast.show(context, tr('lang_changed_toast'));
                  },
                ),
                const SizedBox(height: 8),
                _langOption(
                  ctx,
                  flag: '🇬🇧',
                  name: 'English',
                  selected: !I18n.instance.isRu,
                  onSelect: () {
                    I18n.instance.setLanguage(AppLanguage.en);
                    Navigator.of(ctx).pop();
                    TgToast.show(context, tr('lang_changed_toast'));
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _langOption(
    BuildContext context, {
    required String flag,
    required String name,
    required bool selected,
    required VoidCallback onSelect,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onSelect,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2F6FA8).withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? const Color(0xFF55A5EB) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: Colors.white,
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check_rounded, color: Color(0xFF55A5EB), size: 20),
          ],
        ),
      ),
    );
  }

  void _showLogOutConfirm(BuildContext context, TgAccount currentAcc) {
    final isPrimary = currentAcc.id == 'sergei';
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 380,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Tg.sidebar,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        tr('log_out_confirm_title'),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  tr('log_out_confirm_msg')
                      .replaceAll('{name}', currentAcc.name)
                      .replaceAll('{phone}', currentAcc.phone),
                  style: const TextStyle(fontSize: 13.5, color: Tg.textDim, height: 1.4),
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: Text(
                        tr('cancel'),
                        style: const TextStyle(color: Tg.textDim, fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        Navigator.of(context).pop();
                        if (isPrimary) {
                          TdlibService.instance.logOut();
                          TgToast.show(context, tr('session_ended_toast'));
                        } else {
                          AccountManager.instance.removeAccount(currentAcc.id);
                          TgToast.show(context, tr('account_deleted_toast'));
                        }
                      },
                      child: Text(tr('log_out')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
