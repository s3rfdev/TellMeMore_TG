import 'dart:io';

import 'package:flutter/material.dart';

/// Круглый аватар с реальным фото (если есть) или с градиентом и текстом.
class TgAvatar extends StatelessWidget {
  const TgAvatar({
    super.key,
    required this.emoji,
    required this.color,
    this.imagePath = '',
    this.size = 54,
    this.fontSize = 26,
  });

  final String emoji;
  final Color color;
  final String imagePath;
  final double size;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    if (imagePath.isNotEmpty) {
      if (imagePath.startsWith('assets/')) {
        return ClipOval(
          child: Image.asset(
            imagePath,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildFallback(),
          ),
        );
      }
      if (File(imagePath).existsSync()) {
        return ClipOval(
          child: Image.file(
            File(imagePath),
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildFallback(),
          ),
        );
      }
    }
    return _buildFallback();
  }

  Widget _buildFallback() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color,
            Color.lerp(color, Colors.black, 0.4)!,
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Text(emoji, style: TextStyle(fontSize: fontSize, height: 1)),
    );
  }
}
