import 'package:flutter/material.dart';

import '../../core/theme/tg_theme.dart';
import '../../core/widgets/tg_avatar.dart';
import '../../core/widgets/tg_toast.dart';
import '../../data/models/tg_account.dart';
import '../../state/app_state.dart';
import 'edit_account_dialog.dart';

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
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ValueListenableBuilder<TgAccount>(
        valueListenable: AccountManager.instance.currentAccount,
        builder: (context, acc, _) {
          return Container(
            width: 440,
            constraints: const BoxConstraints(maxHeight: 720),
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
                  _buildHeader(context, acc),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                      children: [
                        _buildAvatarSection(acc),
                        const SizedBox(height: 18),
                        _buildActionButtons(context),
                        const SizedBox(height: 18),
                        _buildInfoCard(acc),
                        const SizedBox(height: 18),
                        _buildPostsTabs(),
                        const SizedBox(height: 24),
                        _buildEmptyPostsState(),
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

  Widget _buildHeader(BuildContext context, TgAccount acc) {
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
              'Profile',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Tg.text,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Tg.accent, size: 20),
            tooltip: 'Edit Profile',
            onPressed: () => EditAccountDialog.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Tg.textDim, size: 22),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarSection(TgAccount acc) {
    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              TgAvatar(
                emoji: acc.avatarEmoji,
                color: acc.avatarColor,
                imagePath: acc.avatarPath,
                size: 96,
                fontSize: 38,
              ),
              Positioned(
                bottom: 2,
                right: 2,
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
            ],
          ),
          const SizedBox(height: 12),
          Text(
            acc.name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            acc.isOnline ? 'online' : 'last seen recently',
            style: TextStyle(
              fontSize: 13,
              color: acc.isOnline ? const Color(0xFF4BD964) : Tg.textDim,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _actionButton(
            icon: Icons.add_a_photo_outlined,
            label: 'Set Photo',
            onTap: () => TgToast.show(context, '📸 Смена фото профиля'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _actionButton(
            icon: Icons.edit_note_rounded,
            label: 'Edit Info',
            onTap: () => EditAccountDialog.show(context),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _actionButton(
            icon: Icons.settings_outlined,
            label: 'Settings',
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

  Widget _buildInfoCard(TgAccount acc) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1F2B38),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          _infoRow(
            title: acc.phone,
            subtitle: 'Mobile',
            onTap: () => TgToast.show(context, 'Номер скопирован'),
          ),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
          _infoRow(
            title: acc.bio.isNotEmpty ? acc.bio : 'No bio',
            subtitle: 'Bio',
            onTap: () => EditAccountDialog.show(context),
          ),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
          _infoRow(
            title: acc.username,
            subtitle: 'Username',
            onTap: () => TgToast.show(context, 'Юзернейм скопирован'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow({required String title, required String subtitle, required VoidCallback onTap}) {
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
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: Colors.white),
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

  Widget _buildPostsTabs() {
    return Container(
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFF17212B),
        borderRadius: BorderRadius.circular(19),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeTab = 0),
              child: Container(
                decoration: BoxDecoration(
                  color: _activeTab == 0 ? const Color(0xFF2B5278) : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Posts',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: _activeTab == 0 ? FontWeight.w600 : FontWeight.normal,
                    color: _activeTab == 0 ? Colors.white : Tg.textDim,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeTab = 1),
              child: Container(
                decoration: BoxDecoration(
                  color: _activeTab == 1 ? const Color(0xFF2B5278) : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Archived Posts',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: _activeTab == 1 ? FontWeight.w600 : FontWeight.normal,
                    color: _activeTab == 1 ? Colors.white : Tg.textDim,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPostsState() {
    return Column(
      children: [
        const SizedBox(height: 14),
        const Text(
          'No posts yet...',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Publish photos and videos to display on your profile page',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Tg.textDim),
        ),
        const SizedBox(height: 18),
        ElevatedButton.icon(
          onPressed: () => TgToast.show(context, 'Создание нового поста'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2F6FA8),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          icon: const Icon(Icons.add_a_photo_rounded, size: 18),
          label: const Text('Add a post'),
        ),
      ],
    );
  }
}
