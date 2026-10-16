import 'package:flutter/material.dart';

import '../../../../core/theme/tg_theme.dart';

/// Раскрывающийся блок настроек или секции досье контакта.
class CollapsibleDossierCard extends StatefulWidget {
  const CollapsibleDossierCard({
    super.key,
    required this.title,
    required this.icon,
    this.badge,
    this.subtitle,
    required this.initiallyExpanded,
    required this.child,
  });

  final String title;
  final IconData icon;
  final String? badge;
  final String? subtitle;
  final bool initiallyExpanded;
  final Widget child;

  @override
  State<CollapsibleDossierCard> createState() => _CollapsibleDossierCardState();
}

class _CollapsibleDossierCardState extends State<CollapsibleDossierCard> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Tg.field,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              child: Row(
                children: [
                  Icon(widget.icon, size: 15, color: Tg.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                widget.title,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: Tg.text,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (widget.badge != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Tg.accent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  widget.badge!,
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    color: Tg.accent,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (widget.subtitle != null) ...[
                          const SizedBox(height: 1),
                          Text(
                            widget.subtitle!,
                            style: const TextStyle(fontSize: 10.5, color: Tg.textDim),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    size: 17,
                    color: Tg.textDim,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1, color: Tg.hairline),
            Padding(
              padding: const EdgeInsets.all(11),
              child: widget.child,
            ),
          ],
        ],
      ),
    );
  }
}
