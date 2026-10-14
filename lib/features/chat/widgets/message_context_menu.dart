import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/localization/app_locale.dart';
import '../../../core/theme/tg_theme.dart';
import '../../../core/widgets/tg_toast.dart';
import '../../../data/models/tg_chat.dart';
import '../../../data/tdlib/tdlib_service.dart';
import '../../../state/app_state.dart';
import 'forward_dialog.dart';

/// Минималистичное контекстное меню сообщения в стиле Telegram Desktop.
class MessageContextMenu {
  MessageContextMenu._();

  static void show({
    required BuildContext context,
    required Offset position,
    required TgMessage message,
    required String chatId,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.25),
      transitionDuration: const Duration(milliseconds: 140),
      pageBuilder: (ctx, anim, secondaryAnim) {
        return _ContextMenuDialog(
          position: position,
          message: message,
          chatId: chatId,
        );
      },
      transitionBuilder: (ctx, anim, secondaryAnim, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
            alignment: Alignment.topLeft,
            child: child,
          ),
        );
      },
    );
  }
}

class _ContextMenuDialog extends StatelessWidget {
  const _ContextMenuDialog({
    required this.position,
    required this.message,
    required this.chatId,
  });

  final Offset position;
  final TgMessage message;
  final String chatId;

  bool get _hasFile =>
      message.kind == MessageKind.document ||
      message.kind == MessageKind.image ||
      message.kind == MessageKind.video ||
      message.kind == MessageKind.voice ||
      message.kind == MessageKind.audio ||
      message.mediaPath.isNotEmpty;

  Future<void> _saveToDownloads(BuildContext context) async {
    Navigator.of(context).pop();

    String sourcePath = message.mediaPath;
    if (sourcePath.isEmpty && message.fileId > 0) {
      TdlibService.instance.downloadFile(message.fileId);
      TgToast.show(
        context,
        'Файл скачивается из Telegram…',
        icon: Icons.downloading_rounded,
      );
      return;
    }

    if (sourcePath.isEmpty || !File(sourcePath).existsSync()) {
      TgToast.show(
        context,
        'Файл ещё не загружен или не найден',
        icon: Icons.error_outline_rounded,
      );
      return;
    }

    try {
      final file = File(sourcePath);
      final home = Platform.environment['HOME'] ?? '';
      final downloadsDir = Directory('$home/Downloads');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }
      final base = message.fileName.isNotEmpty
          ? message.fileName
          : 'tg_file_${DateTime.now().millisecondsSinceEpoch}';
      final destPath = '${downloadsDir.path}/$base';
      await file.copy(destPath);
      if (context.mounted) {
        TgToast.show(
          context,
          '✓ Сохранено в Загрузки',
          icon: Icons.check_circle_rounded,
        );
      }
    } catch (e) {
      if (context.mounted) {
        TgToast.show(
          context,
          'Ошибка сохранения: $e',
          icon: Icons.error_outline_rounded,
        );
      }
    }
  }

  void _onReply(BuildContext context) {
    Navigator.of(context).pop();
    AppState.replyingTo.value = message;
  }

  void _onForward(BuildContext context) {
    Navigator.of(context).pop();
    ForwardDialog.show(
      context,
      message: message,
      currentChatId: chatId,
    );
  }

  void _onCopy(BuildContext context) {
    Navigator.of(context).pop();
    final text = message.text.isNotEmpty ? message.text : message.fileName;
    if (text.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: text));
      TgToast.show(
        context,
        '✓ Скопировано в буфер обмена',
        icon: Icons.copy_rounded,
      );
    }
  }

  void _onPin(BuildContext context) {
    Navigator.of(context).pop();
    final cid = int.tryParse(chatId);
    if (cid != null && message.id > 0) {
      TdlibService.instance.pinMessage(cid, message.id);
      TgToast.show(
        context,
        '✓ Сообщение закреплено',
        icon: Icons.push_pin_rounded,
      );
    }
  }

  void _onDelete(BuildContext context) {
    Navigator.of(context).pop();
    final cid = int.tryParse(chatId);
    if (cid != null && message.id > 0) {
      TdlibService.instance.deleteMessage(cid, message.id);
      TgToast.show(
        context,
        'Сообщение удалено',
        icon: Icons.delete_outline_rounded,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    const menuWidth = 195.0;

    // Считаем число пунктов для корректного расчета высоты
    int itemsCount = 4; // reply, forward, pin, delete
    if (message.text.isNotEmpty) itemsCount++; // copy
    if (_hasFile) itemsCount++; // save to downloads

    final estimatedHeight = itemsCount * 33.0 + 12.0;

    double left = position.dx;
    double top = position.dy;

    if (left + menuWidth > screenSize.width - 12) {
      left = screenSize.width - menuWidth - 12;
    }
    if (left < 12) left = 12;

    if (top + estimatedHeight > screenSize.height - 12) {
      top = position.dy - estimatedHeight;
    }
    if (top < 12) top = 12;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(),
          ),
        ),
        Positioned(
          left: left,
          top: top,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: menuWidth,
              decoration: BoxDecoration(
                color: const Color(0xFF212124),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF2F2F34)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _menuItem(
                    icon: Icons.reply_rounded,
                    label: tr('reply'),
                    onTap: () => _onReply(context),
                  ),
                  _menuItem(
                    icon: Icons.shortcut_rounded,
                    label: tr('forward'),
                    onTap: () => _onForward(context),
                  ),
                  if (message.text.isNotEmpty)
                    _menuItem(
                      icon: Icons.copy_rounded,
                      label: tr('copy_text'),
                      onTap: () => _onCopy(context),
                    ),
                  if (_hasFile)
                    _menuItem(
                      icon: Icons.download_rounded,
                      label: tr('save_to_downloads'),
                      onTap: () => _saveToDownloads(context),
                    ),
                  _menuItem(
                    icon: Icons.push_pin_outlined,
                    label: tr('pin'),
                    onTap: () => _onPin(context),
                  ),
                  const Divider(color: Color(0xFF2C2C30), height: 7, thickness: 1),
                  _menuItem(
                    icon: Icons.delete_outline_rounded,
                    label: tr('delete'),
                    color: const Color(0xFFFF595A),
                    onTap: () => _onDelete(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _menuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final itemColor = color ?? Colors.white;
    return InkWell(
      onTap: onTap,
      hoverColor: Colors.white.withValues(alpha: 0.07),
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color ?? Tg.textDim),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12.8,
                  fontWeight: FontWeight.w400,
                  color: itemColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
