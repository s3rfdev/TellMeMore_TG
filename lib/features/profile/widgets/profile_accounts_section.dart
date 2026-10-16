import 'package:flutter/material.dart';

import '../../../core/localization/app_locale.dart';
import '../../../core/theme/tg_theme.dart';
import '../../../core/widgets/tg_avatar.dart';
import '../../../core/widgets/tg_toast.dart';
import '../../../data/models/tg_account.dart';
import '../../../data/tdlib/tdlib_service.dart';
import '../../auth/add_account_dialog.dart';

/// Раздел управления несколькими аккаунтами внутри экрана настроек профиля.
class ProfileAccountsSection extends StatelessWidget {
  const ProfileAccountsSection({
    super.key,
    required this.currentAccount,
  });

  final TgAccount currentAccount;

  void _showLogOutConfirm(BuildContext context, TgAccount acc) {
    final isPrimary = acc.id == 'sergei';
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
                      .replaceAll('{name}', acc.name)
                      .replaceAll('{phone}', acc.phone),
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
                        if (isPrimary) {
                          TdlibService.instance.logOut();
                          TgToast.show(context, tr('session_logged_out'));
                        } else {
                          AccountManager.instance.removeAccount(acc.id);
                          TgToast.show(context, tr('account_deleted_toast'));
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
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1F2B38),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.switch_account_rounded, size: 20, color: Tg.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tr('accounts'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: Tg.fontMedium,
                    color: Tg.text,
                  ),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => AddAccountDialog.show(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Tg.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Tg.accent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_rounded, size: 16, color: Tg.accent),
                      const SizedBox(width: 4),
                      Text(
                        tr('add_account'),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: Tg.fontMedium,
                          color: Tg.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
          const SizedBox(height: 8),
          ValueListenableBuilder<List<TgAccount>>(
            valueListenable: AccountManager.instance.accounts,
            builder: (context, accounts, _) {
              return Column(
                children: accounts.map((acc) {
                  final isSelected = acc.id == currentAccount.id;
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? Tg.accent.withValues(alpha: 0.08) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? Tg.accent.withValues(alpha: 0.3) : Colors.transparent,
                      ),
                    ),
                    child: ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      leading: Stack(
                        children: [
                          TgAvatar(
                            emoji: acc.avatarEmoji,
                            color: acc.avatarColor,
                            imagePath: acc.avatarPath,
                            size: 38,
                            fontSize: 15,
                          ),
                          if (acc.isOnline)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4BD964),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFF1F2B38), width: 1.5),
                                ),
                              ),
                            ),
                        ],
                      ),
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(
                              acc.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: isSelected ? Tg.fontMedium : Tg.fontRegular,
                                color: isSelected ? Tg.accent : Tg.text,
                              ),
                            ),
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Tg.accent.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                I18n.instance.isRu ? 'Активен' : 'Active',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: Tg.fontMedium,
                                  color: Tg.accent,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text(
                        acc.phone.isNotEmpty ? acc.phone : (acc.username.isNotEmpty ? acc.username : '—'),
                        style: Tg.caption,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (acc.unreadBadge > 0)
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Tg.accentDark,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${acc.unreadBadge}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: Tg.fontMedium,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          IconButton(
                            icon: Icon(
                              isSelected ? Icons.logout_rounded : Icons.delete_outline_rounded,
                              size: 18,
                              color: isSelected ? Colors.redAccent.withValues(alpha: 0.7) : Tg.textDim,
                            ),
                            tooltip: isSelected ? tr('log_out') : tr('delete_account'),
                            splashRadius: 16,
                            onPressed: () => _showLogOutConfirm(context, acc),
                          ),
                        ],
                      ),
                      onTap: isSelected
                          ? null
                          : () {
                              AccountManager.instance.switchAccount(acc.id);
                              TgToast.show(context, tr('active_account_toast', {'name': acc.name}));
                            },
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
