import 'package:flutter/material.dart';

import '../../../../core/localization/app_locale.dart';
import '../../../../core/theme/tg_theme.dart';
import '../../../../core/widgets/tg_toast.dart';
import '../../services/copilot_session_store.dart';
import 'collapsible_dossier_card.dart';

/// Секция автокомпрессии диалога и долговременной памяти с Copilot по контакту.
class DossierMemorySection extends StatefulWidget {
  const DossierMemorySection({
    super.key,
    required this.chatId,
    required this.autoCompressEnabled,
    required this.autoCompressThreshold,
    required this.keepRawCount,
    required this.dialogueCompressionController,
    required this.onAutoCompressChanged,
    required this.onThresholdChanged,
    required this.onKeepRawChanged,
  });

  final String chatId;
  final bool autoCompressEnabled;
  final int autoCompressThreshold;
  final int keepRawCount;
  final TextEditingController dialogueCompressionController;
  final ValueChanged<bool> onAutoCompressChanged;
  final ValueChanged<int> onThresholdChanged;
  final ValueChanged<int> onKeepRawChanged;

  @override
  State<DossierMemorySection> createState() => _DossierMemorySectionState();
}

class _DossierMemorySectionState extends State<DossierMemorySection> {
  bool _isCompressingDialogue = false;

  @override
  Widget build(BuildContext context) {
    final isRu = I18n.instance.isRu;
    final sessionId = 'contact_${widget.chatId}';
    final existingSession = CopilotSessionStore.instance.sessions.value
        .where((s) => s.id == sessionId)
        .firstOrNull;

    return CollapsibleDossierCard(
      title: isRu ? 'Автокомпрессия и память контекста' : 'Auto-compression & Context Memory',
      icon: Icons.memory_rounded,
      subtitle: isRu
          ? 'Сжатие длинной истории диалога при переполнении лимита'
          : 'Compress conversation history upon reaching threshold',
      initiallyExpanded: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isRu ? 'Автокомпрессия при переполнении:' : 'Auto-compress on threshold:',
                style: const TextStyle(fontSize: 11.5, color: Tg.text, fontWeight: FontWeight.w400),
              ),
              Transform.scale(
                scale: 0.72,
                child: Switch.adaptive(
                  value: widget.autoCompressEnabled,
                  activeTrackColor: Tg.accent.withValues(alpha: 0.35),
                  activeThumbColor: Tg.accent,
                  onChanged: widget.onAutoCompressChanged,
                ),
              ),
            ],
          ),

          if (widget.autoCompressEnabled) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isRu ? 'Порог срабатывания сжатия:' : 'Compression trigger threshold:',
                  style: const TextStyle(fontSize: 11, color: Tg.textDim),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: Tg.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isRu ? '${widget.autoCompressThreshold} сообщ.' : '${widget.autoCompressThreshold} msgs',
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500, color: Tg.accent),
                  ),
                ),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
              ),
              child: Slider(
                value: widget.autoCompressThreshold.toDouble().clamp(10.0, 80.0),
                min: 10,
                max: 80,
                divisions: 14,
                activeColor: Tg.accent,
                inactiveColor: Colors.white.withValues(alpha: 0.08),
                onChanged: (val) => widget.onThresholdChanged(val.round()),
              ),
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isRu ? 'Свежих сообщений без сжатия (окно):' : 'Raw recent window:',
                  style: const TextStyle(fontSize: 11, color: Tg.textDim),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: Tg.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isRu ? '${widget.keepRawCount} сообщ.' : '${widget.keepRawCount} msgs',
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500, color: Tg.accent),
                  ),
                ),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
              ),
              child: Slider(
                value: widget.keepRawCount.toDouble().clamp(3.0, 20.0),
                min: 3,
                max: 20,
                divisions: 17,
                activeColor: Tg.accent,
                inactiveColor: Colors.white.withValues(alpha: 0.08),
                onChanged: (val) => widget.onKeepRawChanged(val.round()),
              ),
            ),

            const SizedBox(height: 2),
            Text(
              isRu ? 'Призма сжатия диалога:' : 'Dialogue compression lens:',
              style: const TextStyle(fontSize: 11, color: Tg.text, fontWeight: FontWeight.w400),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: Tg.sidebar,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: TextField(
                controller: widget.dialogueCompressionController,
                maxLines: 2,
                style: const TextStyle(color: Tg.text, fontSize: 11),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  hintText: isRu ? 'Инструкция для сжатия диалога...' : 'Compression instructions...',
                  hintStyle: const TextStyle(color: Tg.textFaint, fontSize: 10.5),
                ),
              ),
            ),
          ],

          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Tg.accent,
                  side: BorderSide(color: Tg.accent.withValues(alpha: 0.35)),
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                icon: _isCompressingDialogue
                    ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.8, color: Tg.accent))
                    : const Icon(Icons.archive_outlined, size: 14),
                label: Text(
                  _isCompressingDialogue
                      ? (isRu ? 'Сжатие...' : 'Compressing...')
                      : (isRu
                          ? 'Сжать диалог сейчас (${existingSession?.messages.length ?? 0} сообщ.)'
                          : 'Compress dialogue now (${existingSession?.messages.length ?? 0} msgs)'),
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500),
                ),
                onPressed: _isCompressingDialogue
                    ? null
                    : () async {
                        setState(() => _isCompressingDialogue = true);
                        try {
                          final compressed = await CopilotSessionStore.instance.compressSessionIntelligent(sessionId);
                          if (!mounted) return;
                          if (compressed) {
                            TgToast.show(this.context, isRu ? '🗜️ Диалог сжат и сохранен в памяти!' : '🗜️ Dialogue compressed to memory!');
                          } else {
                            TgToast.show(
                              this.context,
                              isRu
                                  ? 'В диалоге мало сообщений (меньше окна ${widget.keepRawCount})'
                                  : 'Dialogue has fewer messages than window (${widget.keepRawCount})',
                            );
                          }
                        } catch (e) {
                          if (!mounted) return;
                          TgToast.show(this.context, 'Ошибка сжатия: $e');
                        } finally {
                          if (mounted) {
                            setState(() => _isCompressingDialogue = false);
                          }
                        }
                      },
              ),
              const Spacer(),
              if (existingSession?.contextSummary != null && existingSession!.contextSummary!.isNotEmpty)
                Text(
                  isRu ? '⚡ Память: активна' : '⚡ Memory: active',
                  style: const TextStyle(fontSize: 10.5, color: Color(0xFF00C48C), fontWeight: FontWeight.w500),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
