import 'package:flutter/material.dart';

import '../../../../core/localization/app_locale.dart';
import '../../../../core/theme/tg_theme.dart';
import '../../../../data/models/tg_chat.dart';
import '../../../../data/tdlib/tdlib_service.dart';
import '../../models/contact_dossier.dart';

/// Карточка Sherlock Analysis с настройкой глубины анализа и кнопкой обновления.
class DossierSherlockCard extends StatelessWidget {
  const DossierSherlockCard({
    super.key,
    required this.chat,
    required this.dossier,
    required this.messageLimit,
    required this.isAnalyzing,
    required this.onLimitChanged,
    required this.onRunAnalysis,
  });

  final TgChat chat;
  final ContactDossier dossier;
  final int messageLimit;
  final bool isAnalyzing;
  final ValueChanged<int> onLimitChanged;
  final VoidCallback onRunAnalysis;

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final tdlibMsgs = TdlibService.instance.messagesOf(chat.id).value.messages;
    final totalMsgs = tdlibMsgs.isNotEmpty ? tdlibMsgs.length : chat.messages.length;
    final limit = messageLimit.clamp(5, 500);
    final effectiveCount = totalMsgs > 0 ? (limit > totalMsgs ? totalMsgs : limit) : 0;
    final isRu = I18n.instance.isRu;

    return Container(
      decoration: BoxDecoration(
        color: Tg.field,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      padding: const EdgeInsets.all(9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology_rounded, size: 15, color: Tg.accent),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  tr('ai_sherlock_header'),
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Tg.accent,
                  ),
                ),
              ),
              if (dossier.lastAnalyzed != null)
                Text(
                  tr('ai_sherlock_updated', {'time': _formatTime(dossier.lastAnalyzed!)}),
                  style: const TextStyle(fontSize: 9.5, color: Tg.textDim),
                ),
            ],
          ),
          const SizedBox(height: 7),

          // Слайдер сообщений для анализа
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  isRu ? 'Глубина анализа переписки:' : 'Analysis message depth:',
                  style: const TextStyle(fontSize: 10.5, color: Tg.textDim),
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
                  isRu ? '$effectiveCount из $totalMsgs сообщ.' : '$effectiveCount of $totalMsgs msgs',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Tg.accent),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
            ),
            child: Slider(
              value: limit.toDouble(),
              min: 5,
              max: totalMsgs > 100 ? totalMsgs.toDouble().clamp(100, 500) : 100,
              divisions: 19,
              activeColor: Tg.accent,
              inactiveColor: Colors.white.withValues(alpha: 0.08),
              onChanged: (val) => onLimitChanged(val.round()),
            ),
          ),
          const SizedBox(height: 4),

          if (dossier.summary.isNotEmpty) ...[
            Text(
              dossier.summary,
              style: const TextStyle(fontSize: 11, color: Tg.text, height: 1.3),
            ),
            const SizedBox(height: 8),
          ] else ...[
            Text(
              isRu
                  ? 'Запустите анализ, чтобы нейросеть изучила характер собеседника, скрытые мотивы и наличие манипуляций.'
                  : 'Run analysis to examine interlocutor motives, psychotype, and manipulation markers.',
              style: const TextStyle(fontSize: 10.5, color: Tg.textFaint, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 8),
          ],

          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: isAnalyzing ? null : onRunAnalysis,
              style: ElevatedButton.styleFrom(
                backgroundColor: Tg.accentDark,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
              ),
              icon: isAnalyzing
                  ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 1.6, color: Colors.white),
                    )
                  : const Icon(Icons.refresh_rounded, size: 14),
              label: Text(
                isAnalyzing ? tr('ai_sherlock_analyzing') : tr('ai_sherlock_refresh'),
                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
