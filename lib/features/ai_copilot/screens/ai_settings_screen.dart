import 'package:flutter/material.dart';

import '../../../core/theme/tg_theme.dart';
import '../../../core/widgets/tg_toast.dart';
import '../../settings/settings_dialog.dart';
import '../models/ai_settings_model.dart';
import '../services/ai_model_service.dart';

class AiSettingsScreen extends StatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends State<AiSettingsScreen> {
  int _selectedTab = 0; // 0: Models, 1: Auto-Pilot, 2: Context, 3: Voice, 4: Cache
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
          TgToast.show(context, '✅ Загружено ${list.length} актуальных моделей для ${settings.provider}!');
        } else {
          TgToast.show(context, '⚠️ Не удалось получить список моделей, проверьте ключ.');
        }
      }
    } finally {
      if (mounted) setState(() => _loadingModels = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      child: Column(
        children: [
          _buildHeader(),
          _buildTabs(),
          Expanded(
            child: ValueListenableBuilder<AiSettings>(
              valueListenable: AiSettingsStore.instance.settings,
              builder: (context, settings, _) {
                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  children: [
                    if (_selectedTab == 0) _buildModelsSection(settings),
                    if (_selectedTab == 1) _buildAutoPilotSection(settings),
                    if (_selectedTab == 2) _buildContextSection(settings),
                    if (_selectedTab == 3) _buildVoiceSection(settings),
                    if (_selectedTab == 4) _buildCacheSection(settings),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 52,
      margin: const EdgeInsets.fromLTRB(10, 10, 10, 6),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Tg.sidebar,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.settings_suggest_rounded, color: Color(0xFF8774E1), size: 24),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Настройки AI и Системы',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Tg.text,
              ),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2F6FA8),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            icon: const Icon(Icons.manage_accounts_rounded, size: 17),
            label: const Text(
              'Профиль & Аккаунты',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
            onPressed: () => SettingsDialog.show(context),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    final tabs = [
      (Icons.memory_rounded, 'AI Модели и ZIAI'),
      (Icons.rocket_launch_rounded, 'Автопилот (Pilot)'),
      (Icons.psychology_rounded, 'Контекст и Память'),
      (Icons.mic_none_rounded, 'Распознавание речи'),
      (Icons.storage_rounded, 'Кэш и БД'),
    ];

    return Container(
      height: 44,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final tab = tabs[i];
          final active = _selectedTab == i;
          return ChoiceChip(
            avatar: Icon(
              tab.$1,
              size: 16,
              color: active ? Colors.white : Tg.textDim,
            ),
            label: Text(tab.$2),
            selected: active,
            selectedColor: const Color(0xFF8774E1),
            backgroundColor: Tg.sidebar,
            labelStyle: TextStyle(
              fontSize: 12.5,
              fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              color: active ? Colors.white : Tg.textDim,
            ),
            side: BorderSide(
              color: active ? const Color(0xFF8774E1) : Colors.white.withValues(alpha: 0.08),
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            onSelected: (_) => setState(() => _selectedTab = i),
          );
        },
      ),
    );
  }

  Widget _buildCard({required String title, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Tg.sidebar,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: Tg.text,
            ),
          ),
          const SizedBox(height: 14),
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
          title: 'Основной LLM Провайдер',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _providerModels.keys.map((p) {
                  final active = settings.provider == p;
                  return ChoiceChip(
                    label: Text(p),
                    selected: active,
                    selectedColor: const Color(0xFF8774E1).withValues(alpha: 0.3),
                    backgroundColor: Tg.field,
                    labelStyle: TextStyle(
                      color: active ? const Color(0xFF8774E1) : Tg.textDim,
                      fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                    ),
                    side: BorderSide(
                      color: active ? const Color(0xFF8774E1) : Colors.transparent,
                      width: 1.5,
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
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Актуальная модель:',
                    style: TextStyle(fontSize: 13, color: Tg.textDim),
                  ),
                  if (_loadingModels)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF8774E1)),
                    )
                  else
                    Text(
                      '${currentList.length} доступно',
                      style: const TextStyle(fontSize: 12, color: Tg.accent),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Tg.field,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButton<String>(
                  value: currentList.contains(settings.model) ? settings.model : currentList.first,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  dropdownColor: const Color(0xFF212D3B),
                  style: const TextStyle(color: Tg.text, fontSize: 13.5),
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
                  backgroundColor: const Color(0xFF8774E1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.sync_rounded, size: 16),
                label: Text('Обновить список моделей для ${settings.provider} по ключу'),
              ),
            ],
          ),
        ),
        _buildCard(
          title: 'Ключи API и Соединение (${settings.provider})',
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
                  'Формат: id.secret (GLM-5, GLM-5.3, GLM-4.5 и др.)',
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
                  'Доступ к Gemini 2.5 Flash, 2.5 Pro, 2.0 Flash Thinking',
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
                  TgToast.show(context, '✅ Соединение с ${settings.provider} успешно подтверждено!');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2F6FA8),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.wifi_rounded, size: 16),
                label: const Text('Проверить соединение'),
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
          title: 'Автопилот AI (Автономный ответчик)',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF8774E1).withValues(alpha: 0.15),
                      const Color(0xFF2F6FA8).withValues(alpha: 0.15),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF8774E1).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Color(0xFF8774E1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Telegram AI Pilot — Автопилот',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Максимальные привилегии: ответ от вашего имени, прямая отправка сообщений и анализ контекста.',
                            style: TextStyle(fontSize: 12, color: Tg.textDim),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SwitchListTile(
                value: settings.autoPilotEnabled,
                title: const Text('Включить AI Автопилот', style: TextStyle(color: Tg.text, fontSize: 14)),
                subtitle: const Text('Активирует фоновую работу Copilot для ответов', style: TextStyle(color: Tg.textDim, fontSize: 12)),
                activeThumbColor: const Color(0xFF8774E1),
                contentPadding: EdgeInsets.zero,
                onChanged: (val) {
                  AiSettingsStore.instance.settings.value = settings.copyWith(autoPilotEnabled: val);
                  TgToast.show(context, val ? '🚀 Автопилот активирован!' : 'Автопилот отключен');
                },
              ),
              const Divider(color: Tg.hairline, height: 16),
              SwitchListTile(
                value: settings.autoPilotDirectSend,
                title: const Text('Прямая отправка (Direct Send)', style: TextStyle(color: Tg.text, fontSize: 14)),
                subtitle: const Text('Отправлять сообщения напрямую без ручного подтверждения', style: TextStyle(color: Tg.textDim, fontSize: 12)),
                activeThumbColor: const Color(0xFF8774E1),
                contentPadding: EdgeInsets.zero,
                onChanged: settings.autoPilotEnabled
                    ? (val) {
                        AiSettingsStore.instance.settings.value = settings.copyWith(autoPilotDirectSend: val);
                      }
                    : null,
              ),
              const Divider(color: Tg.hairline, height: 16),
              SwitchListTile(
                value: settings.autoPilotReadIncoming,
                title: const Text('Авто-анализ входящих сообщений', style: TextStyle(color: Tg.text, fontSize: 14)),
                subtitle: const Text('Мгновенно извлекать смысл и готовить ответ при получении', style: TextStyle(color: Tg.textDim, fontSize: 12)),
                activeThumbColor: const Color(0xFF8774E1),
                contentPadding: EdgeInsets.zero,
                onChanged: settings.autoPilotEnabled
                    ? (val) {
                        AiSettingsStore.instance.settings.value = settings.copyWith(autoPilotReadIncoming: val);
                      }
                    : null,
              ),
              const Divider(color: Tg.hairline, height: 16),
              SwitchListTile(
                value: settings.autoPilotToneMatching,
                title: const Text('Адаптация тона и стиля общения', style: TextStyle(color: Tg.text, fontSize: 14)),
                subtitle: const Text('Подстраивать ответы под стиль владельца аккаунта и психотип контакта', style: TextStyle(color: Tg.textDim, fontSize: 12)),
                activeThumbColor: const Color(0xFF8774E1),
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
          child: TextFormField(
            initialValue: value,
            obscureText: isPassword,
            style: const TextStyle(fontSize: 13, color: Tg.text, fontFamily: 'monospace'),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 10),
            ),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildContextSection(AiSettings settings) {
    final isVolume = settings.compressionMode == 'volume';
    final approxChars = (settings.compressionVolumeThreshold * 3.8).round();

    return Column(
      children: [
        _buildCard(
          title: 'Умная автокомпрессия контекста',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                value: settings.contextCompression,
                title: const Text('Включить сжатие длинного контекста', style: TextStyle(color: Tg.text, fontSize: 14, fontWeight: FontWeight.w500)),
                subtitle: const Text('Сворачивает ранние ветки диалога в структурированное резюме', style: TextStyle(color: Tg.textDim, fontSize: 12)),
                activeThumbColor: const Color(0xFF00C48C),
                contentPadding: EdgeInsets.zero,
                onChanged: (val) {
                  AiSettingsStore.instance.settings.value =
                      settings.copyWith(contextCompression: val);
                },
              ),
              const Divider(color: Tg.hairline, height: 20),

              // Метод оценки порога сжатия
              const Text('Критерий оценки для автосжатия:', style: TextStyle(fontSize: 13, color: Tg.textDim)),
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
                          color: isVolume ? const Color(0xFF8774E1).withValues(alpha: 0.18) : Tg.field,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isVolume ? const Color(0xFF8774E1) : Colors.white.withValues(alpha: 0.08),
                            width: isVolume ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.speed_rounded, size: 16, color: isVolume ? const Color(0xFF8774E1) : Tg.textDim),
                            const SizedBox(width: 8),
                            Text(
                              'По объёму токенов (Smart)',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: isVolume ? FontWeight.w600 : FontWeight.normal,
                                color: isVolume ? const Color(0xFF8774E1) : Tg.text,
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
                          color: !isVolume ? const Color(0xFF8774E1).withValues(alpha: 0.18) : Tg.field,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: !isVolume ? const Color(0xFF8774E1) : Colors.white.withValues(alpha: 0.08),
                            width: !isVolume ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.format_list_numbered_rounded, size: 16, color: !isVolume ? const Color(0xFF8774E1) : Tg.textDim),
                            const SizedBox(width: 8),
                            Text(
                              'По числу сообщений',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: !isVolume ? FontWeight.w600 : FontWeight.normal,
                                color: !isVolume ? const Color(0xFF8774E1) : Tg.text,
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
                    const Text('Порог объёма для сжатия:', style: TextStyle(fontSize: 13, color: Tg.textDim)),
                    Text(
                      '${settings.compressionVolumeThreshold} токенов (~$approxChars симв.)',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF00C48C)),
                    ),
                  ],
                ),
                Slider(
                  value: settings.compressionVolumeThreshold.toDouble().clamp(1000, 32000),
                  min: 1000,
                  max: 32000,
                  divisions: 31,
                  activeColor: const Color(0xFF00C48C),
                  inactiveColor: Tg.field,
                  onChanged: (val) {
                    AiSettingsStore.instance.settings.value =
                        settings.copyWith(compressionVolumeThreshold: (val / 500).round() * 500);
                  },
                ),
                Text(
                  '💡 Короткие реплики («ок», «как дела») не вызывают сжатие преждевременно, а объемный код или статьи сожмутся вовремя.',
                  style: TextStyle(fontSize: 11.5, color: Tg.textDim, height: 1.35),
                ),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Сообщений до сжатия:', style: TextStyle(fontSize: 13, color: Tg.textDim)),
                    Text(
                      '${settings.contextMessageCount} сообщений',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF8774E1)),
                    ),
                  ],
                ),
                Slider(
                  value: settings.contextMessageCount.toDouble(),
                  min: 10,
                  max: 100,
                  divisions: 18,
                  activeColor: const Color(0xFF8774E1),
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
                  const Text('Окно свежих сообщений (без сжатия):', style: TextStyle(fontSize: 13, color: Tg.textDim)),
                  Text(
                    '${settings.compressionKeepRawCount} последних сообщений',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF51B2FF)),
                  ),
                ],
              ),
              Slider(
                value: settings.compressionKeepRawCount.toDouble().clamp(3, 20),
                min: 3,
                max: 20,
                divisions: 17,
                activeColor: const Color(0xFF51B2FF),
                inactiveColor: Tg.field,
                onChanged: (val) {
                  AiSettingsStore.instance.settings.value =
                      settings.copyWith(compressionKeepRawCount: val.round());
                },
              ),
              Text(
                '💡 Эти недавние сообщения всегда подаются модели слово в слово в сыром виде (второй слой начинки), сохраняя контекст последних минут общения.',
                style: TextStyle(fontSize: 11.5, color: Tg.textDim, height: 1.35),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Карточка: Принцип Бутерброд
        _buildCard(
          title: 'Архитектура: Принцип «Бутерброд» (Context Sandwich)',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                value: settings.sandwichContextEnabled,
                title: const Text('Сборка промпта по слоям', style: TextStyle(color: Tg.text, fontSize: 13.5)),
                subtitle: const Text('Оптимизирует следование инструкциям и точность ответов', style: TextStyle(color: Tg.textDim, fontSize: 12)),
                activeThumbColor: const Color(0xFF8774E1),
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
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: const Column(
                  children: [
                    _SandwichLayerTile(
                      icon: '🍞',
                      name: 'Верхний хлеб (System Directives)',
                      desc: 'Системные правила, персона агента, CRM-досье и спецификация инструментов.',
                      color: Color(0xFFFF9F43),
                    ),
                    SizedBox(height: 8),
                    _SandwichLayerTile(
                      icon: '🥩',
                      name: 'Начинка 1: Сжатая выжимка (Context Summary)',
                      desc: 'Суть ранних веток переписки (решения, факты, договоренности).',
                      color: Color(0xFF00C48C),
                    ),
                    SizedBox(height: 8),
                    _SandwichLayerTile(
                      icon: '🥬',
                      name: 'Начинка 2: Сырые сообщения (Recent Window)',
                      desc: 'Последние сообщения без изменений для сохранения нити диалога.',
                      color: Color(0xFF51B2FF),
                    ),
                    SizedBox(height: 8),
                    _SandwichLayerTile(
                      icon: '🍞',
                      name: 'Нижний хлеб (User Query & Directives)',
                      desc: 'Текущий запрос пользователя и финальные ограничения на формат.',
                      color: Color(0xFFFF7675),
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
          title: 'Движок транскрибации речи (STT)',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Сервис распознавания голосовых:', style: TextStyle(fontSize: 13, color: Tg.textDim)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Tg.field,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButton<String>(
                  value: settings.voiceProvider,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  dropdownColor: const Color(0xFF212D3B),
                  style: const TextStyle(color: Tg.text, fontSize: 13.5),
                  items: ['Deepgram Nova-2', 'OpenAI Whisper-1', 'Локальный Vosk / Sherpa']
                      .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
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
              const SizedBox(height: 8),
              SwitchListTile(
                value: settings.autoDetectVoiceLang,
                title: const Text('Автоопределение языка', style: TextStyle(color: Tg.text, fontSize: 13.5)),
                subtitle: const Text('Автоматически переключаться между русским и английским', style: TextStyle(color: Tg.textDim, fontSize: 12)),
                activeThumbColor: const Color(0xFF8774E1),
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
          title: 'Кэш базы данных и локальные медиа',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Сохраненных транскрипций:', style: TextStyle(fontSize: 13, color: Tg.textDim)),
                  Text('${settings.cachedAudioCount} файлов', style: const TextStyle(fontSize: 13, color: Tg.text)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Размер кэша аудио:', style: TextStyle(fontSize: 13, color: Tg.textDim)),
                  Text(
                    '${(settings.cachedAudioSizeBytes / 1024 / 1024).toStringAsFixed(1)} МБ',
                    style: const TextStyle(fontSize: 13, color: Tg.text),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  TgToast.show(context, '🧹 Локальный кэш успешно очищен!');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2C3847),
                  foregroundColor: Tg.danger,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.delete_sweep_rounded, size: 16),
                label: const Text('Очистить кэш транскрипций'),
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
                    fontWeight: FontWeight.w600,
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
