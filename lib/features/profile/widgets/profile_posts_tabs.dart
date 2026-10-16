import 'package:flutter/material.dart';

import '../../../core/localization/app_locale.dart';
import '../../../core/theme/tg_theme.dart';

/// Переключатель табов "Посты" и "Архив постов".
class ProfilePostsTabs extends StatelessWidget {
  const ProfilePostsTabs({
    super.key,
    required this.activeTab,
    required this.onTabChanged,
  });

  final int activeTab;
  final ValueChanged<int> onTabChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFF17212B),
        borderRadius: BorderRadius.circular(19),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => onTabChanged(0),
              child: Container(
                decoration: BoxDecoration(
                  color: activeTab == 0 ? const Color(0xFF2B5278) : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Text(
                  tr('posts'),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: activeTab == 0 ? Tg.fontMedium : Tg.fontRegular,
                    color: activeTab == 0 ? Colors.white : Tg.textDim,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => onTabChanged(1),
              child: Container(
                decoration: BoxDecoration(
                  color: activeTab == 1 ? const Color(0xFF2B5278) : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Text(
                  tr('archived_posts'),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: activeTab == 1 ? Tg.fontMedium : Tg.fontRegular,
                    color: activeTab == 1 ? Colors.white : Tg.textDim,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
