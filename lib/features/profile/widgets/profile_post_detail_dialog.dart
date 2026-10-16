import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/localization/app_locale.dart';
import '../../../core/theme/tg_theme.dart';
import '../../../core/widgets/tg_toast.dart';
import '../../../data/models/tg_account.dart';
import '../../chat/widgets/video_viewer_dialog.dart';
import 'profile_post_card.dart';

/// Диалог детального просмотра публикации профиля (медиа, видеоплеер, текст, просмотры и удаление).
class ProfilePostDetailDialog extends StatelessWidget {
  const ProfilePostDetailDialog({
    super.key,
    required this.post,
  });

  final TgPost post;

  static void show(BuildContext context, TgPost post) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (ctx) => ProfilePostDetailDialog(post: post),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasMedia = post.mediaPath.isNotEmpty && File(post.mediaPath).existsSync();
    final isVideo = hasMedia && ProfilePostCard.isVideoFile(post.mediaPath);

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
                      ProfilePostCard.formatPostDate(post.date),
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
                          context: context,
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
                                  Navigator.of(context).pop();
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
                      onPressed: () => Navigator.of(context).pop(),
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
  }
}
