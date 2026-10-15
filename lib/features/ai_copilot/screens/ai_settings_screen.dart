import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/localization/app_locale.dart';
import '../../../core/theme/tg_theme.dart';
import '../../../core/widgets/tg_toast.dart';
import '../../../state/app_state.dart';
import '../../profile/widgets/profile_pane.dart';
import '../models/ai_settings_model.dart';
import '../services/ai_model_service.dart';

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
              _buildHeader(activeSection),
              Expanded(
                child: activeSection == SettingsSection.profile
                    ? const ProfilePane()
                    : ValueListenableBuilder<AiSettings>(
                        valueListenable: AiSettingsStore.instance.settings,
                        builder: (context, settings, _) {
                          return ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            children: [
                              if (activeSection == SettingsSection.general) _buildModelsSection(settings),
                              if (activeSection == SettingsSection.autopilot) _buildAutoPilotSection(settings),
                              if (activeSection == SettingsSection.context) _buildContextSection(settings),
                              if (activeSection == SettingsSection.voice) _buildVoiceSection(settings),
                              if (activeSection == SettingsSection.cache) _buildCacheSection(settings),
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

  Widget _buildHeader(SettingsSection section) {
    IconData icon;
    String title;
    switch (section) {
      case SettingsSection.profile:
        icon = Icons.person_outline_rounded;
        title = tr('settings_profile');
        break;
      case SettingsSection.general:
        icon = Icons.tune_rounded;
        title = tr('settings_general');
        break;
      case SettingsSection.autopilot:
        icon = Icons.smart_toy_outlined;
        title = tr('settings_autopilot');
        break;
      case SettingsSection.context:
        icon = Icons.psychology_outlined;
        title = tr('settings_context');
        break;
      case SettingsSection.voice:
        icon = Icons.mic_none_rounded;
        title = tr('settings_voice');
        break;
      case SettingsSection.cache:
        icon = Icons.storage_rounded;
        title = tr('settings_cache');
        break;
    }

    return Container(
      height: 48,
      margin: const EdgeInsets.fromLTRB(10, 10, 10, 6),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Tg.sidebar,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Tg.border),
      ),
      child: Row(
        children: [
          if (widget.showBack) ...[
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: Tg.textDim),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              splashRadius: 18,
              tooltip: tr('back'),
              onPressed: widget.onBack,
            ),
            const SizedBox(width: 4),
          ],
          Icon(icon, color: Tg.accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: Tg.fontMedium,
                color: Tg.text,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (section == SettingsSection.general)
            Tooltip(
              message: tr('ai_check_connection'),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: _loadingModels ? null : () => _refreshModels(AiSettingsStore.instance.settings.value),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Tg.card,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Tg.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _loadingModels
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Tg.accent))
                          : const Icon(Icons.refresh_rounded, size: 16, color: Tg.accent),
                      if (MediaQuery.sizeOf(context).width > 480) ...[
                        const SizedBox(width: 6),
                        Text(
                          tr('ai_check_connection'),
                          style: const TextStyle(fontSize: 12, fontWeight: Tg.fontMedium, color: Tg.accent),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCard({required String title, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Tg.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Tg.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Tg.title,
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildModelsSection(AiSettings settings) {
    final currentList = _providerModels[settings.provider] ?? [settings.model];

    return Column(
      children: [
        _buildCard(
          title: tr('ai_main_provider'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _providerModels.keys.map((p) {
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
                        final models = _providerModels[p] ?? ['Default'];
                        AiSettingsStore.instance.settings.value = settings.copyWith(
                            provider: p,
                            model: models.first,
                        );
                        _refreshModels(settings.copyWith(provider: p));
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
                  if (_loadingModels)
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
                onPressed: _loadingModels ? null : () => _refreshModels(settings),
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
        _buildCard(
          title: tr('ai_keys_and_conn', {'provider': settings.provider}),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (settings.provider == 'Z-AI (ZIAI)') ...[
                _buildKeyInput(
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
                _buildKeyInput(
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
                _buildKeyInput(
                  label: 'OpenAI API Key',
                  value: settings.openAiKey,
                  onChanged: (v) {
                    settings.openAiKey = v;
                    AiSettingsStore.instance.settings.value = settings.copyWith(openAiKey: v);
                  },
                ),
              ] else if (settings.provider == 'Anthropic') ...[
                _buildKeyInput(
                  label: 'Anthropic Claude API Key',
                  value: settings.anthropicKey,
                  onChanged: (v) {
                    settings.anthropicKey = v;
                    AiSettingsStore.instance.settings.value = settings.copyWith(anthropicKey: v);
                  },
                ),
              ] else if (settings.provider == 'Ollama (Local)') ...[
                _buildKeyInput(
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

  Widget _buildAutoPilotSection(AiSettings settings) {
    return Column(
      children: [
        _buildCard(
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

  Widget _buildKeyInput({
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
    bool isPassword = true,
  }) {
    bool obscure = isPassword;
    String currentValue = value;

    return StatefulBuilder(
      builder: (context, setInputState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12.5, color: Tg.textDim)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Tg.field,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: value,
                      obscureText: obscure,
                      style: const TextStyle(fontSize: 13, color: Tg.text, fontFamily: 'monospace'),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                      onChanged: (v) {
                        currentValue = v;
                        onChanged(v);
                      },
                    ),
                  ),
                  if (isPassword)
                    IconButton(
                      icon: Icon(
                        obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        size: 18,
                        color: Tg.textDim,
                      ),
                      onPressed: () => setInputState(() => obscure = !obscure),
                      tooltip: obscure
                          ? (I18n.instance.isRu ? 'Показать ключ' : 'Show key')
                          : (I18n.instance.isRu ? 'Скрыть ключ' : 'Hide key'),
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                      splashRadius: 16,
                    ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 16, color: Tg.textDim),
                    onPressed: () {
                      if (currentValue.isNotEmpty) {
                        Clipboard.setData(ClipboardData(text: currentValue));
                        TgToast.show(
                          context,
                          I18n.instance.isRu ? 'Ключ скопирован в буфер' : 'Key copied to clipboard',
                          icon: Icons.check_circle_rounded,
                        );
                      }
                    },
                    tooltip: I18n.instance.isRu ? 'Скопировать ключ' : 'Copy key',
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                    splashRadius: 16,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildContextSection(AiSettings settings) {
    final isVolume = settings.compressionMode == 'volume';
    final approxChars = (settings.compressionVolumeThreshold * 3.8).round();

    return Column(
      children: [
        _buildCard(
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
        _buildCard(
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
                    _SandwichLayerTile(
                      icon: '🍞',
                      name: tr('ai_sandwich_top_bread'),
                      desc: tr('ai_sandwich_top_desc'),
                      color: const Color(0xFFFF9F43),
                    ),
                    const SizedBox(height: 8),
                    _SandwichLayerTile(
                      icon: '🥩',
                      name: tr('ai_sandwich_filling1'),
                      desc: tr('ai_sandwich_filling1_desc'),
                      color: const Color(0xFF00C48C),
                    ),
                    const SizedBox(height: 8),
                    _SandwichLayerTile(
                      icon: '🥬',
                      name: tr('ai_sandwich_filling2'),
                      desc: tr('ai_sandwich_filling2_desc'),
                      color: Tg.accent,
                    ),
                    const SizedBox(height: 8),
                    _SandwichLayerTile(
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

  Widget _buildVoiceSection(AiSettings settings) {
    return Column(
      children: [
        _buildCard(
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
              _buildKeyInput(
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

  Widget _buildCacheSection(AiSettings settings) {
    return Column(
      children: [
        _buildCard(
          title: tr('ai_cache_title'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(tr('ai_cache_saved_transcripts'), style: const TextStyle(fontSize: 13, color: Tg.textDim)),
                  Text(tr('ai_cache_files_count', {'count': settings.cachedAudioCount.toString()}), style: const TextStyle(fontSize: 13, color: Tg.text)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(tr('ai_cache_audio_size'), style: const TextStyle(fontSize: 13, color: Tg.textDim)),
                  Text(
                    '${(settings.cachedAudioSizeBytes / 1024 / 1024).toStringAsFixed(1)} MB',
                    style: const TextStyle(fontSize: 13, color: Tg.text),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  TgToast.show(context, tr('ai_cache_cleared_toast'));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2C3847),
                  foregroundColor: Tg.danger,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.delete_sweep_rounded, size: 16),
                label: Text(tr('ai_cache_clear_btn')),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SandwichLayerTile extends StatelessWidget {
  const _SandwichLayerTile({
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
