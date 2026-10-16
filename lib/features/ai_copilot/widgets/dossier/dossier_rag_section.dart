import 'package:flutter/material.dart';

import '../../../../core/localization/app_locale.dart';
import '../../../../core/theme/tg_theme.dart';
import '../../../../core/widgets/tg_toast.dart';
import '../../../../data/models/tg_chat.dart';
import '../../../../data/tdlib/tdlib_service.dart';
import '../../models/contact_dossier.dart';
import '../../services/copilot_session_store.dart';
import 'collapsible_dossier_card.dart';

/// Секция RAG-сбора фактов из чата по заданной призме.
class DossierRagSection extends StatefulWidget {
  const DossierRagSection({
    super.key,
    required this.chat,
    required this.messageLimit,
    required this.ragPromptController,
    this.currentRagSummary,
    this.currentRagCount = 0,
    this.currentRagDate,
    required this.onLimitChanged,
    required this.onSummaryUpdated,
  });

  final TgChat chat;
  final int messageLimit;
  final TextEditingController ragPromptController;
  final String? currentRagSummary;
  final int currentRagCount;
  final DateTime? currentRagDate;
  final ValueChanged<int> onLimitChanged;
  final void Function(String? summary, int count, DateTime? date) onSummaryUpdated;

  @override
  State<DossierRagSection> createState() => _DossierRagSectionState();
}

class _DossierRagSectionState extends State<DossierRagSection> {
  bool _isExtractingRag = false;

  @override
  Widget build(BuildContext context) {
    final isRu = I18n.instance.isRu;

    return CollapsibleDossierCard(
      title: isRu ? 'RAG-сбор сухих фактов из чата' : 'Chat RAG & Fact Extraction',
      icon: Icons.hub_outlined,
      badge: widget.currentRagSummary != null ? (isRu ? 'Активно' : 'Active') : null,
      subtitle: isRu
          ? 'Сжатие истории сообщений в факты по заданной призме'
          : 'Compress chat history into facts per custom filter',
      initiallyExpanded: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  isRu ? 'Глубина сбора фактов (RAG):' : 'Fact extraction depth (RAG):',
                  style: const TextStyle(fontSize: 10.5, color: Tg.text, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: Tg.accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isRu ? '${widget.messageLimit} сообщ.' : '${widget.messageLimit} msgs',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Tg.accent),
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
              value: widget.messageLimit.toDouble().clamp(10.0, 500.0),
              min: 10,
              max: 500,
              divisions: 49,
              activeColor: Tg.accent,
              inactiveColor: Colors.white.withValues(alpha: 0.08),
              onChanged: (val) => widget.onLimitChanged(val.round()),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            isRu ? 'Призма взгляда для RAG (какие факты извлекать):' : 'RAG filter lens (what facts to gather):',
            style: const TextStyle(fontSize: 11, color: Tg.text, fontWeight: FontWeight.w400),
          ),
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: Tg.sidebar,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: TextField(
              controller: widget.ragPromptController,
              maxLines: 2,
              style: const TextStyle(color: Tg.text, fontSize: 11.5),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: isRu ? 'Укажите фокус: договоренности, условия, спорные реплики...' : 'Extraction focus...',
                hintStyle: const TextStyle(color: Tg.textFaint, fontSize: 11),
              ),
            ),
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Tg.accent.withValues(alpha: 0.18),
                  foregroundColor: Tg.accent,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(7),
                    side: BorderSide(color: Tg.accent.withValues(alpha: 0.35)),
                  ),
                ),
                icon: _isExtractingRag
                    ? const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 1.8, color: Tg.accent))
                    : const Icon(Icons.bolt_rounded, size: 15),
                label: Text(
                  _isExtractingRag
                      ? (isRu ? 'Сбор фактов...' : 'Extracting...')
                      : (isRu ? 'Собрать RAG-выжимку (${widget.messageLimit} сообщ.)' : 'Extract RAG Facts (${widget.messageLimit} msgs)'),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
                onPressed: _isExtractingRag
                    ? null
                    : () async {
                        setState(() => _isExtractingRag = true);
                        try {
                          final realHistory = TdlibService.instance.messagesOf(widget.chat.id).value;
                          final msgs = realHistory.messages.isNotEmpty ? realHistory.messages : widget.chat.messages;
                          final sessionId = 'contact_${widget.chat.id}';
                          final summary = await CopilotSessionStore.instance.runRagFactExtraction(
                            sessionId: sessionId,
                            chatId: widget.chat.id,
                            messages: msgs,
                            limit: widget.messageLimit,
                            ragPrompt: widget.ragPromptController.text,
                            chatTitle: widget.chat.title,
                          );
                          final count = msgs.length > widget.messageLimit ? widget.messageLimit : msgs.length;
                          final now = DateTime.now();
                          widget.onSummaryUpdated(summary, count, now);
                          if (!mounted) return;
                          TgToast.show(
                            this.context,
                            isRu ? '⚡ RAG-выжимка из $count сообщений собрана!' : '⚡ RAG summary extracted!',
                          );
                        } catch (e) {
                          if (!mounted) return;
                          TgToast.show(this.context, 'Ошибка RAG: $e');
                        } finally {
                          if (mounted) {
                            setState(() => _isExtractingRag = false);
                          }
                        }
                      },
              ),
              const Spacer(),
              if (widget.currentRagSummary != null && widget.currentRagSummary!.isNotEmpty)
                IconButton(
                  tooltip: isRu ? 'Очистить RAG-выжимку' : 'Clear RAG summary',
                  icon: const Icon(Icons.delete_outline, size: 17, color: Tg.textDim),
                  splashRadius: 16,
                  onPressed: () {
                    widget.onSummaryUpdated(null, 0, null);
                    ContactDossierStore.instance.updateRagSummary(widget.chat.id, '', 0);
                  },
                ),
            ],
          ),

          if (widget.currentRagSummary != null && widget.currentRagSummary!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF00C48C).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF00C48C).withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle_outline, size: 13, color: Color(0xFF00C48C)),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          widget.currentRagDate != null
                              ? (isRu
                                  ? 'RAG-выжимка активна (сжато ${widget.currentRagCount} сообщ., в ${widget.currentRagDate!.hour.toString().padLeft(2, "0")}:${widget.currentRagDate!.minute.toString().padLeft(2, "0")})'
                                  : 'Active RAG summary (${widget.currentRagCount} msgs, at ${widget.currentRagDate!.hour.toString().padLeft(2, "0")}:${widget.currentRagDate!.minute.toString().padLeft(2, "0")})')
                              : (isRu ? 'RAG-выжимка активна (сжато ${widget.currentRagCount} сообщ.)' : 'Active RAG summary (${widget.currentRagCount} msgs)'),
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF00C48C)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    widget.currentRagSummary!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10.5, color: Tg.textDim, height: 1.25),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
