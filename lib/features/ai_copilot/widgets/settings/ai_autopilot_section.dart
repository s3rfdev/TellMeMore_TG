import 'package:flutter/material.dart';

import '../../../../core/localization/app_locale.dart';
import '../../../../core/theme/tg_theme.dart';
import '../../../../core/widgets/tg_toast.dart';
import '../../models/ai_settings_model.dart';
import 'settings_card.dart';

/// Раздел настроек автопилота AI (прямая отправка, фоновое чтение входящих, подстройка тона).
class AiAutopilotSection extends StatelessWidget {
  const AiAutopilotSection({
    super.key,
    required this.settings,
  });

  final AiSettings settings;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SettingsCard(
          title: tr('ai_autopilot_section'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Tg.field,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Tg.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Tg.accentDark,
                        shape: BoxShape.circle,
                        border: Border.all(color: Tg.border),
                      ),
                      child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr('ai_autopilot_header'),
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: Tg.fontMedium,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            tr('ai_autopilot_banner_sub'),
                            style: Tg.caption,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                value: settings.autoPilotEnabled,
                title: Text(tr('ai_enable_autopilot'), style: const TextStyle(color: Tg.text, fontSize: 13, fontWeight: Tg.fontRegular)),
                subtitle: Text(tr('ai_enable_autopilot_sub'), style: Tg.caption),
                activeThumbColor: Tg.accent,
                activeTrackColor: Tg.accentDark.withValues(alpha: 0.5),
                contentPadding: EdgeInsets.zero,
                onChanged: (val) {
                  AiSettingsStore.instance.settings.value = settings.copyWith(autoPilotEnabled: val);
                  TgToast.show(context, val ? tr('ai_autopilot_enabled_toast') : tr('ai_autopilot_disabled_toast'));
                },
              ),
              const Divider(color: Tg.hairline, height: 14),
              SwitchListTile(
                value: settings.autoPilotDirectSend,
                title: Text(tr('ai_direct_send'), style: const TextStyle(color: Tg.text, fontSize: 13, fontWeight: Tg.fontRegular)),
                subtitle: Text(tr('ai_direct_send_sub'), style: Tg.caption),
                activeThumbColor: Tg.accent,
                activeTrackColor: Tg.accentDark.withValues(alpha: 0.5),
                contentPadding: EdgeInsets.zero,
                onChanged: settings.autoPilotEnabled
                    ? (val) {
                        AiSettingsStore.instance.settings.value = settings.copyWith(autoPilotDirectSend: val);
                      }
                    : null,
              ),
              const Divider(color: Tg.hairline, height: 14),
              SwitchListTile(
                value: settings.autoPilotReadIncoming,
                title: Text(tr('ai_read_incoming'), style: const TextStyle(color: Tg.text, fontSize: 13, fontWeight: Tg.fontRegular)),
                subtitle: Text(tr('ai_read_incoming_sub'), style: Tg.caption),
                activeThumbColor: Tg.accent,
                activeTrackColor: Tg.accentDark.withValues(alpha: 0.5),
                contentPadding: EdgeInsets.zero,
                onChanged: settings.autoPilotEnabled
                    ? (val) {
                        AiSettingsStore.instance.settings.value = settings.copyWith(autoPilotReadIncoming: val);
                      }
                    : null,
              ),
              const Divider(color: Tg.hairline, height: 14),
              SwitchListTile(
                value: settings.autoPilotToneMatching,
                title: Text(tr('ai_tone_matching'), style: const TextStyle(color: Tg.text, fontSize: 13, fontWeight: Tg.fontRegular)),
                subtitle: Text(tr('ai_tone_matching_sub'), style: Tg.caption),
                activeThumbColor: Tg.accent,
                activeTrackColor: Tg.accentDark.withValues(alpha: 0.5),
                contentPadding: EdgeInsets.zero,
                onChanged: settings.autoPilotEnabled
                    ? (val) {
                        AiSettingsStore.instance.settings.value = settings.copyWith(autoPilotToneMatching: val);
                      }
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
