import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/localization/app_locale.dart';
import '../../../core/theme/tg_theme.dart';
import '../../../core/widgets/tg_toast.dart';
import '../../../data/models/tg_account.dart';
import 'profile_post_card.dart';

/// Диалог создания новой публикации профиля с прикреплением фото/видео.
class ProfileCreatePostDialog extends StatefulWidget {
  const ProfileCreatePostDialog({
    super.key,
    required this.isArchived,
  });

  final bool isArchived;

  static void show(BuildContext context, {required bool isArchived}) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (ctx) => ProfileCreatePostDialog(isArchived: isArchived),
    );
  }

  @override
  State<ProfileCreatePostDialog> createState() => _ProfileCreatePostDialogState();
}

class _ProfileCreatePostDialogState extends State<ProfileCreatePostDialog> {
  final _textController = TextEditingController();
  String? _attachedMediaPath;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = _attachedMediaPath != null && ProfilePostCard.isVideoFile(_attachedMediaPath!);
    final hasAttachment = _attachedMediaPath != null && _attachedMediaPath!.isNotEmpty;

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
                  onPressed: () => Navigator.of(context).pop(),
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
                controller: _textController,
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
                          File(_attachedMediaPath!),
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
                            _attachedMediaPath!.split(Platform.pathSeparator).last,
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
                        setState(() {
                          _attachedMediaPath = null;
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
                      setState(() {
                        _attachedMediaPath = result.first.path;
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
                  onPressed: () => Navigator.of(context).pop(),
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
                    final text = _textController.text.trim();
                    if (text.isNotEmpty || (_attachedMediaPath != null && _attachedMediaPath!.isNotEmpty)) {
                      final newPost = TgPost(
                        id: 'local_${DateTime.now().millisecondsSinceEpoch}',
                        text: text,
                        mediaPath: _attachedMediaPath ?? '',
                        date: DateTime.now(),
                        views: 1,
                        isArchived: widget.isArchived,
                      );
                      AccountManager.instance.addPost(newPost, isArchived: widget.isArchived);
                      Navigator.of(context).pop();
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
  }
}
