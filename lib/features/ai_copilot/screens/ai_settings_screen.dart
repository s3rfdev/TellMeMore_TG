import 'package:flutter/material.dart';

import '../../../core/localization/app_locale.dart';
import '../../../core/widgets/tg_toast.dart';
import '../../../state/app_state.dart';
import '../../profile/widgets/profile_pane.dart';
import '../models/ai_settings_model.dart';
import '../services/ai_model_service.dart';
import '../widgets/settings/ai_autopilot_section.dart';
import '../widgets/settings/ai_cache_section.dart';
import '../widgets/settings/ai_context_section.dart';
import '../widgets/settings/ai_models_section.dart';
import '../widgets/settings/ai_voice_section.dart';
import '../widgets/settings/settings_header.dart';

/// Экран глобальных настроек приложения (AI модели, Автопилот, Контекст и Sandwich-архитектура, Голос, Кэш, Профиль).
class AiSettingsScreen extends StatefulWidget {
  const AiSettingsScreen({
    super.key,
    this.showBack = false,
    this.onBack,
  });

  final bool showBack;
  final VoidCallback? onBack;

  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends State<AiSettingsScreen> {
  bool _loadingModels = false;

  late final Map<String, List<String>> _providerModels;

  @override
  void initState() {
    super.initState();
    _providerModels = {
      'Z-AI (ZIAI)': List.from(AiModelService.fallbackZaiModels),
      'Google Gemini': List.from(AiModelService.fallbackGeminiModels),
      'OpenAI': List.from(AiModelService.openAiModels),
      'Anthropic': List.from(AiModelService.anthropicModels),
      'Ollama (Local)': List.from(AiModelService.ollamaModels),
    };

    // Auto-fetch live models for current provider on launch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchCurrentModelsSilently();
    });
  }

  Future<void> _fetchCurrentModelsSilently() async {
    final settings = AiSettingsStore.instance.settings.value;
    if (settings.provider == 'Z-AI (ZIAI)' && settings.zaiKey.isNotEmpty) {
      final list = await AiModelService.instance.fetchZaiModels(settings.zaiKey);
      if (mounted && list.isNotEmpty) {
        setState(() {
          _providerModels['Z-AI (ZIAI)'] = list;
          if (!list.contains(settings.model)) {
            AiSettingsStore.instance.settings.value = settings.copyWith(model: list.first);
          }
        });
      }
    } else if (settings.provider == 'Google Gemini' && settings.geminiKey.isNotEmpty) {
      final list = await AiModelService.instance.fetchGeminiModels(settings.geminiKey);
      if (mounted && list.isNotEmpty) {
        setState(() {
          _providerModels['Google Gemini'] = list;
          if (!list.contains(settings.model)) {
            AiSettingsStore.instance.settings.value = settings.copyWith(model: list.first);
          }
        });
      }
    }
  }

  Future<void> _refreshModels(AiSettings settings) async {
    setState(() => _loadingModels = true);
    try {
      List<String> list = [];
      if (settings.provider == 'Z-AI (ZIAI)') {
        list = await AiModelService.instance.fetchZaiModels(settings.zaiKey);
        _providerModels['Z-AI (ZIAI)'] = list;
      } else if (settings.provider == 'Google Gemini') {
        list = await AiModelService.instance.fetchGeminiModels(settings.geminiKey);
        _providerModels['Google Gemini'] = list;
      } else {
        list = _providerModels[settings.provider] ?? [];
      }

      if (mounted) {
        if (list.isNotEmpty) {
          final newModel = list.contains(settings.model) ? settings.model : list.first;
          AiSettingsStore.instance.settings.value = settings.copyWith(model: newModel);
          TgToast.show(context, tr('ai_models_loaded', {'count': list.length.toString(), 'provider': settings.provider}));
        } else {
          TgToast.show(context, tr('ai_models_failed'));
        }
      }
    } finally {
      if (mounted) setState(() => _loadingModels = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SettingsSection>(
      valueListenable: AppState.activeSettingsSection,
      builder: (context, activeSection, _) {
        return Container(
          color: Colors.transparent,
          child: Column(
            children: [
              SettingsHeader(
                section: activeSection,
                showBack: widget.showBack,
                onBack: widget.onBack,
                loadingModels: _loadingModels,
                onRefreshModels: () => _refreshModels(AiSettingsStore.instance.settings.value),
              ),
              Expanded(
                child: activeSection == SettingsSection.profile
                    ? const ProfilePane()
                    : ValueListenableBuilder<AiSettings>(
                        valueListenable: AiSettingsStore.instance.settings,
                        builder: (context, settings, _) {
                          return ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            children: [
                              if (activeSection == SettingsSection.general)
                                AiModelsSection(
                                  settings: settings,
                                  providerModels: _providerModels,
                                  loadingModels: _loadingModels,
                                  onRefreshModels: _refreshModels,
                                ),
                              if (activeSection == SettingsSection.autopilot)
                                AiAutopilotSection(settings: settings),
                              if (activeSection == SettingsSection.context)
                                AiContextSection(settings: settings),
                              if (activeSection == SettingsSection.voice)
                                AiVoiceSection(settings: settings),
                              if (activeSection == SettingsSection.cache)
                                AiCacheSection(settings: settings),
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
