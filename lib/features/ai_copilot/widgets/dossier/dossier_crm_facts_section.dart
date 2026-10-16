import 'package:flutter/material.dart';

import '../../../../core/localization/app_locale.dart';
import '../../../../core/theme/tg_theme.dart';
import '../../models/contact_dossier.dart';
import 'collapsible_dossier_card.dart';

/// Секция фактов о контакте (CRM Facts) с добавлением и удалением элементов.
class DossierCrmFactsSection extends StatelessWidget {
  const DossierCrmFactsSection({
    super.key,
    required this.dossier,
    required this.newFactController,
    required this.onAddFact,
    required this.onRemoveFact,
  });

  final ContactDossier dossier;
  final TextEditingController newFactController;
  final VoidCallback onAddFact;
  final ValueChanged<int> onRemoveFact;

  @override
  Widget build(BuildContext context) {
    return CollapsibleDossierCard(
      title: tr('ai_facts_title'),
      icon: Icons.checklist_rounded,
      badge: '${dossier.facts.length}',
      initiallyExpanded: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...dossier.facts.asMap().entries.map((entry) {
            final idx = entry.key;
            final fact = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                children: [
                  const Icon(Icons.circle, size: 5, color: Tg.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      fact,
                      style: const TextStyle(fontSize: 11.5, color: Tg.text),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 14, color: Tg.textFaint),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                    splashRadius: 12,
                    onPressed: () => onRemoveFact(idx),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 32,
                  decoration: BoxDecoration(
                    color: Tg.sidebar,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: TextField(
                    controller: newFactController,
                    style: const TextStyle(fontSize: 11.5, color: Tg.text),
                    decoration: InputDecoration(
                      hintText: tr('ai_facts_add_hint'),
                      hintStyle: const TextStyle(fontSize: 11, color: Tg.textFaint),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                    ),
                    onSubmitted: (_) => onAddFact(),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded, color: Tg.accent, size: 20),
                splashRadius: 16,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: onAddFact,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
