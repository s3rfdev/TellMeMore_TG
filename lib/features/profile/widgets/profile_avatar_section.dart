import 'package:flutter/material.dart';

import '../../../core/localization/app_locale.dart';
import '../../../core/theme/tg_theme.dart';
import '../../../core/widgets/tg_avatar.dart';
import '../../../core/widgets/tg_toast.dart';
import '../../../data/models/tg_account.dart';

/// Секция аватара профиля с индикатором статуса онлайн и кнопкой смены фото.
class ProfileAvatarSection extends StatelessWidget {
  const ProfileAvatarSection({
    super.key,
    required this.account,
  });

  final TgAccount account;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              TgAvatar(
                emoji: account.avatarEmoji,
                color: account.avatarColor,
                imagePath: account.avatarPath,
                size: 96,
                fontSize: 38,
              ),
              Positioned(
                bottom: 2,
                right: 2,
                child: GestureDetector(
                  onTap: () => TgToast.show(context, '📸 ${tr('set_photo')}'),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: Color(0xFF2F6FA8),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            account.name.isNotEmpty ? account.name : tr('user_default'),
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            account.isOnline ? tr('online') : tr('last_seen_recently'),
            style: TextStyle(
              fontSize: 13,
              color: account.isOnline ? const Color(0xFF4BD964) : Tg.textDim,
            ),
          ),
        ],
      ),
    );
  }
}
