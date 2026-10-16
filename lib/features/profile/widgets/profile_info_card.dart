import 'package:flutter/material.dart';

import '../../../core/localization/app_locale.dart';
import '../../../core/theme/tg_theme.dart';
import '../../../core/widgets/tg_toast.dart';
import '../../../data/models/tg_account.dart';
import '../edit_account_dialog.dart';

/// Карточка контактной информации профиля (телефон, био, юзернейм).
class ProfileInfoCard extends StatelessWidget {
  const ProfileInfoCard({
    super.key,
    required this.account,
  });

  final TgAccount account;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1F2B38),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          _infoRow(
            context,
            title: account.phone.isNotEmpty ? account.phone : '—',
            subtitle: tr('phone'),
            onTap: () => TgToast.show(context, tr('phone_copied')),
          ),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
          _infoRow(
            context,
            title: account.bio.isNotEmpty ? account.bio : tr('no_bio'),
            subtitle: tr('bio'),
            isPlaceholder: account.bio.isEmpty,
            onTap: () => EditAccountDialog.show(context),
          ),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
          _infoRow(
            context,
            title: account.username.isNotEmpty ? account.username : '—',
            subtitle: tr('username'),
            onTap: () => TgToast.show(context, tr('username_copied')),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(
    BuildContext context, {
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isPlaceholder = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      color: isPlaceholder ? Tg.textDim : Colors.white,
                      fontStyle: isPlaceholder ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: Tg.textDim),
                  ),
                ],
              ),
            ),
            const Icon(Icons.content_copy_rounded, size: 16, color: Tg.textFaint),
          ],
        ),
      ),
    );
  }
}
