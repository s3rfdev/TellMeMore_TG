import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/localization/app_locale.dart';
import '../../core/theme/tg_theme.dart';
import '../../core/widgets/tg_avatar.dart';
import '../../core/widgets/tg_toast.dart';
import '../../data/models/tg_account.dart';
import '../../data/tdlib/tdlib_service.dart';
import '../../state/app_state.dart';
import '../chat/widgets/video_viewer_dialog.dart';
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
  void initState() {
    super.initState();
    // Auto-sync real Telegram profile data upon opening dialog
    TdlibService.instance.syncUserProfile();
  }

  bool _isVideoFile(String path) {
    if (path.isEmpty) return false;
    final lower = path.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.avi') ||
        lower.endsWith('.mkv') ||
        lower.endsWith('.webm');
  }

  String _formatPostDate(DateTime date) {
    if (date.year <= 1970) return '';
    final now = DateTime.now();
    final months = I18n.instance.isRu
        ? const ['янв', 'фев', 'мар', 'апр', 'май', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек']
        : const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final mName = (date.month >= 1 && date.month <= 12) ? months[date.month - 1] : '';
    if (date.year == now.year) {
      return '${date.day} $mName';
    }
    return '${date.day} $mName ${date.year}';
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
            builder: (context, acc, _) {
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
                            const SizedBox(height: 18),
                            _buildPostsSection(),
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
            acc.name.isNotEmpty ? acc.name : tr('user_default'),
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            acc.isOnline ? tr('online') : tr('last_seen_recently'),
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
            title: acc.phone.isNotEmpty ? acc.phone : '—',
            subtitle: tr('phone'),
            onTap: () => TgToast.show(context, tr('phone_copied')),
          ),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
          _infoRow(
            title: acc.bio.isNotEmpty ? acc.bio : tr('no_bio'),
            subtitle: tr('bio'),
            isPlaceholder: acc.bio.isEmpty,
            onTap: () => EditAccountDialog.show(context),
          ),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
          _infoRow(
            title: acc.username.isNotEmpty ? acc.username : '—',
            subtitle: tr('username'),
            onTap: () => TgToast.show(context, tr('username_copied')),
          ),
        ],
      ),
    );
  }

  Widget _infoRow({
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
                  tr('posts'),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: _activeTab == 0 ? Tg.fontMedium : Tg.fontRegular,
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
                  tr('archived_posts'),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: _activeTab == 1 ? Tg.fontMedium : Tg.fontRegular,
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

  Widget _buildPostsSection() {
    return ValueListenableBuilder<bool>(
      valueListenable: AccountManager.instance.isSyncingProfile,
      builder: (context, syncing, _) {
        return ValueListenableBuilder<List<TgPost>>(
          valueListenable: _activeTab == 0
              ? AccountManager.instance.myPosts
              : AccountManager.instance.myArchivedPosts,
          builder: (context, posts, _) {
            if (syncing && posts.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 36),
                child: Center(
                  child: Column(
                    children: [
                      const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Tg.accent),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        tr('syncing_posts'),
                        style: const TextStyle(fontSize: 13, color: Tg.textDim),
                      ),
                    ],
                  ),
                ),
              );
            }
            if (posts.isEmpty) {
              return _buildEmptyPostsState();
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _activeTab == 0
                          ? tr('publications_header', {'count': '${posts.length}'})
                          : tr('archive_header', {'count': '${posts.length}'}),
                      style: const TextStyle(fontSize: 12.5, fontWeight: Tg.fontMedium, color: Tg.textDim),
                    ),
                    TextButton.icon(
                      onPressed: () => _showCreatePostDialog(context),
                      icon: const Icon(Icons.add_rounded, size: 16, color: Tg.accent),
                      label: Text(
                        tr('add_post'),
                        style: const TextStyle(fontSize: 12, color: Tg.accent, fontWeight: Tg.fontMedium),
                      ),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildPostsGrid(posts),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPostsGrid(List<TgPost> posts) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.82,
      ),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        return _buildPostCard(post);
      },
    );
  }

  Widget _buildPostCard(TgPost post) {
    final hasMedia = post.mediaPath.isNotEmpty && File(post.mediaPath).existsSync();
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _showPostDetail(context, post),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E2B38),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: hasMedia
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        if (_isVideoFile(post.mediaPath))
                          Container(
                            color: const Color(0xFF141F2B),
                            child: Center(
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.65),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                                ),
                                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                              ),
                            ),
                          )
                        else
                          Image.file(
                            File(post.mediaPath),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => _mediaFallback(post),
                          ),
                        if (_isVideoFile(post.mediaPath))
                          Positioned(
                            top: 6,
                            left: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('VIDEO', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: Colors.white)),
                            ),
                          ),
                        if (post.views > 0)
                          Positioned(
                            bottom: 6,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.visibility_outlined, size: 12, color: Colors.white),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${post.views}',
                                    style: const TextStyle(fontSize: 10.5, color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    )
                  : _mediaFallback(post),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (post.text.isNotEmpty)
                    Text(
                      post.text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Tg.text, fontWeight: FontWeight.w500),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatPostDate(post.date),
                        style: const TextStyle(fontSize: 10.5, color: Tg.textDim),
                      ),
                      if (!hasMedia && post.views > 0)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.visibility_outlined, size: 11, color: Tg.textFaint),
                            const SizedBox(width: 3),
                            Text(
                              '${post.views}',
                              style: const TextStyle(fontSize: 10.5, color: Tg.textFaint),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mediaFallback(TgPost post) {
    return Container(
      color: const Color(0xFF17212B),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            post.mediaPath.isNotEmpty ? Icons.image_rounded : Icons.article_rounded,
            size: 32,
            color: Tg.textFaint,
          ),
          if (post.mediaPath.isNotEmpty && !File(post.mediaPath).existsSync()) ...[
            const SizedBox(height: 6),
            Text(
              tr('loading_photo'),
              style: const TextStyle(fontSize: 11, color: Tg.textDim),
            ),
          ],
        ],
      ),
    );
  }

  void _showPostDetail(BuildContext context, TgPost post) {
    final hasMedia = post.mediaPath.isNotEmpty && File(post.mediaPath).existsSync();
    final isVideo = hasMedia && _isVideoFile(post.mediaPath);
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          child: Container(
            width: 440,
            constraints: const BoxConstraints(maxHeight: 640),
            decoration: BoxDecoration(
              color: Tg.sidebar,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
                    ),
                    child: Row(
                      children: [
                        Text(
                          _formatPostDate(post.date),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                        const Spacer(),
                        if (post.views > 0) ...[
                          const Icon(Icons.visibility_outlined, size: 14, color: Tg.textDim),
                          const SizedBox(width: 4),
                          Text('${post.views}', style: const TextStyle(fontSize: 12, color: Tg.textDim)),
                          const SizedBox(width: 8),
                        ],
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.redAccent),
                          tooltip: tr('delete_post'),
                          onPressed: () {
                            showDialog(
                              context: ctx,
                              builder: (confirmCtx) => AlertDialog(
                                backgroundColor: Tg.sidebar,
                                title: Text(tr('confirm_delete_post'), style: const TextStyle(fontSize: 16, color: Colors.white)),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(confirmCtx).pop(),
                                    child: Text(tr('cancel'), style: const TextStyle(color: Tg.textDim)),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                    onPressed: () {
                                      AccountManager.instance.deletePost(post.id);
                                      Navigator.of(confirmCtx).pop();
                                      Navigator.of(ctx).pop();
                                      TgToast.show(context, tr('post_deleted'));
                                    },
                                    child: Text(tr('delete')),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20, color: Tg.textDim),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (isVideo)
                            GestureDetector(
                              onTap: () {
                                VideoViewerDialog.show(
                                  context,
                                  videoPath: post.mediaPath,
                                  title: post.text,
                                );
                              },
                              child: Container(
                                height: 260,
                                margin: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: Tg.accent.withValues(alpha: 0.9),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                                      ),
                                      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 34),
                                    ),
                                    Positioned(
                                      bottom: 12,
                                      left: 12,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.7),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.videocam_rounded, size: 14, color: Colors.white70),
                                            const SizedBox(width: 6),
                                            Text(
                                              post.mediaPath.split(Platform.pathSeparator).last,
                                              style: const TextStyle(fontSize: 12, color: Colors.white70),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else if (hasMedia)
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 380),
                              child: Image.file(
                                File(post.mediaPath),
                                fit: BoxFit.contain,
                              ),
                            ),
                          if (post.text.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: SelectableText(
                                post.text,
                                style: const TextStyle(fontSize: 14.5, color: Colors.white, height: 1.4),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showCreatePostDialog(BuildContext context) {
    final textController = TextEditingController();
    String? attachedMediaPath;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final isVideo = attachedMediaPath != null && _isVideoFile(attachedMediaPath!);
            final hasAttachment = attachedMediaPath != null && attachedMediaPath!.isNotEmpty;

            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                width: 440,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Tg.sidebar,
                  borderRadius: BorderRadius.circular(18),
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
                          tr('add_post'),
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20, color: Tg.textDim),
                          onPressed: () => Navigator.of(ctx).pop(),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF17212B),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: TextField(
                        controller: textController,
                        maxLines: 4,
                        autofocus: true,
                        style: const TextStyle(fontSize: 14, color: Colors.white),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: tr('post_text_hint'),
                          hintStyle: const TextStyle(color: Tg.textDim),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (hasAttachment) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1F2E3D),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Tg.accent.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            if (isVideo)
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.black38,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(Icons.videocam_rounded, color: Tg.accent, size: 24),
                              )
                            else
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.file(
                                  File(attachedMediaPath!),
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_rounded, color: Tg.accent),
                                ),
                              ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    attachedMediaPath!.split(Platform.pathSeparator).last,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isVideo ? (I18n.instance.isRu ? 'Видеофайл' : 'Video file') : (I18n.instance.isRu ? 'Изображение' : 'Image'),
                                    style: const TextStyle(fontSize: 11, color: Tg.textDim),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18, color: Colors.white70),
                              tooltip: tr('delete'),
                              onPressed: () {
                                setDialogState(() {
                                  attachedMediaPath = null;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Tg.accent,
                            side: BorderSide(color: Tg.accent.withValues(alpha: 0.4)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                          ),
                          icon: const Icon(Icons.perm_media_outlined, size: 18),
                          label: Text(tr('attach_media'), style: const TextStyle(fontSize: 12.5)),
                          onPressed: () async {
                            final result = await FilePicker.pickFiles(
                              type: FileType.custom,
                              allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'mp4', 'mov', 'avi', 'mkv', 'webm'],
                            );
                            if (result.isNotEmpty && result.first.path != null) {
                              setDialogState(() {
                                attachedMediaPath = result.first.path;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: Text(tr('cancel'), style: const TextStyle(color: Tg.textDim)),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2F6FA8),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () {
                            final text = textController.text.trim();
                            if (text.isNotEmpty || (attachedMediaPath != null && attachedMediaPath!.isNotEmpty)) {
                              final newPost = TgPost(
                                id: 'local_${DateTime.now().millisecondsSinceEpoch}',
                                text: text,
                                mediaPath: attachedMediaPath ?? '',
                                date: DateTime.now(),
                                views: 1,
                                isArchived: _activeTab == 1,
                              );
                              AccountManager.instance.addPost(newPost, isArchived: _activeTab == 1);
                              Navigator.of(ctx).pop();
                              TgToast.show(context, tr('post_added'));
                            }
                          },
                          child: Text(tr('publish')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyPostsState() {
    final isArchived = _activeTab == 1;
    return Column(
      children: [
        const SizedBox(height: 14),
        Text(
          isArchived
              ? tr('no_archived_posts')
              : tr('no_posts_yet'),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          isArchived
              ? tr('archive_empty_hint')
              : tr('posts_empty_hint'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: Tg.textDim),
        ),
        const SizedBox(height: 18),
        ElevatedButton.icon(
          onPressed: () => _showCreatePostDialog(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2F6FA8),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          icon: const Icon(Icons.add_a_photo_rounded, size: 18),
          label: Text(tr('add_post')),
        ),
      ],
    );
  }
}
