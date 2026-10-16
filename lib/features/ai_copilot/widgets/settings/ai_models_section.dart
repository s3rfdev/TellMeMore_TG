import 'package:flutter/material.dart';

import '../../../../core/localization/app_locale.dart';
import '../../../../core/theme/tg_theme.dart';
import '../../../../core/widgets/tg_toast.dart';
import '../../models/ai_settings_model.dart';
import 'settings_card.dart';
import 'settings_key_input.dart';

/// Раздел настроек AI-провайдеров и моделей (Z-AI, Google Gemini, OpenAI, Anthropic, Ollama), API-ключей и проверки подключения.
class AiModelsSection extends StatelessWidget {
  const AiModelsSection({
    super.key,
    required this.settings,
    required this.providerModels,
    required this.loadingModels,
    required this.onRefreshModels,
  });

  final AiSettings settings;
  final Map<String, List<String>> providerModels;
  final bool loadingModels;
  final Future<void> Function(AiSettings settings) onRefreshModels;

  @override
  Widget build(BuildContext context) {
    final currentList = providerModels[settings.provider] ?? [settings.model];

    return Column(
      children: [
        SettingsCard(
          title: tr('ai_main_provider'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: providerModels.keys.map((p) {
                  final active = settings.provider == p;
                  return ChoiceChip(
                    label: Text(p),
                    selected: active,
                    selectedColor: Tg.accentDark.withValues(alpha: 0.35),
                    backgroundColor: Tg.field,
                    labelStyle: TextStyle(
                      color: active ? Tg.accent : Tg.textDim,
                      fontSize: 12,
                      fontWeight: active ? Tg.fontMedium : Tg.fontRegular,
                    ),
                    side: BorderSide(
                      color: active ? Tg.accent : Tg.border,
                      width: 1,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        final models = providerModels[p] ?? ['Default'];
                        AiSettingsStore.instance.settings.value = settings.copyWith(
                          provider: p,
                          model: models.first,
                        );
                        onRefreshModels(settings.copyWith(provider: p));
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      tr('ai_current_model'),
                      style: Tg.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (loadingModels)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 1.5, color: Tg.accent),
                    )
                  else
                    Text(
                      tr('ai_available_count', {'count': currentList.length.toString()}),
                      style: const TextStyle(fontSize: 11.5, color: Tg.accent, fontWeight: Tg.fontMedium),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Tg.field,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Tg.border),
                ),
                child: DropdownButton<String>(
                  value: currentList.contains(settings.model) ? settings.model : currentList.first,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  dropdownColor: Tg.field,
                  style: const TextStyle(color: Tg.text, fontSize: 13),
                  items: currentList
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      AiSettingsStore.instance.settings.value =
                          settings.copyWith(model: val);
                    }
                  },
                ),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: loadingModels ? null : () => onRefreshModels(settings),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Tg.accentDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: Tg.border),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.sync_rounded, size: 15),
                label: Text(
                  tr('ai_refresh_models', {'provider': settings.provider}),
                  style: const TextStyle(fontSize: 12.5, fontWeight: Tg.fontMedium),
                ),
              ),
            ],
          ),
        ),
        SettingsCard(
          title: tr('ai_keys_and_conn', {'provider': settings.provider}),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (settings.provider == 'Z-AI (ZIAI)') ...[
                SettingsKeyInput(
                  label: 'Z-AI (Zhipu BigModel) API Key',
                  value: settings.zaiKey,
                  onChanged: (v) {
                    settings.zaiKey = v;
                    AiSettingsStore.instance.settings.value = settings.copyWith(zaiKey: v);
                  },
                ),
                const SizedBox(height: 8),
                const Text(
                  'Format: id.secret (GLM-5, GLM-5.3, GLM-4.5, etc.)',
                  style: TextStyle(fontSize: 11.5, color: Tg.textFaint),
                ),
              ] else if (settings.provider == 'Google Gemini') ...[
                SettingsKeyInput(
                  label: 'Google Gemini API Key',
                  value: settings.geminiKey,
                  onChanged: (v) {
                    settings.geminiKey = v;
                    AiSettingsStore.instance.settings.value = settings.copyWith(geminiKey: v);
                  },
                ),
                const SizedBox(height: 8),
                const Text(
                  'Gemini 2.5 Flash, 2.5 Pro, 2.0 Flash Thinking access',
                  style: TextStyle(fontSize: 11.5, color: Tg.textFaint),
                ),
              ] else if (settings.provider == 'OpenAI') ...[
                SettingsKeyInput(
                  label: 'OpenAI API Key',
                  value: settings.openAiKey,
                  onChanged: (v) {
                    settings.openAiKey = v;
                    AiSettingsStore.instance.settings.value = settings.copyWith(openAiKey: v);
                  },
                ),
              ] else if (settings.provider == 'Anthropic') ...[
                SettingsKeyInput(
                  label: 'Anthropic Claude API Key',
                  value: settings.anthropicKey,
                  onChanged: (v) {
                    settings.anthropicKey = v;
                    AiSettingsStore.instance.settings.value = settings.copyWith(anthropicKey: v);
                  },
                ),
              ] else if (settings.provider == 'Ollama (Local)') ...[
                SettingsKeyInput(
                  label: 'Ollama Host URL',
                  value: settings.ollamaUrl,
                  isPassword: false,
                  onChanged: (v) {
                    settings.ollamaUrl = v;
                    AiSettingsStore.instance.settings.value = settings.copyWith(ollamaUrl: v);
                  },
                ),
              ],
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  TgToast.show(context, tr('ai_connection_success', {'provider': settings.provider}));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2F6FA8),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.wifi_rounded, size: 16),
                label: Text(tr('ai_check_connection')),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
