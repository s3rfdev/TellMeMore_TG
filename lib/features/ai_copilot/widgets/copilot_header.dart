import 'package:flutter/material.dart';

import '../../../core/localization/app_locale.dart';
import '../../../core/theme/tg_theme.dart';
import '../../../core/widgets/circle_icon_button.dart';
import '../models/ai_settings_model.dart';
import '../models/copilot_session.dart';

/// Заголовок панели AI Copilot с информацией об агенте, модели и кнопками управления.
class CopilotHeader extends StatelessWidget {
  const CopilotHeader({
    super.key,
    required this.session,
    required this.settings,
    this.showBack = false,
    this.onBack,
    this.onOpenInspector,
    this.onOpenPromptEditor,
    this.onClearHistory,
  });

  final CopilotSession session;
  final AiSettings settings;
  final bool showBack;
  final VoidCallback? onBack;
  final VoidCallback? onOpenInspector;
  final VoidCallback? onOpenPromptEditor;
  final VoidCallback? onClearHistory;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      margin: const EdgeInsets.fromLTRB(10, 10, 10, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Tg.sidebar,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Tg.border),
      ),
      child: Row(
        children: [
          if (showBack) ...[
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: Tg.textDim),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              splashRadius: 18,
              tooltip: tr('back'),
              onPressed: onBack,
            ),
            const SizedBox(width: 4),
          ],
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: session.avatarColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: session.avatarColor.withValues(alpha: 0.5)),
            ),
            child: Icon(session.avatarIcon, color: session.avatarColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        session.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Tg.text,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: session.avatarColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          session.agentRole,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: session.avatarColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  '${session.model ?? settings.model} • ${settings.provider}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Tg.textDim),
                ),
              ],
            ),
          ),

          // Кнопка инспектора бутерброда / объема токенов
          Tooltip(
            message: tr('context_inspector_tooltip'),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onOpenInspector,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: session.contextSummary != null
                      ? const Color(0xFF00C48C).withValues(alpha: 0.18)
                      : Tg.field,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: session.contextSummary != null
                        ? const Color(0xFF00C48C).withValues(alpha: 0.4)
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      session.contextSummary != null ? Icons.compress : Icons.layers_outlined,
                      size: 14,
                      color: session.contextSummary != null ? const Color(0xFF00C48C) : Tg.accent,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${session.totalTokens} tok',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: Tg.fontMedium,
                        color: session.contextSummary != null ? const Color(0xFF00C48C) : Tg.text,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Кнопка директив / промпта агента
          Tooltip(
            message: tr('agent_directives_tooltip'),
            child: CircleIconButton(
              icon: Icons.tune_rounded,
              iconSize: 19,
              color: Tg.textDim,
              onTap: onOpenPromptEditor,
            ),
          ),

          // Кнопка очистки сообщений
          Tooltip(
            message: tr('clear_history_tooltip'),
            child: CircleIconButton(
              icon: Icons.delete_sweep_outlined,
              iconSize: 19,
              color: Tg.textDim,
              onTap: onClearHistory,
            ),
          ),
        ],
      ),
    );
  }
}
