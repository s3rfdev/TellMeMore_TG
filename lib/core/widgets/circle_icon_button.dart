import 'package:flutter/material.dart';

/// Круглая кнопка с ховером — базовый элемент панелей Telegram.
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    this.iconSize = 20,
    this.color = const Color(0xFFAEBAC1),
    this.onTap,
  });

  final IconData icon;
  final double iconSize;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        customBorder: const CircleBorder(),
        hoverColor: Colors.white.withValues(alpha: 0.07),
        onTap: onTap ?? () {},
        child: SizedBox(
          width: 36,
          height: 36,
          child: Center(
            child: Icon(icon, size: iconSize, color: color),
          ),
        ),
      ),
    );
  }
}
