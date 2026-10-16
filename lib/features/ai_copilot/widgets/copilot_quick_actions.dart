import 'package:flutter/material.dart';

import '../../../core/localization/app_locale.dart';
import '../../../core/theme/tg_theme.dart';
import '../models/copilot_session.dart';

/// Горизонтальная панель быстрых действий (Quick Action Chips) для Copilot.
class CopilotQuickActions extends StatelessWidget {
  const CopilotQuickActions({
    super.key,
    required this.session,
    required this.onSelectAction,
  });

  final CopilotSession session;
  final ValueChanged<String> onSelectAction;

  @override
  Widget build(BuildContext context) {
    List<String> actions;
    final role = session.agentRole.toLowerCase();
    final isRu = I18n.instance.isRu;

    if (session.id.startsWith('contact_')) {
      actions = [
        isRu ? '📊 Анализ человека и переписки' : '📊 Analyze person & chat',
        isRu ? '🧐 Манипулирует ли собеседник?' : '🧐 Is contact manipulating?',
        isRu ? '🎯 Истинные мотивы собеседника' : '🎯 Real contact motives',
        isRu ? '✍️ Предложи идеальный ответ' : '✍️ Suggest best reply',
        isRu ? '⏳ Зафиксировать договоренности' : '⏳ Lock agreements',
      ];
    } else if (role.contains('hunter') || role.contains('ваканси') || role.contains('лид')) {
      actions = [
        isRu ? '💼 Вакансии Flutter Remote' : '💼 Flutter Remote Jobs',
        isRu ? '🔍 Спарсить чат заказов' : '🔍 Parse Orders Chat',
        isRu ? '📋 Подготовить отклик' : '📋 Draft Proposal',
        isRu ? '🎯 Фильтр по рейту от \$4000' : '🎯 Rate Filter \$4000+',
      ];
    } else if (role.contains('crm') || role.contains('анали')) {
      actions = [
        isRu ? '📊 Саммари переписки' : '📊 Conversation Summary',
        isRu ? '🎯 Досье контакта' : '🎯 Contact Dossier',
        isRu ? '⏳ Зафиксировать договоренности' : '⏳ Lock Agreements',
        isRu ? '📝 Экспорт в CRM заметки' : '📝 Export to CRM Notes',
      ];
    } else if (role.contains('code') || role.contains('архитект')) {
      actions = [
        isRu ? '🛠️ Ревью Isolate C++ в TDLib' : '🛠️ Review C++ Isolate in TDLib',
        isRu ? '⚡ Анализ задержки звонков' : '⚡ Call Latency Analysis',
        isRu ? '🧪 Написать unit-тесты' : '🧪 Generate Unit Tests',
        isRu ? '📦 Проверить сжатие контекста' : '📦 Check Context Compression',
      ];
    } else {
      actions = [
        isRu ? '📊 Анализ активного диалога' : '📊 Analyze Active Chat',
        isRu ? '🧐 Мотивы и скрытые цели' : '🧐 Motives & Hidden Goals',
        isRu ? '💼 Найти вакансии Flutter' : '💼 Find Flutter Jobs',
        isRu ? '✍️ Предложи ответ в чат' : '✍️ Draft Chat Reply',
      ];
    }

    return Container(
      height: 36,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: actions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final action = actions[i];
          return ActionChip(
            label: Text(action),
            backgroundColor: Tg.sidebar.withValues(alpha: 0.9),
            labelStyle: const TextStyle(
              fontSize: 12,
              color: Tg.text,
              fontWeight: FontWeight.w500,
            ),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            onPressed: () => onSelectAction(action),
          );
        },
      ),
    );
  }
}
