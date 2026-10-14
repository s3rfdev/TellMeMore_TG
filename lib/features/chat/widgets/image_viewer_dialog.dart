import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/tg_theme.dart';
import '../../../data/models/tg_chat.dart';
import '../../../data/tdlib/tdlib_service.dart';

/// Полноэкранный просмотрщик изображений в стиле Telegram Desktop.
/// Поддерживает зум (InteractiveViewer), горячую клавишу Esc,
/// сохранение в Загрузки и пересылку в другие чаты.
class ImageViewerDialog extends StatelessWidget {
  const ImageViewerDialog({
    super.key,
    required this.imagePath,
    this.title = 'Фотография',
    this.time = '',
  });

  final String imagePath;
  final String title;
  final String time;

  static void show(BuildContext context, {required String imagePath, String title = 'Фотография', String time = ''}) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (_) => ImageViewerDialog(
        imagePath: imagePath,
        title: title,
        time: time,
      ),
    );
  }

  Future<void> _saveToDownloads(BuildContext context) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Файл изображения не найден')),
          );
        }
        return;
      }
      final home = Platform.environment['HOME'] ?? '';
      final downloadsDir = Directory('$home/Downloads');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }
      final ext = imagePath.contains('.') ? imagePath.split('.').last : 'jpg';
      final destName = 'tg_photo_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final destPath = '${downloadsDir.path}/$destName';
      await file.copy(destPath);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Сохранено в Загрузки ($destName)'),
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

  void _showForwardDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF212124),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Переслать в…', style: TextStyle(color: Tg.text, fontSize: 16)),
        content: SizedBox(
          width: 320,
          height: 320,
          child: ValueListenableBuilder<List<TgChat>>(
            valueListenable: TdlibService.instance.chats,
            builder: (context, chats, _) {
              if (chats.isEmpty) {
                return const Center(child: Text('Нет доступных чатов', style: TextStyle(color: Tg.textDim)));
              }
              return ListView.builder(
                itemCount: chats.length,
                itemBuilder: (context, i) {
                  final c = chats[i];
                  return ListTile(
                    dense: true,
                    title: Text(c.title, style: const TextStyle(color: Tg.text, fontSize: 14)),
                    onTap: () {
                      Navigator.pop(ctx);
                      final id = int.tryParse(c.id);
                      if (id != null) {
                        TdlibService.instance.sendFile(id, imagePath);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('✓ Переслано в "${c.title}"')),
                        );
                      }
                    },
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена', style: TextStyle(color: Tg.textDim)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final file = File(imagePath);
    final exists = file.existsSync();

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
            // Центр: интерактивное зумируемое изображение
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => Navigator.of(context).pop(),
                child: Center(
                  child: exists
                      ? InteractiveViewer(
                          minScale: 0.5,
                          maxScale: 4.0,
                          child: GestureDetector(
                            onTap: () {}, // поглощает клик на картинку
                            child: Image.file(
                              file,
                              fit: BoxFit.contain,
                            ),
                          ),
                        )
                      : const Text(
                          'Изображение загружается или недоступно',
                          style: TextStyle(color: Tg.textDim, fontSize: 15),
                        ),
                ),
              ),
            ),

            // Верхняя плашка управления (минималистичная, как в Telegram Desktop)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.8),
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
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (time.isNotEmpty)
                          Text(
                            time,
                            style: const TextStyle(color: Tg.textDim, fontSize: 12),
                          ),
                      ],
                    ),
                    const Spacer(),
                    if (exists) ...[
                      TextButton.icon(
                        icon: const Icon(Icons.download_rounded, color: Colors.white, size: 18),
                        label: const Text('Сохранить', style: TextStyle(color: Colors.white, fontSize: 13)),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.12),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => _saveToDownloads(context),
                      ),
                      const SizedBox(width: 10),
                      TextButton.icon(
                        icon: const Icon(Icons.reply_rounded, color: Colors.white, size: 18),
                        label: const Text('Переслать', style: TextStyle(color: Colors.white, fontSize: 13)),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.12),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => _showForwardDialog(context),
                      ),
                      const SizedBox(width: 10),
                    ],
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
