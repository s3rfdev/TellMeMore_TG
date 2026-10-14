import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../core/theme/tg_theme.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/widgets/tg_toast.dart';
import '../../../data/models/tg_chat.dart';
import '../../../state/app_state.dart';
import 'forward_dialog.dart';

/// Полноэкранный плеер видеозаписей в стиле Telegram Desktop.
/// Использует media_kit (libmpv) для воспроизведения на Linux.
/// Поддерживает воспроизведение, паузу, перемотку, Esc, сохранение в Загрузки и пересылку.
class VideoViewerDialog extends StatefulWidget {
  const VideoViewerDialog({
    super.key,
    required this.videoPath,
    this.title = 'Видеозапись',
    this.time = '',
    this.message,
    this.chatId = '',
  });

  final String videoPath;
  final String title;
  final String time;
  final TgMessage? message;
  final String chatId;

  static void show(
    BuildContext context, {
    required String videoPath,
    String title = 'Видеозапись',
    String time = '',
    TgMessage? message,
    String chatId = '',
  }) {
    AppLogger.log('[VideoViewerDialog.show] videoPath="$videoPath", title="$title", msgId=${message?.id}');
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.94),
      builder: (_) => VideoViewerDialog(
        videoPath: videoPath,
        title: title,
        time: time,
        message: message,
        chatId: chatId,
      ),
    );
  }

  @override
  State<VideoViewerDialog> createState() => _VideoViewerDialogState();
}

class _VideoViewerDialogState extends State<VideoViewerDialog> {
  Player? _player;
  VideoController? _controller;
  bool _canPlay = false;

  @override
  void initState() {
    super.initState();
    AppLogger.log('[VideoViewerDialog] initState: videoPath="${widget.videoPath}"');
    final file = File(widget.videoPath);
    final exists = file.existsSync();
    final size = exists ? file.lengthSync() : -1;
    AppLogger.log('[VideoViewerDialog] File check: exists=$exists, size=$size bytes');

    if (widget.videoPath.isNotEmpty && exists && size > 100) {
      try {
        AppLogger.log('[VideoViewerDialog] Creating Player()...');
        _player = Player();
        AppLogger.log('[VideoViewerDialog] Creating VideoController...');
        _controller = VideoController(
          _player!,
          configuration: const VideoControllerConfiguration(
            enableHardwareAcceleration: false, // Безопасный рендеринг без OpenGL сбоев
          ),
        );
        AppLogger.log('[VideoViewerDialog] VideoController created. Opening Media...');
        _player!.open(Media(widget.videoPath));
        _canPlay = true;
        AppLogger.log('[VideoViewerDialog] Media opened successfully, _canPlay=true');
      } catch (e, stack) {
        _canPlay = false;
        AppLogger.error('[VideoViewerDialog] Error initializing player: $e', e, stack);
      }
    } else {
      AppLogger.log('[VideoViewerDialog] Video file invalid or size <= 100 bytes.');
    }
  }

  @override
  void dispose() {
    AppLogger.log('[VideoViewerDialog] dispose called');
    if (_player != null) {
      try {
        _player!.stop();
      } catch (e) {
        AppLogger.error('[VideoViewerDialog] Error stopping player in dispose', e);
      }
      try {
        _player!.dispose();
      } catch (e) {
        AppLogger.error('[VideoViewerDialog] Error disposing player in dispose', e);
      }
    }
    super.dispose();
  }

  Future<void> _saveToDownloads() async {
    try {
      final file = File(widget.videoPath);
      if (!await file.exists()) {
        if (mounted) {
          TgToast.show(
            context,
            'Файл видеозаписи не найден',
            icon: Icons.error_outline_rounded,
          );
        }
        return;
      }
      final home = Platform.environment['HOME'] ?? '';
      final downloadsDir = Directory('$home/Downloads');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }
      final ext = widget.videoPath.contains('.') ? widget.videoPath.split('.').last : 'mp4';
      final base = widget.title.isNotEmpty && widget.title != 'Видеозапись'
          ? widget.title
          : 'tg_video_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final destPath = '${downloadsDir.path}/$base';
      await file.copy(destPath);
      if (mounted) {
        TgToast.show(
          context,
          '✓ Видео сохранено в Загрузки',
          icon: Icons.check_circle_rounded,
        );
      }
    } catch (e) {
      if (mounted) {
        TgToast.show(
          context,
          'Ошибка сохранения: $e',
          icon: Icons.error_outline_rounded,
        );
      }
    }
  }

  void _onReply() {
    if (widget.message != null) {
      AppState.replyingTo.value = widget.message;
      Navigator.of(context).pop();
    }
  }

  void _showForward() {
    if (widget.message != null) {
      ForwardDialog.show(
        context,
        message: widget.message!,
        currentChatId: widget.chatId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      onKeyEvent: (event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.of(context).pop();
        }
      },
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // Центр: видеоплеер media_kit
            Positioned.fill(
              child: Center(
                child: _canPlay && _controller != null
                    ? Video(
                        controller: _controller!,
                        controls: MaterialDesktopVideoControls,
                      )
                    : const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.videocam_off_rounded, size: 54, color: Tg.textDim),
                          SizedBox(height: 14),
                          Text(
                            'Файл видеозаписи ещё загружается или повреждён',
                            style: TextStyle(color: Colors.white70, fontSize: 14.5),
                          ),
                        ],
                      ),
              ),
            ),

            // Верхняя плашка управления
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.85),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                      tooltip: 'Назад (Esc)',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (widget.time.isNotEmpty)
                          Text(
                            widget.time,
                            style: const TextStyle(color: Tg.textDim, fontSize: 11.5),
                          ),
                      ],
                    ),
                    const Spacer(),
                    if (widget.message != null) ...[
                      TextButton.icon(
                        icon: const Icon(Icons.reply_rounded, color: Colors.white, size: 18),
                        label: const Text('Ответить', style: TextStyle(color: Colors.white, fontSize: 13)),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.12),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _onReply,
                      ),
                      const SizedBox(width: 10),
                    ],
                    TextButton.icon(
                      icon: const Icon(Icons.download_rounded, color: Colors.white, size: 18),
                      label: const Text('Сохранить', style: TextStyle(color: Colors.white, fontSize: 13)),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.12),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _saveToDownloads,
                    ),
                    if (widget.message != null) ...[
                      const SizedBox(width: 10),
                      TextButton.icon(
                        icon: const Icon(Icons.shortcut_rounded, color: Colors.white, size: 18),
                        label: const Text('Переслать', style: TextStyle(color: Colors.white, fontSize: 13)),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.12),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _showForward,
                      ),
                    ],
                    const SizedBox(width: 10),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 22),
                      tooltip: 'Закрыть',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
