import 'package:flutter/material.dart';

import '../../../core/localization/app_locale.dart';
import '../../../core/theme/tg_theme.dart';
import '../../../data/models/tg_account.dart';
import 'profile_create_post_dialog.dart';
import 'profile_post_card.dart';
import 'profile_post_detail_dialog.dart';

/// Секция отображения сетки публикаций профиля или архивных постов.
class ProfilePostsSection extends StatelessWidget {
  const ProfilePostsSection({
    super.key,
    required this.activeTab,
  });

  final int activeTab;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AccountManager.instance.isSyncingProfile,
      builder: (context, syncing, _) {
        return ValueListenableBuilder<List<TgPost>>(
          valueListenable: activeTab == 0
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
              return _buildEmptyPostsState(context);
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      activeTab == 0
                          ? tr('publications_header', {'count': '${posts.length}'})
                          : tr('archive_header', {'count': '${posts.length}'}),
                      style: const TextStyle(fontSize: 12.5, fontWeight: Tg.fontMedium, color: Tg.textDim),
                    ),
                    TextButton.icon(
                      onPressed: () => ProfileCreatePostDialog.show(context, isArchived: activeTab == 1),
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
                GridView.builder(
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
                    return ProfilePostCard(
                      post: post,
                      onTap: () => ProfilePostDetailDialog.show(context, post),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyPostsState(BuildContext context) {
    final isArchived = activeTab == 1;
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
          onPressed: () => ProfileCreatePostDialog.show(context, isArchived: isArchived),
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
