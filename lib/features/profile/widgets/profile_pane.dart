import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/localization/app_locale.dart';
import '../../../core/theme/tg_theme.dart';
import '../../../core/widgets/tg_avatar.dart';
import '../../../core/widgets/tg_toast.dart';
import '../../../data/models/tg_account.dart';
import '../../../data/tdlib/tdlib_service.dart';
import '../../chat/widgets/video_viewer_dialog.dart';
import '../edit_account_dialog.dart';

/// Полноразмерная панель профиля для раздела настроек "Профиль и аккаунт".
class ProfilePane extends StatefulWidget {
  const ProfilePane({super.key});

  @override
  State<ProfilePane> createState() => _ProfilePaneState();
}

class _ProfilePaneState extends State<ProfilePane> {
  int _activeTab = 0; // 0: Posts, 1: Archived Posts

  @override
  void initState() {
    super.initState();
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
    return ValueListenableBuilder<TgAccount>(
      valueListenable: AccountManager.instance.currentAccount,
      builder: (context, acc, _) {
        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          children: [
            _buildAvatarSection(acc),
            const SizedBox(height: 16),
            _buildActionButtons(context),
            const SizedBox(height: 16),
            _buildInfoCard(acc),
            const SizedBox(height: 16),
            _buildPostsTabs(),
            const SizedBox(height: 14),
            _buildPostsSection(),
          ],
        );
      },
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
                size: 84,
                fontSize: 32,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () => TgToast.show(context, '📸 ${tr('set_photo')}'),
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: const BoxDecoration(
                      color: Tg.accentDark,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt_rounded, size: 15, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            acc.name.isNotEmpty ? acc.name : tr('user_default'),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: Tg.fontMedium,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            acc.isOnline ? tr('online') : tr('last_seen_recently'),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: Tg.fontRegular,
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
            icon: Icons.sync_rounded,
            label: tr('sync_with_telegram'),
            onTap: () {
              TdlibService.instance.syncUserProfile();
              TgToast.show(context, tr('syncing_profile'));
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
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Tg.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Tg.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: Tg.accent, size: 18),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: Tg.fontMedium,
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
        color: Tg.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Tg.border),
      ),
      child: Column(
        children: [
          _infoRow(
            title: acc.phone.isNotEmpty ? acc.phone : '—',
            subtitle: tr('phone'),
            onTap: () => TgToast.show(context, tr('phone_copied')),
          ),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.05)),
          _infoRow(
            title: acc.bio.isNotEmpty ? acc.bio : tr('no_bio'),
            subtitle: tr('bio'),
            isPlaceholder: acc.bio.isEmpty,
            onTap: () => EditAccountDialog.show(context),
          ),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.05)),
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
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: Tg.fontMedium,
                      color: isPlaceholder ? Tg.textDim : Colors.white,
                      fontStyle: isPlaceholder ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11.5, color: Tg.textDim, fontWeight: Tg.fontRegular),
                  ),
                ],
              ),
            ),
            const Icon(Icons.content_copy_rounded, size: 15, color: Tg.textFaint),
          ],
        ),
      ),
    );
  }

  Widget _buildPostsTabs() {
    return Container(
      height: 36,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Tg.field,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeTab = 0),
              child: Container(
                decoration: BoxDecoration(
                  color: _activeTab == 0 ? Tg.accentDark : Colors.transparent,
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
                  color: _activeTab == 1 ? Tg.accentDark : Colors.transparent,
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
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Column(
                    children: [
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Tg.accent),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        tr('syncing_posts'),
                        style: const TextStyle(fontSize: 12.5, color: Tg.textDim),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 550 ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.85,
          ),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            return _buildPostCard(post);
          },
        );
      },
    );
  }

  Widget _buildPostCard(TgPost post) {
    final hasMedia = post.mediaPath.isNotEmpty && File(post.mediaPath).existsSync();
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _showPostDetail(context, post),
      child: Container(
        decoration: BoxDecoration(
          color: Tg.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Tg.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (hasMedia)
                    _isVideoFile(post.mediaPath)
                        ? Container(
                            color: Colors.black45,
                            child: const Center(
                              child: Icon(Icons.play_circle_fill_rounded, size: 36, color: Colors.white70),
                            ),
                          )
                        : Image.file(
                            File(post.mediaPath),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _buildPlaceholderMedia(post),
                          )
                  else
                    _buildPlaceholderMedia(post),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.remove_red_eye_outlined, size: 11, color: Colors.white70),
                          const SizedBox(width: 4),
                          Text(
                            '${post.views}',
                            style: const TextStyle(fontSize: 10.5, color: Colors.white, fontWeight: Tg.fontRegular),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.text.isNotEmpty ? post.text : tr('post_attachment'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, color: Colors.white, fontWeight: Tg.fontRegular),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _formatPostDate(post.date),
                    style: const TextStyle(fontSize: 10, color: Tg.textDim),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderMedia(TgPost post) {
    return Container(
      color: Tg.accentDark.withValues(alpha: 0.25),
      child: Center(
        child: Icon(
          post.mediaPath.isNotEmpty ? Icons.image_rounded : Icons.article_rounded,
          size: 32,
          color: Tg.accent,
        ),
      ),
    );
  }

  Widget _buildEmptyPostsState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Tg.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Tg.border),
      ),
      child: Column(
        children: [
          Icon(
            _activeTab == 0 ? Icons.post_add_rounded : Icons.archive_outlined,
            size: 38,
            color: Tg.textDim,
          ),
          const SizedBox(height: 10),
          Text(
            _activeTab == 0 ? tr('no_posts_yet') : tr('no_archived_posts'),
            style: const TextStyle(fontSize: 13, fontWeight: Tg.fontMedium, color: Tg.text),
          ),
          const SizedBox(height: 4),
          Text(
            _activeTab == 0 ? tr('no_posts_hint') : tr('no_archived_posts_hint'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11.5, color: Tg.textDim),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Tg.accentDark,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => _showCreatePostDialog(context),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: Text(tr('create_first_post'), style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  void _showCreatePostDialog(BuildContext context) {
    final textCtrl = TextEditingController();
    String attachedPath = '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: Tg.sidebar,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Tg.border),
          ),
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      tr('create_post_title'),
                      style: const TextStyle(fontSize: 14.5, fontWeight: Tg.fontMedium, color: Colors.white),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18, color: Tg.textDim),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: textCtrl,
                  maxLines: 4,
                  style: const TextStyle(fontSize: 13, color: Tg.text),
                  decoration: InputDecoration(
                    hintText: tr('post_text_hint'),
                    hintStyle: const TextStyle(fontSize: 12.5, color: Tg.textDim),
                    filled: true,
                    fillColor: Tg.field,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Tg.border),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (attachedPath.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Tg.field,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Tg.border),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isVideoFile(attachedPath) ? Icons.videocam_rounded : Icons.image_rounded,
                          size: 18,
                          color: Tg.accent,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            attachedPath.split('/').last,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: Colors.white),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16, color: Tg.textDim),
                          onPressed: () => setDialogState(() => attachedPath = ''),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Tg.accent,
                        side: const BorderSide(color: Tg.border),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.attach_file_rounded, size: 16),
                      label: Text(tr('attach_media'), style: const TextStyle(fontSize: 12)),
                      onPressed: () async {
                        final result = await FilePicker.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'mp4', 'mov', 'avi', 'mkv', 'webm'],
                        );
                        if (result.isNotEmpty && result.first.path != null) {
                          setDialogState(() => attachedPath = result.first.path!);
                        }
                      },
                    ),
                    const Spacer(),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Tg.accentDark,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        final text = textCtrl.text.trim();
                        if (text.isEmpty && attachedPath.isEmpty) {
                          TgToast.show(context, tr('post_empty_error'));
                          return;
                        }
                        final newPost = TgPost(
                          id: 'p_${DateTime.now().millisecondsSinceEpoch}',
                          text: text,
                          date: DateTime.now(),
                          views: 1,
                          mediaPath: attachedPath,
                        );
                        final list = List<TgPost>.from(AccountManager.instance.myPosts.value);
                        list.insert(0, newPost);
                        AccountManager.instance.myPosts.value = list;
                        Navigator.of(ctx).pop();
                        TgToast.show(context, tr('post_published_toast'));
                      },
                      child: Text(tr('publish_btn'), style: const TextStyle(fontSize: 12.5)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPostDetail(BuildContext context, TgPost post) {
    final hasMedia = post.mediaPath.isNotEmpty && File(post.mediaPath).existsSync();
    final isVideo = _isVideoFile(post.mediaPath);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Tg.sidebar,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Tg.border),
        ),
        child: Container(
          width: 440,
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hasMedia)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: isVideo
                        ? GestureDetector(
                            onTap: () => VideoViewerDialog.show(
                              context,
                              videoPath: post.mediaPath,
                              title: post.text,
                            ),
                            child: Container(
                              color: Colors.black,
                              child: const Center(
                                child: Icon(Icons.play_circle_fill_rounded, size: 48, color: Colors.white70),
                              ),
                            ),
                          )
                        : Image.file(File(post.mediaPath), fit: BoxFit.cover),
                  ),
                ),
              if (hasMedia) const SizedBox(height: 12),
              if (post.text.isNotEmpty)
                Text(
                  post.text,
                  style: const TextStyle(fontSize: 13, color: Colors.white, height: 1.4),
                ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${tr('views')}: ${post.views} • ${_formatPostDate(post.date)}',
                    style: const TextStyle(fontSize: 11, color: Tg.textDim),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(tr('close'), style: const TextStyle(fontSize: 12, color: Tg.accent)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
