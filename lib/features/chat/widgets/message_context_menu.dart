import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/tg_theme.dart';
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Файл скачивается из Telegram…')),
      );
      return;
    }

    if (sourcePath.isEmpty || !File(sourcePath).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Файл ещё не загружен или не найден')),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Сохранено в Загрузки ($base)'),
            backgroundColor: const Color(0xFF27A7E7),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка сохранения: $e')),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Скопировано в буфер обмена'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _onPin(BuildContext context) {
    Navigator.of(context).pop();
    final cid = int.tryParse(chatId);
    if (cid != null && message.id > 0) {
      TdlibService.instance.pinMessage(cid, message.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Сообщение закреплено'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _onDelete(BuildContext context) {
    Navigator.of(context).pop();
    final cid = int.tryParse(chatId);
    if (cid != null && message.id > 0) {
      TdlibService.instance.deleteMessage(cid, message.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Сообщение удалено'),
          duration: Duration(seconds: 2),
        ),
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
                    label: 'Ответить',
                    onTap: () => _onReply(context),
                  ),
                  _menuItem(
                    icon: Icons.shortcut_rounded,
                    label: 'Переслать',
                    onTap: () => _onForward(context),
                  ),
                  if (message.text.isNotEmpty)
                    _menuItem(
                      icon: Icons.copy_rounded,
                      label: 'Копировать текст',
                      onTap: () => _onCopy(context),
                    ),
                  if (_hasFile)
                    _menuItem(
                      icon: Icons.download_rounded,
                      label: 'Сохранить в…',
                      onTap: () => _saveToDownloads(context),
                    ),
                  _menuItem(
                    icon: Icons.push_pin_outlined,
                    label: 'Закрепить',
                    onTap: () => _onPin(context),
                  ),
                  const Divider(color: Color(0xFF2C2C30), height: 7, thickness: 1),
                  _menuItem(
                    icon: Icons.delete_outline_rounded,
                    label: 'Удалить',
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
