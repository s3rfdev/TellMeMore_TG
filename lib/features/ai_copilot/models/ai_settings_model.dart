import 'package:flutter/foundation.dart';

class AiSettings {
  AiSettings({
    this.provider = 'Z-AI (ZIAI)',
    this.model = 'glm-5',
    this.contextMessageCount = 30,
    this.contextCompression = true,
    this.compressionMode = 'volume',
    this.compressionVolumeThreshold = 4000,
    this.compressionKeepRawCount = 6,
    this.sandwichContextEnabled = true,
    this.voiceProvider = 'Deepgram Nova-2',
    this.openAiKey = '',
    this.geminiKey = '',
    this.zaiKey = '',
    this.anthropicKey = '',
    this.deepgramKey = '',
    this.ollamaUrl = 'http://localhost:11434',
    this.autoDetectVoiceLang = true,
    this.cacheTranscriptions = true,
    this.cachedAudioCount = 48,
    this.cachedAudioSizeBytes = 12400000,
    this.autoPilotEnabled = true,
    this.autoPilotDirectSend = true,
    this.autoPilotReadIncoming = true,
    this.autoPilotToneMatching = true,
  });

  String provider;
  String model;
  int contextMessageCount;
  bool contextCompression;
  String compressionMode; // 'volume' | 'message_count'
  int compressionVolumeThreshold; // tokens
  int compressionKeepRawCount; // raw messages retained in window
  bool sandwichContextEnabled;
  String voiceProvider;
  String openAiKey;
  String geminiKey;
  String zaiKey;
  String anthropicKey;
  String deepgramKey;
  String ollamaUrl;
  bool autoDetectVoiceLang;
  bool cacheTranscriptions;
  int cachedAudioCount;
  int cachedAudioSizeBytes;
  bool autoPilotEnabled;
  bool autoPilotDirectSend;
  bool autoPilotReadIncoming;
  bool autoPilotToneMatching;

  AiSettings copyWith({
    String? provider,
    String? model,
    int? contextMessageCount,
    bool? contextCompression,
    String? compressionMode,
    int? compressionVolumeThreshold,
    int? compressionKeepRawCount,
    bool? sandwichContextEnabled,
    String? voiceProvider,
    String? openAiKey,
    String? geminiKey,
    String? zaiKey,
    String? anthropicKey,
    String? deepgramKey,
    String? ollamaUrl,
    bool? autoDetectVoiceLang,
    bool? cacheTranscriptions,
    int? cachedAudioCount,
    int? cachedAudioSizeBytes,
    bool? autoPilotEnabled,
    bool? autoPilotDirectSend,
    bool? autoPilotReadIncoming,
    bool? autoPilotToneMatching,
  }) {
    return AiSettings(
      provider: provider ?? this.provider,
      model: model ?? this.model,
      contextMessageCount: contextMessageCount ?? this.contextMessageCount,
      contextCompression: contextCompression ?? this.contextCompression,
      compressionMode: compressionMode ?? this.compressionMode,
      compressionVolumeThreshold: compressionVolumeThreshold ?? this.compressionVolumeThreshold,
      compressionKeepRawCount: compressionKeepRawCount ?? this.compressionKeepRawCount,
      sandwichContextEnabled: sandwichContextEnabled ?? this.sandwichContextEnabled,
      voiceProvider: voiceProvider ?? this.voiceProvider,
      openAiKey: openAiKey ?? this.openAiKey,
      geminiKey: geminiKey ?? this.geminiKey,
      zaiKey: zaiKey ?? this.zaiKey,
      anthropicKey: anthropicKey ?? this.anthropicKey,
      deepgramKey: deepgramKey ?? this.deepgramKey,
      ollamaUrl: ollamaUrl ?? this.ollamaUrl,
      autoDetectVoiceLang: autoDetectVoiceLang ?? this.autoDetectVoiceLang,
      cacheTranscriptions: cacheTranscriptions ?? this.cacheTranscriptions,
      cachedAudioCount: cachedAudioCount ?? this.cachedAudioCount,
      cachedAudioSizeBytes: cachedAudioSizeBytes ?? this.cachedAudioSizeBytes,
      autoPilotEnabled: autoPilotEnabled ?? this.autoPilotEnabled,
      autoPilotDirectSend: autoPilotDirectSend ?? this.autoPilotDirectSend,
      autoPilotReadIncoming: autoPilotReadIncoming ?? this.autoPilotReadIncoming,
      autoPilotToneMatching: autoPilotToneMatching ?? this.autoPilotToneMatching,
    );
  }
}

class AiSettingsStore {
  AiSettingsStore._();
  static final AiSettingsStore instance = AiSettingsStore._();

  final ValueNotifier<AiSettings> settings = ValueNotifier<AiSettings>(AiSettings());
}
