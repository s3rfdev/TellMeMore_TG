import 'package:flutter/material.dart';

import '../../../../core/localization/app_locale.dart';
import '../../../../core/theme/tg_theme.dart';
import '../../models/ai_settings_model.dart';
import 'settings_card.dart';
import 'settings_key_input.dart';

/// Раздел настроек голосового движка (STT провайдер, Deepgram API ключ, автоопределение языка).
class AiVoiceSection extends StatelessWidget {
  const AiVoiceSection({
    super.key,
    required this.settings,
  });

  final AiSettings settings;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SettingsCard(
          title: tr('ai_voice_engine'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr('ai_voice_service'), style: Tg.caption),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Tg.field,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Tg.border),
                ),
                child: DropdownButton<String>(
                  value: settings.voiceProvider,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  dropdownColor: Tg.field,
                  style: const TextStyle(color: Tg.text, fontSize: 13),
                  items: [
                    'Google Gemini STT (Multimodal)',
                    'Deepgram Nova-2',
                    'OpenAI Whisper-1',
                    'Vosk / Sherpa',
                  ].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      AiSettingsStore.instance.settings.value =
                          settings.copyWith(voiceProvider: val);
                    }
                  },
                ),
              ),
              const SizedBox(height: 14),
              SettingsKeyInput(
                label: 'Deepgram API Key',
                value: settings.deepgramKey,
                onChanged: (v) {
                  settings.deepgramKey = v;
                  AiSettingsStore.instance.settings.value = settings.copyWith(deepgramKey: v);
                },
              ),
              const SizedBox(height: 6),
              const Text(
                'Deepgram Nova-2 (40 hex-символов). При ошибке 401 или отсутствии токена автоматически используется Gemini STT.',
                style: TextStyle(fontSize: 11.5, color: Tg.textFaint),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                value: settings.autoDetectVoiceLang,
                title: Text(tr('ai_voice_autodetect'), style: const TextStyle(color: Tg.text, fontSize: 13, fontWeight: Tg.fontRegular)),
                subtitle: Text(tr('ai_voice_autodetect_sub'), style: Tg.caption),
                activeThumbColor: Tg.accent,
                activeTrackColor: Tg.accentDark.withValues(alpha: 0.5),
                contentPadding: EdgeInsets.zero,
                onChanged: (val) {
                  AiSettingsStore.instance.settings.value =
                      settings.copyWith(autoDetectVoiceLang: val);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
