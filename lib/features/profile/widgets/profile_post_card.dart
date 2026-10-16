import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/localization/app_locale.dart';
import '../../../core/theme/tg_theme.dart';
import '../../../data/models/tg_account.dart';

/// Карточка публикации в сетке постов профиля.
class ProfilePostCard extends StatelessWidget {
  const ProfilePostCard({
    super.key,
    required this.post,
    required this.onTap,
  });

  final TgPost post;
  final VoidCallback onTap;

  static bool isVideoFile(String path) {
    if (path.isEmpty) return false;
    final lower = path.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.avi') ||
        lower.endsWith('.mkv') ||
        lower.endsWith('.webm');
  }

  static String formatPostDate(DateTime date) {
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
    final hasMedia = post.mediaPath.isNotEmpty && File(post.mediaPath).existsSync();
    final isVideo = isVideoFile(post.mediaPath);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
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
                        if (isVideo)
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
                        if (isVideo)
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
                        formatPostDate(post.date),
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
}
