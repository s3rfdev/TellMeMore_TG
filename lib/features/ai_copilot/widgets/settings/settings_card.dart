import 'package:flutter/material.dart';

import '../../../../core/theme/tg_theme.dart';

/// Базовая карточка настроек с заголовком и закругленной рамкой.
class SettingsCard extends StatelessWidget {
  const SettingsCard({
    super.key,
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Tg.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Tg.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Tg.title,
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
