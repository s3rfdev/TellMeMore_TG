import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/ai_settings_model.dart';

/// Сервис анализа изображений (Gemini Vision) с персистентным кэшированием.
/// Анализирует фотографии один раз и кэширует краткое описание для контекста LLM.
class ImageDescriptionService {
  ImageDescriptionService._() {
    _loadCacheFromDisk();
  }
  static final ImageDescriptionService instance = ImageDescriptionService._();

  final Map<String, String> _cache = {};
  bool _isLoaded = false;

  /// Получить сохраненное описание по ID сообщения или пути к файлу
  String? getCachedDescription(dynamic idOrPath) {
    if (idOrPath == null) return null;
    return _cache[idOrPath.toString()];
  }

  /// Проверить, описано ли изображение
  bool hasDescription(dynamic idOrPath) {
    if (idOrPath == null) return false;
    final val = _cache[idOrPath.toString()];
    return val != null && val.trim().isNotEmpty;
  }

  /// Сохранить описание в память и на диск
  void saveDescription(dynamic idOrPath, String text) {
    if (idOrPath == null || text.trim().isEmpty) return;
    final key = idOrPath.toString();
    _cache[key] = text.trim();
    _persistCacheToDisk();
  }

  /// Проанализировать изображение через Gemini Vision
  Future<String?> describeImage({
    required String filePath,
    dynamic messageId,
    String? geminiApiKey,
  }) async {
    // 1. Проверяем кэш по ID
    if (messageId != null && hasDescription(messageId)) {
      return getCachedDescription(messageId);
    }

    // 2. Проверяем кэш по пути
    if (hasDescription(filePath)) {
      final cached = getCachedDescription(filePath);
      if (messageId != null && cached != null) saveDescription(messageId, cached);
      return cached;
    }

    final file = File(filePath);
    if (!file.existsSync() || file.lengthSync() == 0) {
      return null;
    }

    final settings = AiSettingsStore.instance.settings.value;
    final key = (geminiApiKey != null && geminiApiKey.isNotEmpty)
        ? geminiApiKey
        : settings.geminiKey;

    if (key.isEmpty) return null;

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);
    try {
      final ext = filePath.toLowerCase().split('.').last;
      String mime = 'image/jpeg';
      if (ext == 'png') {
        mime = 'image/png';
      } else if (ext == 'webp') {
        mime = 'image/webp';
      } else if (ext == 'gif') {
        mime = 'image/gif';
      }

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return null;
      final b64 = base64Encode(bytes);

      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent?key=$key',
      );
      final request = await client.postUrl(uri);
      request.headers.set('Content-Type', 'application/json; charset=utf-8');
      request.headers.set('User-Agent', 'TGAnswer-Desktop/1.0');

      final payload = {
        'contents': [
          {
            'parts': [
              {
                'inlineData': {
                  'mimeType': mime,
                  'data': b64,
                }
              },
              {
                'text':
                    'Опиши кратко суть этой фотографии в одном предложении (до 15 слов) на русском языке для контекста переписки. Верни только описание без вступительных слов, кавычек или точек в конце.'
              }
            ]
          }
        ]
      };

      request.add(utf8.encode(jsonEncode(payload)));
      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final candidates = json['candidates'] as List<dynamic>?;
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates.first['content'] as Map<String, dynamic>?;
          final parts = content?['parts'] as List<dynamic>?;
          if (parts != null && parts.isNotEmpty) {
            final text = parts.first['text'] as String?;
            if (text != null && text.trim().isNotEmpty) {
              final cleaned = text.trim();
              saveDescription(filePath, cleaned);
              if (messageId != null) saveDescription(messageId, cleaned);
              return cleaned;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[ImageDescriptionService] Vision error: $e');
    } finally {
      client.close();
    }
    return null;
  }

  Future<File?> _getCacheFile() async {
    try {
      final dir = await getApplicationSupportDirectory();
      return File('${dir.path}/image_descriptions_cache.json');
    } catch (_) {
      try {
        final temp = await getTemporaryDirectory();
        return File('${temp.path}/image_descriptions_cache.json');
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
      debugPrint('[ImageDescriptionService] Error loading cache: $e');
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
      debugPrint('[ImageDescriptionService] Error saving cache: $e');
    }
  }

  int get cachedCount => _cache.length;

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
