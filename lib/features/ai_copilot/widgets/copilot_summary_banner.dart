import 'package:flutter/material.dart';

import '../../../core/theme/tg_theme.dart';
import '../models/copilot_session.dart';

/// Баннер сжатия контекста диалога (Summary Banner) с возможностью разворачивания текста сводки.
class CopilotSummaryBanner extends StatefulWidget {
  const CopilotSummaryBanner({
    super.key,
    required this.session,
  });

  final CopilotSession session;

  @override
  State<CopilotSummaryBanner> createState() => _CopilotSummaryBannerState();
}

class _CopilotSummaryBannerState extends State<CopilotSummaryBanner> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.session.contextSummary == null || widget.session.contextSummary!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF00C48C).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00C48C).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.compress, size: 16, color: Color(0xFF00C48C)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '🗜️ Контекст сжат: Сводка истории (${widget.session.summaryTokenCount} токенов)',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF00C48C),
                      ),
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 18,
                    color: const Color(0xFF00C48C),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Text(
                widget.session.contextSummary!,
                style: const TextStyle(fontSize: 11.5, color: Tg.textDim, height: 1.4),
              ),
            ),
        ],
      ),
    );
  }
}
