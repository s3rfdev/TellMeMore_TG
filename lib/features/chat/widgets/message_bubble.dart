import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/tg_theme.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/widgets/tg_toast.dart';
import '../../../data/models/tg_chat.dart';
import '../../../data/tdlib/tdlib_service.dart';
import 'image_viewer_dialog.dart';
import 'message_context_menu.dart';
import 'video_viewer_dialog.dart';
import 'voice_message_bubble.dart';

/// Пузырь сообщения / разделители дат и непрочитанных.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    this.chatId = '',
    this.selectionMode = false,
    this.isSelected = false,
    this.onSelectToggle,
  });

  final TgMessage message;
  final String chatId;
  final bool selectionMode;
  final bool isSelected;
  final VoidCallback? onSelectToggle;

  @override
  Widget build(BuildContext context) {
    switch (message.kind) {
      case MessageKind.date:
      case MessageKind.unreadDivider:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Center(
            child: Text(
              message.text,
              style: const TextStyle(fontSize: 12.5, color: Tg.service),
            ),
          ),
        );
      default:
        return _bubble(context);
    }
  }

  Widget _bubble(BuildContext context) {
    final out = message.outgoing;

    Widget content;
    if (message.kind == MessageKind.voice) {
      content = VoiceMessageBubble(message: message, outgoing: out);
    } else if (message.kind == MessageKind.document) {
      content = _documentBody(context, out);
    } else if (message.kind == MessageKind.video) {
      content = _videoBody(context, out);
    } else if (message.kind == MessageKind.image) {
      Widget img;
      if (message.mediaPath.isNotEmpty && File(message.mediaPath).existsSync()) {
        img = MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => ImageViewerDialog.show(
              context,
              imagePath: message.mediaPath,
              time: message.time,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(
                File(message.mediaPath),
                width: 280,
                height: 190,
                fit: BoxFit.cover,
              ),
            ),
          ),
        );
      } else {
        img = Container(
          width: 280,
          height: 190,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.2, color: Tg.accent),
                ),
                SizedBox(height: 8),
                Text('Загрузка фото…', style: TextStyle(color: Tg.textDim, fontSize: 12)),
              ],
            ),
          ),
        );
      }
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: img,
          ),
          if (message.text.isNotEmpty)
            _textBody(context, message.text, out, topPadding: 8),
        ],
      );
    } else {
      content = _textBody(context, message.text, out);
    }

    final bubbleWidget = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 470),
      child: GestureDetector(
        onTap: selectionMode ? onSelectToggle : null,
        onSecondaryTapUp: selectionMode
            ? null
            : (details) => MessageContextMenu.show(
                  context: context,
                  position: details.globalPosition,
                  message: message,
                  chatId: chatId,
                ),
        onLongPressStart: selectionMode
            ? null
            : (details) => MessageContextMenu.show(
                  context: context,
                  position: details.globalPosition,
                  message: message,
                  chatId: chatId,
                ),
        child: Container(
          decoration: BoxDecoration(
            color: out ? Tg.outBubble : Tg.inBubble,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(14),
              topRight: const Radius.circular(14),
              bottomLeft: Radius.circular(out ? 14 : 4),
              bottomRight: Radius.circular(out ? 4 : 14),
            ),
            border: isSelected ? Border.all(color: Tg.accent, width: 2) : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 4,
                offset: const Offset(0, 1.5),
              ),
            ],
          ),
          child: (message.replyToMessageId > 0 || message.replySenderName.isNotEmpty)
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _replyBox(context, out),
                    content,
                  ],
                )
              : content,
        ),
      ),
    );

    if (selectionMode) {
      final checkIcon = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: GestureDetector(
          onTap: onSelectToggle,
          child: Icon(
            isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            color: isSelected ? Tg.accent : Tg.textDim,
            size: 22,
          ),
        ),
      );

      return Align(
        alignment: out ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: EdgeInsets.fromLTRB(out ? 20 : 14, 2, out ? 14 : 20, 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!out) checkIcon,
              Flexible(child: bubbleWidget),
              if (out) checkIcon,
            ],
          ),
        ),
      );
    }

    return Align(
      alignment: out ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.fromLTRB(out ? 64 : 14, 2, out ? 14 : 64, 2),
        child: bubbleWidget,
      ),
    );
  }

  Widget _replyBox(BuildContext context, bool out) {
    final hasThumb = message.replyThumbnailPath.isNotEmpty && File(message.replyThumbnailPath).existsSync();
    IconData? mediaIcon;
    if (message.replyKind == MessageKind.video) {
      mediaIcon = Icons.videocam_rounded;
    } else if (message.replyKind == MessageKind.image) {
      mediaIcon = Icons.image_rounded;
    } else if (message.replyKind == MessageKind.voice) {
      mediaIcon = Icons.mic_rounded;
    } else if (message.replyKind == MessageKind.document) {
      mediaIcon = Icons.insert_drive_file_rounded;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 2),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
        decoration: BoxDecoration(
          color: out ? Colors.black.withValues(alpha: 0.14) : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 3,
              height: 32,
              decoration: BoxDecoration(
                color: out ? Colors.white : Tg.accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            if (hasThumb) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.file(
                  File(message.replyThumbnailPath),
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 8),
            ] else if (mediaIcon != null) ...[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: out ? Colors.white.withValues(alpha: 0.12) : Tg.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(mediaIcon, size: 18, color: out ? Colors.white : Tg.accent),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message.replySenderName.isNotEmpty ? message.replySenderName : 'Ответ',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: out ? Colors.white : Tg.accent,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message.replyText.isNotEmpty ? message.replyText : 'Сообщение',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: out ? Colors.white.withValues(alpha: 0.82) : Tg.textDim,
                      fontSize: 11.8,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _videoBody(BuildContext context, bool out) {
    final hasThumb = message.thumbnailPath.isNotEmpty && File(message.thumbnailPath).existsSync();
    final isReady = message.isDownloaded &&
        message.mediaPath.isNotEmpty &&
        File(message.mediaPath).existsSync() &&
        File(message.mediaPath).lengthSync() > 100;
    final isDownloading = message.isDownloading && !isReady;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                final fileExists = message.mediaPath.isNotEmpty && File(message.mediaPath).existsSync();
                final fileSize = fileExists ? File(message.mediaPath).lengthSync() : -1;
                AppLogger.log('[message_bubble] Video tapped! msgId=${message.id}, fileId=${message.fileId}, mediaPath="${message.mediaPath}", exists=$fileExists, size=$fileSize, isReady=$isReady, isDownloading=$isDownloading');
                if (isReady) {
                  AppLogger.log('[message_bubble] Launching VideoViewerDialog.show...');
                  VideoViewerDialog.show(
                    context,
                    videoPath: message.mediaPath,
                    title: message.fileName.isNotEmpty ? message.fileName : 'Видеозапись',
                    time: message.time,
                    message: message,
                    chatId: chatId,
                  );
                } else if (isDownloading) {
                  AppLogger.log('[message_bubble] Video is downloading...');
                  TgToast.show(
                    context,
                    'Видеозапись загружается из Telegram…',
                    icon: Icons.downloading_rounded,
                  );
                } else if (message.fileId > 0) {
                  AppLogger.log('[message_bubble] Starting manual download for fileId=${message.fileId}...');
                  TdlibService.instance.downloadFile(message.fileId);
                  TgToast.show(
                    context,
                    'Загрузка видеозаписи начата…',
                    icon: Icons.download_rounded,
                  );
                }
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 290,
                  height: 195,
                  color: Colors.black.withValues(alpha: 0.35),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (hasThumb)
                        Image.file(
                          File(message.thumbnailPath),
                          fit: BoxFit.cover,
                        )
                      else
                        const Center(
                          child: Icon(Icons.videocam_rounded, color: Tg.textDim, size: 38),
                        ),

                      // Легкое затемнение под контролы
                      Container(color: Colors.black.withValues(alpha: 0.22)),

                      // Кнопка Play или прогресс загрузки по центру
                      Center(
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withValues(alpha: 0.62),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.5),
                          ),
                          child: isReady
                              ? const Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 32,
                                )
                              : isDownloading
                                  ? const Padding(
                                      padding: EdgeInsets.all(11.0),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.arrow_downward_rounded,
                                      color: Colors.white,
                                      size: 26,
                                    ),
                        ),
                      ),

                      // Длительность видео внизу слева
                      if (message.duration > 0)
                        Positioned(
                          left: 8,
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _formatDuration(message.duration),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),

                      // Время внизу справа
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: _timeRow(out, forceWhite: true),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (message.text.isNotEmpty)
          _textBody(context, message.text, out, topPadding: 8),
      ],
    );
  }

  Widget _documentBody(BuildContext context, bool out) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: out ? const Color(0xFF8774E1) : Tg.accent,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.insert_drive_file_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message.fileName.isNotEmpty ? message.fileName : 'Документ',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message.fileSize.isNotEmpty ? message.fileSize : 'Файл',
                      style: TextStyle(
                        fontSize: 12,
                        color: out ? Tg.timeOut : Tg.textDim,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _timeRow(out),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 2),
          // Боковая менюшка с тремя точками для файла
          Builder(
            builder: (btnCtx) {
              return IconButton(
                icon: const Icon(Icons.more_vert, size: 18, color: Tg.textDim),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                splashRadius: 16,
                tooltip: 'Опции файла',
                onPressed: () {
                  final renderBox = btnCtx.findRenderObject() as RenderBox?;
                  final pos = renderBox != null
                      ? renderBox.localToGlobal(Offset.zero) + const Offset(0, 24)
                      : Offset.zero;
                  MessageContextMenu.show(
                    context: context,
                    position: pos,
                    message: message,
                    chatId: chatId,
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _textBody(BuildContext context, String text, bool out, {double topPadding = 0}) {
    final spans = _buildTextSpans(context, text, out);

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 7 + topPadding, 12, 7),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: SelectableText.rich(
              TextSpan(
                style: const TextStyle(
                  fontSize: 14.5,
                  height: 1.25,
                  color: Colors.white,
                ),
                children: spans,
              ),
              cursorColor: Tg.accent,
              selectionColor: Tg.accent.withValues(alpha: 0.35),
            ),
          ),
          const SizedBox(width: 10),
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: _timeRow(out),
          ),
        ],
      ),
    );
  }

  List<InlineSpan> _buildTextSpans(BuildContext context, String text, bool out) {
    final regex = RegExp(r'(@[a-zA-Z0-9_]{3,}|https?://[^\s]+)');
    final matches = regex.allMatches(text);
    if (matches.isEmpty) {
      return [TextSpan(text: text)];
    }

    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final m in matches) {
      if (m.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, m.start)));
      }
      final matchedText = m.group(0)!;
      if (matchedText.startsWith('@')) {
        final username = matchedText.substring(1);
        spans.add(
          TextSpan(
            text: matchedText,
            style: TextStyle(
              color: out ? const Color(0xFFD4CCFF) : const Color(0xFF8774E1),
              fontWeight: FontWeight.w600,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                TdlibService.instance.openUserByUsername(username);
              },
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: matchedText,
            style: TextStyle(
              color: out ? const Color(0xFFD4CCFF) : const Color(0xFF8774E1),
              decoration: TextDecoration.underline,
            ),
          ),
        );
      }
      lastEnd = m.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    return spans;
  }

  Widget _timeRow(bool out, {bool forceWhite = false}) {
    final textColor = forceWhite
        ? Colors.white.withValues(alpha: 0.9)
        : (out ? Tg.timeOut : Tg.service);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          message.time,
          style: TextStyle(
            fontSize: 11,
            color: textColor,
          ),
        ),
        if (out) ...[
          const SizedBox(width: 3),
          Icon(
            message.read ? Icons.done_all : Icons.done,
            size: 14,
            color: forceWhite ? Colors.white : Tg.ticks,
          ),
        ],
      ],
    );
  }

  String _formatDuration(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
