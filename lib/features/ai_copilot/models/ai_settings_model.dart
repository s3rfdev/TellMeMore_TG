import 'package:flutter/foundation.dart';

class AiSettings {
  AiSettings({
    this.provider = 'OpenAI',
    this.model = 'GPT-4o',
    this.contextMessageCount = 30,
    this.contextCompression = true,
    this.voiceProvider = 'Deepgram Nova-2',
    this.openAiKey = '',
    this.geminiKey = 'AIzaSy...7b41',
    this.anthropicKey = '',
    this.deepgramKey = 'dg_sec_...99ff',
    this.ollamaUrl = 'http://localhost:11434',
    this.autoDetectVoiceLang = true,
    this.cacheTranscriptions = true,
    this.cachedAudioCount = 48,
    this.cachedAudioSizeBytes = 12400000,
  });

  String provider;
  String model;
  int contextMessageCount;
  bool contextCompression;
  String voiceProvider;
  String openAiKey;
  String geminiKey;
  String anthropicKey;
  String deepgramKey;
  String ollamaUrl;
  bool autoDetectVoiceLang;
  bool cacheTranscriptions;
  int cachedAudioCount;
  int cachedAudioSizeBytes;

  AiSettings copyWith({
    String? provider,
    String? model,
    int? contextMessageCount,
    bool? contextCompression,
    String? voiceProvider,
    String? openAiKey,
    String? geminiKey,
    String? anthropicKey,
    String? deepgramKey,
    String? ollamaUrl,
    bool? autoDetectVoiceLang,
    bool? cacheTranscriptions,
    int? cachedAudioCount,
    int? cachedAudioSizeBytes,
  }) {
    return AiSettings(
      provider: provider ?? this.provider,
      model: model ?? this.model,
      contextMessageCount: contextMessageCount ?? this.contextMessageCount,
      contextCompression: contextCompression ?? this.contextCompression,
      voiceProvider: voiceProvider ?? this.voiceProvider,
      openAiKey: openAiKey ?? this.openAiKey,
      geminiKey: geminiKey ?? this.geminiKey,
      anthropicKey: anthropicKey ?? this.anthropicKey,
      deepgramKey: deepgramKey ?? this.deepgramKey,
      ollamaUrl: ollamaUrl ?? this.ollamaUrl,
      autoDetectVoiceLang: autoDetectVoiceLang ?? this.autoDetectVoiceLang,
      cacheTranscriptions: cacheTranscriptions ?? this.cacheTranscriptions,
      cachedAudioCount: cachedAudioCount ?? this.cachedAudioCount,
      cachedAudioSizeBytes: cachedAudioSizeBytes ?? this.cachedAudioSizeBytes,
    );
  }
}

class AiSettingsStore {
  AiSettingsStore._();
  static final AiSettingsStore instance = AiSettingsStore._();

  final ValueNotifier<AiSettings> settings = ValueNotifier<AiSettings>(AiSettings());
}
