import 'package:flutter/material.dart';

import '../../../core/localization/app_locale.dart';
import '../../../core/theme/tg_theme.dart';
import '../../../core/widgets/tg_toast.dart';
import '../../../data/models/tg_account.dart';
import '../../../data/tdlib/tdlib_service.dart';
import '../edit_account_dialog.dart';

/// Шапка диалога профиля с кнопками синхронизации с Telegram, редактирования и закрытия.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.account,
    this.onClose,
  });

  final TgAccount account;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
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
            onPressed: onClose ?? () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tr('profile'),
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: Tg.fontMedium,
                color: Tg.text,
              ),
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: AccountManager.instance.isSyncingProfile,
            builder: (context, syncing, _) {
              if (syncing) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Tg.accent),
                  ),
                );
              }
              return IconButton(
                icon: const Icon(Icons.sync_rounded, color: Tg.accent, size: 21),
                tooltip: tr('sync_with_telegram'),
                onPressed: () {
                  TdlibService.instance.syncUserProfile();
                  TgToast.show(context, tr('syncing_profile'));
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Tg.accent, size: 20),
            tooltip: tr('edit_info'),
            onPressed: () => EditAccountDialog.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Tg.textDim, size: 22),
            onPressed: onClose ?? () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
