import 'package:flutter/material.dart';

import '../../../core/localization/app_locale.dart';
import '../../../core/theme/tg_theme.dart';
import '../../../core/widgets/tg_toast.dart';
import '../models/ai_settings_model.dart';
import '../models/copilot_session.dart';
import '../services/copilot_session_store.dart';

/// Диалог инспектора слоев сэндвич-контекста (Sandwich Prompt Inspector) с отображением токенов.
class CopilotSandwichInspectorDialog extends StatelessWidget {
  const CopilotSandwichInspectorDialog({
    super.key,
    required this.session,
    required this.settings,
    required this.currentQuery,
  });

  final CopilotSession session;
  final AiSettings settings;
  final String currentQuery;

  static void show(
    BuildContext context, {
    required CopilotSession session,
    required AiSettings settings,
    required String currentQuery,
  }) {
    showDialog(
      context: context,
      builder: (_) => CopilotSandwichInspectorDialog(
        session: session,
        settings: settings,
        currentQuery: currentQuery,
      ),
    );
  }

  Widget _buildSandwichLayer({
    required String layerNumber,
    required String layerName,
    required int tokens,
    required Color color,
    required String description,
    required String content,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  layerName,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: color),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$tokens tok',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500, color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(description, style: const TextStyle(fontSize: 11.5, color: Tg.textDim)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final queryText = currentQuery.isEmpty ? '[Текущий запрос]' : currentQuery;
    final sandwich = CopilotSessionStore.instance.buildSandwichPrompt(
      session,
      settings,
      queryText,
    );

    return AlertDialog(
      backgroundColor: Tg.sidebar,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Tg.border),
      ),
      title: Row(
        children: [
          const Icon(Icons.layers_outlined, color: Tg.accent, size: 20),
          const SizedBox(width: 10),
          Text(
            tr('context_sandwich_title'),
            style: Tg.title,
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('sandwich_desc'),
                style: const TextStyle(color: Tg.textDim, fontSize: 12.5),
              ),
              const SizedBox(height: 14),

              // Слой 1: Верхний хлеб
              _buildSandwichLayer(
                layerNumber: '1',
                layerName: tr('sandwich_layer_top_bread'),
                tokens: sandwich['systemTokens'] as int,
                color: const Color(0xFFFF9F43),
                description: 'Персона агента, инструкции, формат вывода и подключенные инструменты.',
                content: sandwich['systemSlice'] as String,
              ),
              const SizedBox(height: 10),

              // Слой 2: Начинка - Сжатое саммари
              _buildSandwichLayer(
                layerNumber: '2',
                layerName: tr('sandwich_layer_summary'),
                tokens: sandwich['summaryTokens'] as int,
                color: const Color(0xFF00C48C),
                description: sandwich['summarySlice'] != null
                    ? tr('sandwich_layer_summary_compressed')
                    : tr('sandwich_layer_summary_compact'),
                content: sandwich['summarySlice'] as String? ??
                    (I18n.instance.isRu ? '— Нет сжатого контекста —' : '— No compressed context —'),
              ),
              const SizedBox(height: 10),

              // Слой 3: Начинка - Сырые недавние сообщения
              _buildSandwichLayer(
                layerNumber: '3',
                layerName: tr('sandwich_layer_raw'),
                tokens: sandwich['rawTokens'] as int,
                color: const Color(0xFF51B2FF),
                description: tr('sandwich_layer_raw_desc', {'count': session.rawMessagesCount.toString()}),
                content: session.messages
                    .map((m) => '${m.isUser ? tr("you") : tr("bot")}: ${m.text}')
                    .join('\n'),
              ),
              const SizedBox(height: 10),

              // Слой 4: Нижний хлеб
              _buildSandwichLayer(
                layerNumber: '4',
                layerName: tr('sandwich_layer_bottom_bread'),
                tokens: sandwich['bottomTokens'] as int,
                color: const Color(0xFFFF7675),
                description: tr('sandwich_layer_bottom_desc'),
                content: sandwich['bottomSlice'] as String,
              ),
              const SizedBox(height: 14),

              // Итого
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Tg.field,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr('total_request_volume'), style: const TextStyle(color: Tg.textDim, fontSize: 12)),
                        const SizedBox(height: 2),
                        Text(
                          '${sandwich["totalTokens"]} tok / ${I18n.instance.isRu ? "Порог: " : "Threshold: "}${settings.compressionVolumeThreshold}',
                          style: const TextStyle(color: Tg.text, fontWeight: FontWeight.w600, fontSize: 13.5),
                        ),
                      ],
                    ),
                    if (session.messages.length > settings.compressionKeepRawCount)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00C48C),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          CopilotSessionStore.instance.compressSession(
                            session.id,
                            keepRawCount: settings.compressionKeepRawCount,
                          );
                          Navigator.of(context).pop();
                          TgToast.show(context, tr('context_compressed_toast'));
                        },
                        icon: const Icon(Icons.compress, size: 16),
                        label: Text(tr('compress_now')),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Tg.accent,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tr('close')),
        ),
      ],
    );
  }
}
