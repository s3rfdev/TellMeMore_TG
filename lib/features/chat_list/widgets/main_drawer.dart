import 'package:flutter/material.dart';

import '../../../core/localization/app_locale.dart';
import '../../../core/theme/tg_theme.dart';
import '../../../core/widgets/tg_avatar.dart';
import '../../../core/widgets/tg_toast.dart';
import '../../../data/models/tg_account.dart';
import '../../../data/models/tg_chat.dart';
import '../../../data/tdlib/tdlib_service.dart';
import '../../../state/app_state.dart';
import '../../auth/add_account_dialog.dart';
import '../../profile/profile_dialog.dart';
import '../../settings/settings_dialog.dart';

/// Главное меню Telegram Desktop (выдвигается по кнопке ≡).
class MainDrawer extends StatefulWidget {
  const MainDrawer({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  State<MainDrawer> createState() => _MainDrawerState();
}

class _MainDrawerState extends State<MainDrawer> {
  bool _accountsExpanded = false;

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
                        isPrimary ? tr('log_out_confirm_title') : tr('delete_account_confirm_title'),
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: Tg.fontMedium,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  (isPrimary ? tr('log_out_confirm_msg') : tr('delete_account_confirm_msg'))
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
                        widget.onClose();
                        if (isPrimary) {
                          TdlibService.instance.logOut();
                          TgToast.show(context, tr('session_logged_out'));
                        } else {
                          AccountManager.instance.removeAccount(currentAcc.id);
                          TgToast.show(context, tr('account_deleted'));
                        }
                      },
                      child: Text(isPrimary ? tr('log_out') : tr('delete_account')),
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

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: I18n.instance.currentLanguage,
      builder: (context, lang, child) {
        return Container(
          width: 290,
          height: double.infinity,
          color: Tg.sidebar,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _userHeader(context),
              const Divider(height: 1, color: Tg.hairline),
              Expanded(
                child: _accountsExpanded ? _buildAccountsList(context) : _buildMainMenu(context),
              ),
              const Divider(height: 1, color: Tg.hairline),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text(
                  'TellMeMore TG 1.0.0 (TDLib)',
                  style: TextStyle(
                    fontSize: 12,
                    color: Tg.textFaint.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _userHeader(BuildContext context) {
    return ValueListenableBuilder<TgAccount>(
      valueListenable: AccountManager.instance.currentAccount,
      builder: (context, acc, _) {
        return InkWell(
          onTap: () {
            setState(() {
              _accountsExpanded = !_accountsExpanded;
            });
          },
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            color: Tg.sidebar,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Stack(
                      children: [
                        TgAvatar(
                          emoji: acc.avatarEmoji,
                          color: acc.avatarColor,
                          imagePath: acc.avatarPath,
                          size: 48,
                          fontSize: 20,
                        ),
                        if (acc.isOnline)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: const Color(0xFF4BD964),
                                shape: BoxShape.circle,
                                border: Border.all(color: Tg.sidebar, width: 2),
                              ),
                            ),
                          ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20, color: Tg.textDim),
                      onPressed: widget.onClose,
                      splashRadius: 18,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            acc.name,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: Tg.fontMedium,
                              color: Tg.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            acc.phone,
                            style: const TextStyle(fontSize: 13, color: Tg.textDim),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: AnimatedRotation(
                        duration: const Duration(milliseconds: 200),
                        turns: _accountsExpanded ? 0.5 : 0.0,
                        child: const Icon(Icons.keyboard_arrow_down_rounded, color: Tg.textDim),
                      ),
                      onPressed: () {
                        setState(() {
                          _accountsExpanded = !_accountsExpanded;
                        });
                      },
                      splashRadius: 18,
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

  Widget _buildAccountsList(BuildContext context) {
    final current = AccountManager.instance.currentAccount.value;
    final all = AccountManager.instance.accounts.value;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 6),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            tr('accounts'),
            style: const TextStyle(fontSize: 12, fontWeight: Tg.fontMedium, color: Tg.accent),
          ),
        ),
        ...all.map((acc) {
          final isSelected = acc.id == current.id;
          return ListTile(
            dense: true,
            leading: TgAvatar(
              emoji: acc.avatarEmoji,
              color: acc.avatarColor,
              imagePath: acc.avatarPath,
              size: 34,
              fontSize: 14,
            ),
            title: Text(
              acc.name,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: isSelected ? Tg.fontMedium : Tg.fontRegular,
                color: isSelected ? Tg.accent : Tg.text,
              ),
            ),
            subtitle: Text(
              acc.phone,
              style: Tg.caption,
            ),
            trailing: isSelected
                ? const Icon(Icons.check_rounded, color: Tg.accent, size: 18)
                : (acc.unreadBadge > 0
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Tg.accentDark,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${acc.unreadBadge}',
                          style: const TextStyle(fontSize: 11, fontWeight: Tg.fontMedium, color: Colors.white),
                        ),
                      )
                    : null),
            onTap: () {
              AccountManager.instance.switchAccount(acc.id);
              TgToast.show(context, tr('active_account_toast', {'name': acc.name}));
              setState(() {
                _accountsExpanded = false;
              });
            },
          );
        }),
        const Divider(height: 12, color: Tg.hairline),
        _menuItem(
          icon: Icons.add_rounded,
          title: tr('add_account'),
          iconColor: Tg.accent,
          textColor: Tg.accent,
          onTap: () {
            widget.onClose();
            AddAccountDialog.show(context);
          },
        ),
        _menuItem(
          icon: Icons.logout_rounded,
          title: tr('log_out'),
          iconColor: Colors.redAccent,
          textColor: Colors.redAccent,
          onTap: () {
            _showLogOutConfirm(context, current);
          },
        ),
      ],
    );
  }

  Widget _buildMainMenu(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 6),
      children: [
        _menuItem(
          icon: Icons.account_circle_outlined,
          title: tr('profile'),
          onTap: () {
            widget.onClose();
            ProfileDialog.show(context);
          },
        ),
        _menuItem(
          icon: Icons.group_outlined,
          title: I18n.instance.isRu ? 'Создать группу' : 'New Group',
          onTap: () {
            widget.onClose();
            _showNewChatDialog(context, isGroup: true);
          },
        ),
        _menuItem(
          icon: Icons.campaign_outlined,
          title: I18n.instance.isRu ? 'Создать канал' : 'New Channel',
          onTap: () {
            widget.onClose();
            _showNewChatDialog(context, isGroup: false);
          },
        ),
        _menuItem(
          icon: Icons.person_outline_rounded,
          title: tr('contacts'),
          onTap: () {
            widget.onClose();
            _showContactsDialog(context);
          },
        ),
        _menuItem(
          icon: Icons.phone_outlined,
          title: tr('calls'),
          onTap: () {
            widget.onClose();
            TgToast.show(
              context,
              I18n.instance.isRu ? 'Журнал звонков пуст' : 'Call log is empty',
              icon: Icons.phone_disabled_rounded,
            );
          },
        ),
        _menuItem(
          icon: Icons.bookmark_border_rounded,
          title: I18n.instance.isRu ? 'Избранное' : 'Saved Messages',
          onTap: () {
            widget.onClose();
            final user = TdlibService.instance.currentUser.value;
            if (user != null) {
              AppState.selectedChatId.value = user.id.toString();
            }
          },
        ),
        _menuItem(
          icon: Icons.settings_outlined,
          title: tr('settings_title'),
          onTap: () {
            widget.onClose();
            SettingsDialog.show(context);
          },
        ),
        const Divider(height: 12, color: Tg.hairline),
        _menuItem(
          icon: Icons.add_rounded,
          title: tr('add_account'),
          iconColor: Tg.accent,
          textColor: Tg.accent,
          onTap: () {
            widget.onClose();
            AddAccountDialog.show(context);
          },
        ),
        _nightModeRow(),
      ],
    );
  }

  Widget _menuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconColor,
    Color? textColor,
  }) {
    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(vertical: -2),
      leading: Icon(icon, color: iconColor ?? Tg.textDim, size: 20),
      title: Text(
        title,
        style: TextStyle(fontSize: 13.5, fontWeight: Tg.fontRegular, color: textColor ?? Tg.text),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      hoverColor: Colors.white.withValues(alpha: 0.05),
    );
  }

  Widget _nightModeRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.nightlight_round, color: Tg.textDim, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              I18n.instance.isRu ? 'Ночной режим' : 'Night Mode',
              style: const TextStyle(fontSize: 13.5, color: Tg.text),
            ),
          ),
          Switch(
            value: true,
            activeThumbColor: Tg.accent,
            activeTrackColor: Tg.accentDark.withValues(alpha: 0.5),
            onChanged: (val) {},
          ),
        ],
      ),
    );
  }

  void _showNewChatDialog(BuildContext context, {required bool isGroup}) {
    final titleController = TextEditingController();
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        backgroundColor: Tg.sidebar,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Tg.border, width: 1),
        ),
        child: Container(
          width: 360,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isGroup
                    ? (I18n.instance.isRu ? 'Создать группу' : 'New Group')
                    : (I18n.instance.isRu ? 'Создать канал' : 'New Channel'),
                style: Tg.title,
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Tg.accentDark,
                      shape: BoxShape.circle,
                      border: Border.all(color: Tg.border),
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Tg.field,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Tg.border),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: TextField(
                        controller: titleController,
                        autofocus: true,
                        style: const TextStyle(color: Colors.white, fontSize: 13.5),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: isGroup
                              ? (I18n.instance.isRu ? 'Название группы' : 'Group Name')
                              : (I18n.instance.isRu ? 'Название канала' : 'Channel Name'),
                          hintStyle: const TextStyle(color: Tg.textFaint, fontSize: 13),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                isGroup ? tr('new_group_hint') : tr('new_channel_hint'),
                style: Tg.caption,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: TextButton.styleFrom(
                      foregroundColor: Tg.textDim,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    child: Text(tr('cancel'), style: const TextStyle(fontSize: 13)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      final title = titleController.text.trim();
                      if (title.isNotEmpty) {
                        TdlibService.instance.createGroup(title);
                        Navigator.pop(ctx);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Tg.accentDark,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(color: Tg.border),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: Text(
                      I18n.instance.isRu ? 'Создать' : 'Create',
                      style: const TextStyle(fontSize: 13, fontWeight: Tg.fontMedium),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showContactsDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        backgroundColor: Tg.sidebar,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Tg.border, width: 1),
        ),
        child: Container(
          width: 360,
          height: 420,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    tr('contacts'),
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: Tg.fontMedium,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: Tg.textDim),
                    onPressed: () => Navigator.pop(ctx),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ValueListenableBuilder<List<TgChat>>(
                  valueListenable: TdlibService.instance.chats,
                  builder: (context, chats, _) {
                    if (chats.isEmpty) {
                      return Center(
                        child: Text(
                          I18n.instance.isRu ? 'Контакты загружаются…' : 'Loading contacts…',
                          style: const TextStyle(color: Tg.textDim),
                        ),
                      );
                    }
                    return ListView.separated(
                      itemCount: chats.length,
                      separatorBuilder: (ctx, i) => const Divider(height: 1, color: Tg.hairline),
                      itemBuilder: (ctx, i) {
                        final c = chats[i];
                        return ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          leading: TgAvatar(emoji: c.avatarEmoji, color: Color(c.avatarColor), size: 36, fontSize: 15),
                          title: Text(c.title, style: const TextStyle(color: Tg.text, fontSize: 13.5)),
                          subtitle: Text(c.headerSubtitle, style: const TextStyle(color: Tg.textDim, fontSize: 12)),
                          onTap: () {
                            Navigator.pop(ctx);
                            AppState.selectedChatId.value = c.id;
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
