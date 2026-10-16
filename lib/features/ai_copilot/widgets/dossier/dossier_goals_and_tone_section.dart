import 'package:flutter/material.dart';

import '../../../../core/localization/app_locale.dart';
import '../../../../core/theme/tg_theme.dart';
import '../../models/contact_dossier.dart';

/// Секции настройки целей общения, рекомендуемого тона и психотипа контакта.
class DossierGoalsAndToneSection extends StatelessWidget {
  const DossierGoalsAndToneSection({
    super.key,
    required this.dossier,
    required this.goalController,
    required this.psychotypeController,
    required this.onGoalChanged,
    required this.onToneChanged,
    required this.onPsychotypeChanged,
  });

  final ContactDossier dossier;
  final TextEditingController goalController;
  final TextEditingController psychotypeController;
  final ValueChanged<String> onGoalChanged;
  final ValueChanged<String> onToneChanged;
  final ValueChanged<String> onPsychotypeChanged;

  static const List<String> goalPresetKeys = [
    'ai_goal_preset_partnership',
    'ai_goal_preset_friendship',
    'ai_goal_preset_sales',
    'ai_goal_preset_work',
    'ai_goal_preset_clarify',
    'ai_goal_preset_defense',
  ];

  static const List<String> tonePresetKeys = [
    'ai_tone_preset_business',
    'ai_tone_preset_friendly',
    'ai_tone_preset_warm',
    'ai_tone_preset_strict',
    'ai_tone_preset_cautious',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- ЦЕЛЬ ОБЩЕНИЯ ---
        Row(
          children: [
            const Icon(Icons.flag_outlined, size: 14, color: Tg.accent),
            const SizedBox(width: 6),
            Text(
              tr('ai_goal_title'),
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Tg.text),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Wrap(
          spacing: 5,
          runSpacing: 4,
          children: goalPresetKeys.map((key) {
            final label = tr(key);
            final active = dossier.goal == label || dossier.goal == key;
            return ChoiceChip(
              label: Text(label),
              selected: active,
              selectedColor: Tg.accent.withValues(alpha: 0.2),
              backgroundColor: Tg.field,
              visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              labelStyle: TextStyle(
                fontSize: 10,
                color: active ? Tg.accent : Tg.textDim,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              ),
              side: BorderSide(
                color: active ? Tg.accent : Tg.borderSubtle,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
              onSelected: (selected) {
                if (selected) {
                  goalController.text = label;
                  onGoalChanged(label);
                }
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 5),
        Container(
          decoration: BoxDecoration(
            color: Tg.field,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
          child: TextField(
            controller: goalController,
            minLines: 1,
            maxLines: 7,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            onChanged: onGoalChanged,
            style: const TextStyle(fontSize: 11, color: Tg.text, height: 1.3),
            decoration: InputDecoration(
              hintText: tr('ai_goal_hint'),
              hintStyle: const TextStyle(fontSize: 10.5, color: Tg.textFaint),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 4),
            ),
          ),
        ),
        const SizedBox(height: 11),

        // --- ТОН ОБЩЕНИЯ ---
        Row(
          children: [
            const Icon(Icons.record_voice_over_outlined, size: 14, color: Tg.accent),
            const SizedBox(width: 6),
            Text(
              tr('ai_tone_title'),
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Tg.text),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Wrap(
          spacing: 5,
          runSpacing: 4,
          children: tonePresetKeys.map((key) {
            final label = tr(key);
            final active = dossier.tone == label || dossier.tone == key;
            return ChoiceChip(
              label: Text(label),
              selected: active,
              selectedColor: Tg.accent.withValues(alpha: 0.2),
              backgroundColor: Tg.field,
              visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              labelStyle: TextStyle(
                fontSize: 10,
                color: active ? Tg.accent : Tg.textDim,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              ),
              side: BorderSide(
                color: active ? Tg.accent : Colors.transparent,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
              onSelected: (selected) {
                if (selected) {
                  onToneChanged(label);
                }
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 11),

        // --- ПСИХОТИП ---
        Row(
          children: [
            const Icon(Icons.fingerprint_rounded, size: 14, color: Tg.accent),
            const SizedBox(width: 6),
            Text(
              tr('ai_psychotype_title'),
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Tg.text),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Tg.field,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
          child: TextField(
            controller: psychotypeController,
            minLines: 1,
            maxLines: 7,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            onChanged: onPsychotypeChanged,
            style: const TextStyle(fontSize: 11, color: Tg.text, height: 1.3),
            decoration: InputDecoration(
              hintText: tr('ai_psychotype_hint'),
              hintStyle: const TextStyle(fontSize: 10.5, color: Tg.textFaint),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 4),
            ),
          ),
        ),
      ],
    );
  }
}
