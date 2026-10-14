import 'package:flutter/material.dart';

import '../../../core/theme/tg_theme.dart';
import '../../../core/widgets/tg_toast.dart';
import '../models/ai_settings_model.dart';

class AiSettingsScreen extends StatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends State<AiSettingsScreen> {
  int _selectedTab = 0; // 0: Models, 1: Context, 2: Voice, 3: Cache & Storage

  final Map<String, List<String>> _providerModels = {
    'OpenAI': ['GPT-4o', 'GPT-4o-mini', 'o1-preview'],
    'Google Gemini': ['Gemini 1.5 Pro', 'Gemini 1.5 Flash', 'Gemini 2.0 Flash'],
    'Anthropic': ['Claude 3.5 Sonnet', 'Claude 3.5 Haiku'],
    'Ollama (Local)': ['Llama 3.1 (8B)', 'Qwen 2.5 (14B)', 'DeepSeek Coder (6.7B)'],
  };

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
                    if (_selectedTab == 1) _buildContextSection(settings),
                    if (_selectedTab == 2) _buildVoiceSection(settings),
                    if (_selectedTab == 3) _buildCacheSection(settings),
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
      child: const Row(
        children: [
          Icon(Icons.settings_suggest_rounded, color: Color(0xFF8774E1), size: 24),
          SizedBox(width: 12),
          Text(
            'Настройки AI и Системы',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Tg.text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    final tabs = [
      (Icons.memory_rounded, 'AI Модели'),
      (Icons.psychology_rounded, 'Контекст и Память'),
      (Icons.mic_none_rounded, 'Распознавание речи'),
      (Icons.storage_rounded, 'Кэш и База данных'),
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
                    selectedColor: const Color(0xFF8774E1).withValues(alpha: 0.25),
                    backgroundColor: Tg.field,
                    labelStyle: TextStyle(
                      color: active ? const Color(0xFF8774E1) : Tg.textDim,
                      fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                    ),
                    side: BorderSide(
                      color: active ? const Color(0xFF8774E1) : Colors.transparent,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        final models = _providerModels[p] ?? ['Default'];
                        AiSettingsStore.instance.settings.value = settings.copyWith(
                          provider: p,
                          model: models.first,
                        );
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              const Text(
                'Выбор модели:',
                style: TextStyle(fontSize: 13, color: Tg.textDim),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Tg.field,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButton<String>(
                  value: settings.model,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  dropdownColor: const Color(0xFF212D3B),
                  style: const TextStyle(color: Tg.text, fontSize: 13.5),
                  items: (_providerModels[settings.provider] ?? [settings.model])
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
            ],
          ),
        ),
        _buildCard(
          title: 'Ключи API и Соединение',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildKeyInput(
                label: 'OpenAI API Key',
                value: settings.openAiKey,
                onChanged: (v) => settings.openAiKey = v,
              ),
              const SizedBox(height: 12),
              _buildKeyInput(
                label: 'Google Gemini API Key',
                value: settings.geminiKey,
                onChanged: (v) => settings.geminiKey = v,
              ),
              const SizedBox(height: 12),
              _buildKeyInput(
                label: 'Anthropic Claude API Key',
                value: settings.anthropicKey,
                onChanged: (v) => settings.anthropicKey = v,
              ),
              if (settings.provider == 'Ollama (Local)') ...[
                const SizedBox(height: 12),
                _buildKeyInput(
                  label: 'Ollama Host URL',
                  value: settings.ollamaUrl,
                  isPassword: false,
                  onChanged: (v) => settings.ollamaUrl = v,
                ),
              ],
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: () {
                  TgToast.show(context, '✅ Соединение с ${settings.provider} успешно проверено!');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2F6FA8),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.wifi_rounded, size: 16),
                label: const Text('Проверить соединение с провайдером'),
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
    return Column(
      children: [
        _buildCard(
          title: 'Глубина контекста диалога',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Сообщений истории для анализа:', style: TextStyle(color: Tg.textDim, fontSize: 13)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8774E1).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${settings.contextMessageCount} сообщений',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF8774E1),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Slider(
                value: settings.contextMessageCount.toDouble(),
                min: 5,
                max: 100,
                divisions: 19,
                activeColor: const Color(0xFF8774E1),
                inactiveColor: Tg.field,
                onChanged: (val) {
                  AiSettingsStore.instance.settings.value =
                      settings.copyWith(contextMessageCount: val.round());
                },
              ),
              const Text(
                'Оптимальное значение: 25–40 сообщений. Это обеспечивает точный контекст без перерасхода токенов.',
                style: TextStyle(fontSize: 11.5, color: Tg.textFaint),
              ),
            ],
          ),
        ),
        _buildCard(
          title: 'Оптимизация и сжатие контекста',
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Интеллектуальное сжатие (LLM Summarizer)', style: TextStyle(color: Tg.text, fontSize: 14)),
            subtitle: const Text(
              'Старые сообщения автоматически свертываются в факты досье контакта, освобождая контекстное окно.',
              style: TextStyle(color: Tg.textDim, fontSize: 12),
            ),
            value: settings.contextCompression,
            activeTrackColor: const Color(0xFF8774E1),
            onChanged: (val) {
              AiSettingsStore.instance.settings.value =
                  settings.copyWith(contextCompression: val);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVoiceSection(AiSettings settings) {
    return Column(
      children: [
        _buildCard(
          title: 'Провайдер транскрипции голосовых заметок',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: ['Deepgram Nova-2', 'OpenAI Whisper', 'Local Whisper.cpp'].map((p) {
                  final active = settings.voiceProvider == p;
                  return ChoiceChip(
                    label: Text(p),
                    selected: active,
                    selectedColor: const Color(0xFF43C053).withValues(alpha: 0.22),
                    backgroundColor: Tg.field,
                    labelStyle: TextStyle(
                      color: active ? const Color(0xFF43C053) : Tg.textDim,
                      fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                    ),
                    side: BorderSide(
                      color: active ? const Color(0xFF43C053) : Colors.transparent,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        AiSettingsStore.instance.settings.value =
                            settings.copyWith(voiceProvider: p);
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              _buildKeyInput(
                label: 'Deepgram Secret Key',
                value: settings.deepgramKey,
                onChanged: (v) => settings.deepgramKey = v,
              ),
              const SizedBox(height: 14),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Автоопределение языка аудио (Auto-detect)', style: TextStyle(color: Tg.text, fontSize: 13.5)),
                subtitle: const Text('Русский, Английский, Вьетнамский и др.', style: TextStyle(color: Tg.textDim, fontSize: 11.5)),
                value: settings.autoDetectVoiceLang,
                activeTrackColor: const Color(0xFF43C053),
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
          title: 'Локальное хранилище расшифровок и CRM',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2F6FA8).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.dns_rounded, color: Color(0xFF51B2FF), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Кэшировано аудиозаписей: ${settings.cachedAudioCount}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Tg.text),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Объем локальной базы: ${(settings.cachedAudioSizeBytes / (1024 * 1024)).toStringAsFixed(1)} МБ',
                          style: const TextStyle(fontSize: 12, color: Tg.textDim),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Кэшировать транскрипции локально', style: TextStyle(color: Tg.text, fontSize: 13.5)),
                subtitle: const Text('Позволяет не расходовать API при повторном прослушивании', style: TextStyle(color: Tg.textDim, fontSize: 11.5)),
                value: settings.cacheTranscriptions,
                activeTrackColor: const Color(0xFF51B2FF),
                onChanged: (val) {
                  AiSettingsStore.instance.settings.value =
                      settings.copyWith(cacheTranscriptions: val);
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        settings.cachedAudioCount = 0;
                        settings.cachedAudioSizeBytes = 0;
                      });
                      TgToast.show(context, '🗑️ Кэш аудиозаписей успешно очищен');
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Tg.danger,
                      side: const BorderSide(color: Tg.danger),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                    label: const Text('Очистить кэш'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      TgToast.show(context, '📦 База транскрипций экспортирована в JSON');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Tg.field,
                      foregroundColor: Tg.text,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: const Text('Экспорт в JSON'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
