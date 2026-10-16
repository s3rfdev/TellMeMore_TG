import 'package:flutter/material.dart';

import '../../../../core/localization/app_locale.dart';
import '../../../../core/theme/tg_theme.dart';
import '../../models/ai_settings_model.dart';
import 'settings_card.dart';

/// Раздел настроек сжатия контекста диалогов и параметров архитектуры Sandwich Prompt.
class AiContextSection extends StatelessWidget {
  const AiContextSection({
    super.key,
    required this.settings,
  });

  final AiSettings settings;

  @override
  Widget build(BuildContext context) {
    final isVolume = settings.compressionMode == 'volume';
    final approxChars = (settings.compressionVolumeThreshold * 3.8).round();

    return Column(
      children: [
        SettingsCard(
          title: tr('ai_compression_section'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                value: settings.contextCompression,
                title: Text(tr('ai_compression_enable'), style: const TextStyle(color: Tg.text, fontSize: 14, fontWeight: FontWeight.w500)),
                subtitle: Text(tr('ai_compression_enable_sub'), style: const TextStyle(color: Tg.textDim, fontSize: 12)),
                activeThumbColor: const Color(0xFF00C48C),
                contentPadding: EdgeInsets.zero,
                onChanged: (val) {
                  AiSettingsStore.instance.settings.value =
                      settings.copyWith(contextCompression: val);
                },
              ),
              const Divider(color: Tg.hairline, height: 20),

              // Метод оценки порога сжатия
              Text(tr('ai_compression_criterion'), style: const TextStyle(fontSize: 13, color: Tg.textDim)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        AiSettingsStore.instance.settings.value =
                            settings.copyWith(compressionMode: 'volume');
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        decoration: BoxDecoration(
                          color: isVolume ? Tg.accentDark.withValues(alpha: 0.25) : Tg.field,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isVolume ? Tg.accent : Tg.border,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.speed_rounded, size: 16, color: isVolume ? Tg.accent : Tg.textDim),
                            const SizedBox(width: 8),
                            Text(
                              tr('ai_comp_volume_smart'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isVolume ? Tg.fontMedium : Tg.fontRegular,
                                color: isVolume ? Colors.white : Tg.text,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        AiSettingsStore.instance.settings.value =
                            settings.copyWith(compressionMode: 'message_count');
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        decoration: BoxDecoration(
                          color: !isVolume ? Tg.accentDark.withValues(alpha: 0.25) : Tg.field,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: !isVolume ? Tg.accent : Tg.border,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.format_list_numbered_rounded, size: 16, color: !isVolume ? Tg.accent : Tg.textDim),
                            const SizedBox(width: 8),
                            Text(
                              tr('ai_comp_msg_count'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: !isVolume ? Tg.fontMedium : Tg.fontRegular,
                                color: !isVolume ? Colors.white : Tg.text,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (isVolume) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        tr('ai_comp_volume_threshold'),
                        style: Tg.caption,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tr('ai_comp_volume_tokens', {
                        'tokens': settings.compressionVolumeThreshold.toString(),
                        'chars': approxChars.toString(),
                      }),
                      style: const TextStyle(fontSize: 12, fontWeight: Tg.fontMedium, color: Tg.accent),
                    ),
                  ],
                ),
                Slider(
                  value: settings.compressionVolumeThreshold.toDouble().clamp(1000, 32000),
                  min: 1000,
                  max: 32000,
                  divisions: 31,
                  activeColor: Tg.accent,
                  inactiveColor: Tg.field,
                  onChanged: (val) {
                    AiSettingsStore.instance.settings.value =
                        settings.copyWith(compressionVolumeThreshold: (val / 500).round() * 500);
                  },
                ),
                Text(
                  tr('ai_comp_volume_tip'),
                  style: const TextStyle(fontSize: 11.5, color: Tg.textDim, height: 1.35),
                ),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        tr('ai_comp_msg_threshold'),
                        style: Tg.caption,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tr('ai_comp_msgs_count', {'count': settings.contextMessageCount.toString()}),
                      style: const TextStyle(fontSize: 12, fontWeight: Tg.fontMedium, color: Tg.accent),
                    ),
                  ],
                ),
                Slider(
                  value: settings.contextMessageCount.toDouble(),
                  min: 10,
                  max: 100,
                  divisions: 18,
                  activeColor: Tg.accent,
                  inactiveColor: Tg.field,
                  onChanged: (val) {
                    AiSettingsStore.instance.settings.value =
                        settings.copyWith(contextMessageCount: val.round());
                  },
                ),
              ],

              const SizedBox(height: 14),
              const Divider(color: Tg.hairline, height: 20),

              // Окно свежих сырых сообщений
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      tr('ai_comp_raw_window'),
                      style: const TextStyle(fontSize: 13, color: Tg.textDim),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    tr('ai_comp_raw_count', {'count': settings.compressionKeepRawCount.toString()}),
                    style: const TextStyle(fontSize: 12.5, fontWeight: Tg.fontMedium, color: Tg.accent),
                  ),
                ],
              ),
              Slider(
                value: settings.compressionKeepRawCount.toDouble().clamp(3, 20),
                min: 3,
                max: 20,
                divisions: 17,
                activeColor: Tg.accent,
                inactiveColor: Tg.field,
                onChanged: (val) {
                  AiSettingsStore.instance.settings.value =
                      settings.copyWith(compressionKeepRawCount: val.round());
                },
              ),
              Text(
                tr('ai_comp_raw_tip'),
                style: const TextStyle(fontSize: 11.5, color: Tg.textDim, height: 1.35),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Карточка: Принцип Бутерброд
        SettingsCard(
          title: tr('ai_sandwich_architecture'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                value: settings.sandwichContextEnabled,
                title: Text(tr('ai_sandwich_layers'), style: const TextStyle(color: Tg.text, fontSize: 13, fontWeight: Tg.fontRegular)),
                subtitle: Text(tr('ai_sandwich_layers_sub'), style: Tg.caption),
                activeThumbColor: Tg.accent,
                activeTrackColor: Tg.accentDark.withValues(alpha: 0.5),
                contentPadding: EdgeInsets.zero,
                onChanged: (val) {
                  AiSettingsStore.instance.settings.value =
                      settings.copyWith(sandwichContextEnabled: val);
                },
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Tg.field,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Tg.border),
                ),
                child: Column(
                  children: [
                    SandwichLayerTile(
                      icon: '🍞',
                      name: tr('ai_sandwich_top_bread'),
                      desc: tr('ai_sandwich_top_desc'),
                      color: const Color(0xFFFF9F43),
                    ),
                    const SizedBox(height: 8),
                    SandwichLayerTile(
                      icon: '🥩',
                      name: tr('ai_sandwich_filling1'),
                      desc: tr('ai_sandwich_filling1_desc'),
                      color: const Color(0xFF00C48C),
                    ),
                    const SizedBox(height: 8),
                    SandwichLayerTile(
                      icon: '🥬',
                      name: tr('ai_sandwich_filling2'),
                      desc: tr('ai_sandwich_filling2_desc'),
                      color: Tg.accent,
                    ),
                    const SizedBox(height: 8),
                    SandwichLayerTile(
                      icon: '🍞',
                      name: tr('ai_sandwich_bottom_bread'),
                      desc: tr('ai_sandwich_bottom_desc'),
                      color: const Color(0xFFFF7675),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Визуальная плашка слоя Sandwich-контекста (хлеб, начинка, RAG факты).
class SandwichLayerTile extends StatelessWidget {
  const SandwichLayerTile({
    super.key,
    required this.icon,
    required this.name,
    required this.desc,
    required this.color,
  });

  final String icon;
  final String name;
  final String desc;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: Tg.fontMedium,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Tg.textDim,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
