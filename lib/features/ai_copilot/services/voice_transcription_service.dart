import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/ai_settings_model.dart';

/// Сервис транскрибации голосовых сообщений (Deepgram Nova-2)
/// с персистентным кэшированием, исключающим повторные запросы.
class VoiceTranscriptionService {
  VoiceTranscriptionService._() {
    _loadCacheFromDisk();
  }
  static final VoiceTranscriptionService instance = VoiceTranscriptionService._();

  final Map<String, String> _cache = {};
  bool _isLoaded = false;

  /// Получить сохраненную транскрипцию по ID сообщения или пути к аудио
  String? getCachedTranscription(dynamic idOrPath) {
    if (idOrPath == null) return null;
    return _cache[idOrPath.toString()];
  }

  /// Проверить, есть ли уже распознанный текст
  bool hasTranscription(dynamic idOrPath) {
    if (idOrPath == null) return false;
    final val = _cache[idOrPath.toString()];
    return val != null && val.trim().isNotEmpty;
  }

  /// Записать транскрипцию в память и на диск
  void saveTranscription(dynamic idOrPath, String text) {
    if (idOrPath == null || text.trim().isEmpty) return;
    final key = idOrPath.toString();
    _cache[key] = text.trim();
    _persistCacheToDisk();
  }

  /// Транскрибировать голосовое сообщение с автокэшированием
  Future<String> transcribeVoiceFile({
    required String filePath,
    dynamic messageId,
    int durationSeconds = 0,
    String? deepgramApiKey,
  }) async {
    // 1. Проверяем кэш по ID
    if (messageId != null && hasTranscription(messageId)) {
      return getCachedTranscription(messageId)!;
    }

    // 2. Проверяем кэш по пути файла
    if (hasTranscription(filePath)) {
      final cached = getCachedTranscription(filePath)!;
      if (messageId != null) saveTranscription(messageId, cached);
      return cached;
    }

    final file = File(filePath);
    if (!file.existsSync() || file.lengthSync() == 0) {
      final fallback = durationSeconds > 0
          ? '[Голосовое сообщение ($durationSeconds сек)]'
          : '[Голосовое сообщение]';
      return fallback;
    }

    final settings = AiSettingsStore.instance.settings.value;
    final key = (deepgramApiKey != null && deepgramApiKey.isNotEmpty)
        ? deepgramApiKey
        : settings.deepgramKey;

    // 3. Отправляем в Deepgram Nova-2
    if (key.isNotEmpty) {
      try {
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 25);
        try {
          final uri = Uri.parse(
            'https://api.deepgram.com/v1/listen?model=nova-2&smart_format=true&detect_language=true',
          );
          final request = await client.postUrl(uri);
          request.headers.set('Authorization', 'Token $key');
          request.headers.set('Content-Type', 'audio/*');
          request.headers.set('User-Agent', 'TGAnswer-Desktop/1.0');

          final bytes = await file.readAsBytes();
          request.add(bytes);

          final response = await request.close();
          if (response.statusCode == 200) {
            final body = await response.transform(utf8.decoder).join();
            final json = jsonDecode(body) as Map<String, dynamic>;
            final results = json['results'] as Map<String, dynamic>?;
            final channels = results?['channels'] as List<dynamic>?;
            if (channels != null && channels.isNotEmpty) {
              final alternatives =
                  (channels.first as Map<String, dynamic>)['alternatives'] as List<dynamic>?;
              if (alternatives != null && alternatives.isNotEmpty) {
                final transcript =
                    (alternatives.first as Map<String, dynamic>)['transcript'] as String?;
                if (transcript != null && transcript.trim().isNotEmpty) {
                  final text = transcript.trim();
                  saveTranscription(filePath, text);
                  if (messageId != null) saveTranscription(messageId, text);
                  return text;
                }
              }
            }
          }
        } finally {
          client.close();
        }
      } catch (e) {
        debugPrint('[VoiceTranscriptionService] Deepgram error: $e');
      }
    }

    // 4. Локальный fallback, если Deepgram недоступен
    final fallback = durationSeconds > 0
        ? '[Голосовое сообщение ($durationSeconds сек)]'
        : '[Голосовое сообщение]';
    return fallback;
  }

  Future<File?> _getCacheFile() async {
    try {
      final dir = await getApplicationSupportDirectory();
      return File('${dir.path}/transcriptions_cache.json');
    } catch (_) {
      try {
        final temp = await getTemporaryDirectory();
        return File('${temp.path}/transcriptions_cache.json');
      } catch (_) {
        return null;
      }
    }
  }

  Future<void> _loadCacheFromDisk() async {
    if (_isLoaded) return;
    try {
      final file = await _getCacheFile();
      if (file != null && file.existsSync()) {
        final content = await file.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        for (final entry in json.entries) {
          if (entry.value is String) {
            _cache[entry.key] = entry.value as String;
          }
        }
      }
    } catch (e) {
      debugPrint('[VoiceTranscriptionService] Error loading cache: $e');
    } finally {
      _isLoaded = true;
    }
  }

  Future<void> _persistCacheToDisk() async {
    try {
      final file = await _getCacheFile();
      if (file != null) {
        await file.writeAsString(jsonEncode(_cache));
      }
    } catch (e) {
      debugPrint('[VoiceTranscriptionService] Error saving cache: $e');
    }
  }

  /// Общее число закэшированных транскрипций
  int get cachedCount => _cache.length;

  /// Очистить кэш
  Future<void> clearCache() async {
    _cache.clear();
    final file = await _getCacheFile();
    if (file != null && file.existsSync()) {
      try {
        await file.delete();
      } catch (_) {}
    }
  }
}
