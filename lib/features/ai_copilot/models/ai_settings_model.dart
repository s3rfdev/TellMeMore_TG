import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../core/utils/session_paths.dart';

class AiSettings {
  AiSettings({
    this.provider = 'Google Gemini',
    this.model = 'gemini-3.5-flash-lite',
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

  Map<String, dynamic> toJson() => {
        'provider': provider,
        'model': model,
        'contextMessageCount': contextMessageCount,
        'contextCompression': contextCompression,
        'compressionMode': compressionMode,
        'compressionVolumeThreshold': compressionVolumeThreshold,
        'compressionKeepRawCount': compressionKeepRawCount,
        'sandwichContextEnabled': sandwichContextEnabled,
        'voiceProvider': voiceProvider,
        'openAiKey': openAiKey,
        'geminiKey': geminiKey,
        'zaiKey': zaiKey,
        'anthropicKey': anthropicKey,
        'deepgramKey': deepgramKey,
        'ollamaUrl': ollamaUrl,
        'autoDetectVoiceLang': autoDetectVoiceLang,
        'cacheTranscriptions': cacheTranscriptions,
        'cachedAudioCount': cachedAudioCount,
        'cachedAudioSizeBytes': cachedAudioSizeBytes,
        'autoPilotEnabled': autoPilotEnabled,
        'autoPilotDirectSend': autoPilotDirectSend,
        'autoPilotReadIncoming': autoPilotReadIncoming,
        'autoPilotToneMatching': autoPilotToneMatching,
      };

  factory AiSettings.fromJson(Map<String, dynamic> json) {
    final d = AiSettings();
    return AiSettings(
      provider: json['provider'] as String? ?? d.provider,
      model: json['model'] as String? ?? d.model,
      contextMessageCount: json['contextMessageCount'] as int? ?? d.contextMessageCount,
      contextCompression: json['contextCompression'] as bool? ?? d.contextCompression,
      compressionMode: json['compressionMode'] as String? ?? d.compressionMode,
      compressionVolumeThreshold:
          json['compressionVolumeThreshold'] as int? ?? d.compressionVolumeThreshold,
      compressionKeepRawCount:
          json['compressionKeepRawCount'] as int? ?? d.compressionKeepRawCount,
      sandwichContextEnabled:
          json['sandwichContextEnabled'] as bool? ?? d.sandwichContextEnabled,
      voiceProvider: json['voiceProvider'] as String? ?? d.voiceProvider,
      openAiKey: json['openAiKey'] as String? ?? d.openAiKey,
      geminiKey: json['geminiKey'] as String? ?? d.geminiKey,
      zaiKey: json['zaiKey'] as String? ?? d.zaiKey,
      anthropicKey: json['anthropicKey'] as String? ?? d.anthropicKey,
      deepgramKey: json['deepgramKey'] as String? ?? d.deepgramKey,
      ollamaUrl: json['ollamaUrl'] as String? ?? d.ollamaUrl,
      autoDetectVoiceLang: json['autoDetectVoiceLang'] as bool? ?? d.autoDetectVoiceLang,
      cacheTranscriptions: json['cacheTranscriptions'] as bool? ?? d.cacheTranscriptions,
      cachedAudioCount: json['cachedAudioCount'] as int? ?? d.cachedAudioCount,
      cachedAudioSizeBytes: json['cachedAudioSizeBytes'] as int? ?? d.cachedAudioSizeBytes,
      autoPilotEnabled: json['autoPilotEnabled'] as bool? ?? d.autoPilotEnabled,
      autoPilotDirectSend: json['autoPilotDirectSend'] as bool? ?? d.autoPilotDirectSend,
      autoPilotReadIncoming: json['autoPilotReadIncoming'] as bool? ?? d.autoPilotReadIncoming,
      autoPilotToneMatching: json['autoPilotToneMatching'] as bool? ?? d.autoPilotToneMatching,
    );
  }
}

class AiSettingsStore {
  AiSettingsStore._() {
    settings.addListener(() {
      saveToDisk();
    });
    _initFuture = _loadFromDisk();
  }
  static final AiSettingsStore instance = AiSettingsStore._();

  late final Future<void> _initFuture;
  Future<void> init() => _initFuture;

  final ValueNotifier<AiSettings> settings = ValueNotifier<AiSettings>(AiSettings());

  bool _isLoading = false;
  bool _isSaving = false;
  bool _hasPendingSave = false;

  Future<void> _loadFromDisk() async {
    try {
      _isLoading = true;
      final base = await SessionPaths.getAppStorageDirectory();
      final file = File('$base/ai_settings.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final data = jsonDecode(content);
          if (data is Map<String, dynamic>) {
            settings.value = AiSettings.fromJson(data);
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading AI settings: $e');
    } finally {
      _isLoading = false;
    }
  }

  Future<void> saveToDisk() async {
    if (_isLoading) return;
    if (_isSaving) {
      _hasPendingSave = true;
      return;
    }
    _isSaving = true;
    try {
      final base = await SessionPaths.getAppStorageDirectory();
      final file = File('$base/ai_settings.json');
      final tempFile = File('$base/ai_settings_${DateTime.now().microsecondsSinceEpoch}.tmp');
      await tempFile.writeAsString(jsonEncode(settings.value.toJson()), encoding: utf8, flush: true);
      if (await tempFile.exists()) {
        await tempFile.rename(file.path);
      }
    } catch (e) {
      debugPrint('Error saving AI settings: $e');
    } finally {
      _isSaving = false;
      if (_hasPendingSave) {
        _hasPendingSave = false;
        saveToDisk();
      }
    }
  }
}
