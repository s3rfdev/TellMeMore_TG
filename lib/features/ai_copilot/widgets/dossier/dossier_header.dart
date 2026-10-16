import 'package:flutter/material.dart';

import '../../../../core/localization/app_locale.dart';
import '../../../../core/theme/tg_theme.dart';
import '../../../../core/widgets/tg_avatar.dart';
import '../../../../data/models/tg_chat.dart';

/// Верхняя панель диалога досье контакта с аватаром, именем, кнопкой закрытия и табами.
class DossierHeader extends StatelessWidget {
  const DossierHeader({
    super.key,
    required this.chat,
    required this.tabController,
    required this.onClose,
  });

  final TgChat chat;
  final TabController tabController;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final isRu = I18n.instance.isRu;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 11, 12, 0),
      child: Column(
        children: [
          Row(
            children: [
              TgAvatar(
                emoji: chat.avatarEmoji,
                color: Color(chat.avatarColor),
                imagePath: chat.avatarPath,
                size: 32,
                fontSize: 13,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            chat.title,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Tg.text,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: Tg.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isRu ? 'AI-Ассистент' : 'AI Assistant',
                            style: const TextStyle(
                              fontSize: 9.5,
                              color: Tg.accent,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      chat.headerSubtitle.isNotEmpty
                          ? chat.headerSubtitle
                          : (isRu ? 'Управление досье и контекстом' : 'Dossier & context management'),
                      style: const TextStyle(fontSize: 10.5, color: Tg.textDim),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18, color: Tg.textFaint),
                splashRadius: 14,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: onClose,
              ),
            ],
          ),
          const SizedBox(height: 6),
          TabBar(
            controller: tabController,
            labelColor: Tg.accent,
            unselectedLabelColor: Tg.textDim,
            indicatorColor: Tg.accent,
            indicatorWeight: 2,
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.normal),
            tabs: [
              Tab(text: isRu ? '👤 Досье контакта (CRM)' : '👤 Contact Dossier (CRM)'),
              Tab(text: isRu ? '⚙️ Промпт и память (LLM)' : '⚙️ Prompt & Memory (LLM)'),
            ],
          ),
        ],
      ),
    );
  }
}
