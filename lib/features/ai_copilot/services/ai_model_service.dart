import 'dart:convert';
import 'dart:io';

class AiModelService {
  AiModelService._();
  static final AiModelService instance = AiModelService._();

  static const List<String> fallbackZaiModels = [
    'glm-5',
    'glm-5.3',
    'glm-5.3-flash',
    'glm-5.2',
    'glm-5.1',
    'glm-5-turbo',
    'glm-4.7',
    'glm-4.6',
    'glm-4.5',
    'glm-4.5-air',
  ];

  static const List<String> fallbackGeminiModels = [
    'gemini-2.5-flash',
    'gemini-2.5-pro',
    'gemini-2.0-flash',
    'gemini-1.5-pro',
    'gemini-2.0-flash-thinking-exp',
  ];

  static const List<String> openAiModels = [
    'GPT-4o',
    'GPT-4o-mini',
    'o1-preview',
    'o3-mini',
  ];

  static const List<String> anthropicModels = [
    'Claude 3.5 Sonnet',
    'Claude 3.5 Haiku',
    'Claude 3.7 Sonnet',
  ];

  static const List<String> ollamaModels = [
    'Llama 3.3 (70B)',
    'Llama 3.1 (8B)',
    'Qwen 2.5 (14B)',
    'DeepSeek Coder (6.7B)',
  ];

  Future<List<String>> fetchZaiModels(String apiKey) async {
    final key = apiKey.trim();
    if (key.isEmpty) return fallbackZaiModels;

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 7);
    try {
      final uri = Uri.parse('https://open.bigmodel.cn/api/paas/v4/models');
      final request = await client.getUrl(uri);
      request.headers.set('Authorization', 'Bearer $key');
      request.headers.set('User-Agent', 'TGAnswer-Desktop/1.0');

      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final data = json['data'] as List<dynamic>? ?? [];
        final models = data
            .map((item) => (item as Map<String, dynamic>)['id'] as String? ?? '')
            .where((id) => id.isNotEmpty)
            .toList();
        if (models.isNotEmpty) {
          return models;
        }
      }
    } catch (_) {
      // Return curated list on network/ssl issue
    } finally {
      client.close();
    }
    return fallbackZaiModels;
  }

  Future<List<String>> fetchGeminiModels(String apiKey) async {
    final key = apiKey.trim();
    if (key.isEmpty) return fallbackGeminiModels;

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 7);
    try {
      final uri = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?key=$key');
      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', 'TGAnswer-Desktop/1.0');

      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final modelsList = json['models'] as List<dynamic>? ?? [];
        final models = <String>[];
        for (final m in modelsList) {
          final map = m as Map<String, dynamic>;
          final name = (map['name'] as String? ?? '').replaceFirst('models/', '');
          final supportedMethods = (map['supportedGenerationMethods'] as List<dynamic>?)
                  ?.cast<String>() ??
              [];
          if (supportedMethods.contains('generateContent')) {
            // Exclude obsolete 1.5 flash if newer flash exists or filter
            if (!name.contains('1.5-flash-8b') && name != 'gemini-1.5-flash') {
              models.add(name);
            }
          }
        }
        if (models.isNotEmpty) {
          // Sort to put 2.5 and 2.0 at the top
          models.sort((a, b) {
            if (a.contains('2.5') && !b.contains('2.5')) return -1;
            if (!a.contains('2.5') && b.contains('2.5')) return 1;
            if (a.contains('2.0') && !b.contains('2.0')) return -1;
            if (!a.contains('2.0') && b.contains('2.0')) return 1;
            return a.compareTo(b);
          });
          return models;
        }
      }
    } catch (_) {
      // Fallback
    } finally {
      client.close();
    }
    return fallbackGeminiModels;
  }
}
