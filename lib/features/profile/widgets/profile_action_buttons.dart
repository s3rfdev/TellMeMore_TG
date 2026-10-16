import 'package:flutter/material.dart';

import '../../../core/localization/app_locale.dart';
import '../../../core/theme/tg_theme.dart';
import '../../../core/widgets/tg_toast.dart';
import '../../../state/app_state.dart';
import '../edit_account_dialog.dart';

/// Горизонтальный ряд кнопок быстрых действий профиля (установить фото, редактировать, открыть настройки).
class ProfileActionButtons extends StatelessWidget {
  const ProfileActionButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _actionButton(
            icon: Icons.add_a_photo_outlined,
            label: tr('set_photo'),
            onTap: () => TgToast.show(context, '📸 ${tr('set_photo')}'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _actionButton(
            icon: Icons.edit_note_rounded,
            label: tr('edit_info'),
            onTap: () => EditAccountDialog.show(context),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _actionButton(
            icon: Icons.settings_outlined,
            label: tr('settings_title'),
            onTap: () {
              Navigator.of(context).pop();
              AppState.activeSidebarTab.value = SidebarTab.settings;
            },
          ),
        ),
      ],
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF232E3C),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Tg.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
