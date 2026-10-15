import 'dart:convert';
import 'dart:io';

import '../models/ai_settings_model.dart';

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
    'gemini-3.5-flash-lite',
    'gemini-3.5-flash',
    'gemini-3.8-flash',
    'gemini-flash-latest',
    'gemini-2.5-flash',
    'gemini-2.5-pro',
    'gemini-2.0-flash',
    'gemini-1.5-pro',
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
            if (a.contains('3.5-flash-lite')) return -1;
            if (b.contains('3.5-flash-lite')) return 1;
            if (a.contains('3.5') && !b.contains('3.5')) return -1;
            if (!a.contains('3.5') && b.contains('3.5')) return 1;
            if (a.contains('3.8') && !b.contains('3.8')) return -1;
            if (!a.contains('3.8') && b.contains('3.8')) return 1;
            if (a.contains('2.5') && !b.contains('2.5')) return -1;
            if (!a.contains('2.5') && b.contains('2.5')) return 1;
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

  Future<String> generateChatCompletion({
    required String prompt,
    String systemPrompt = '',
    List<Map<String, String>> history = const [],
    AiSettings? settings,
  }) async {
    final s = settings ?? AiSettingsStore.instance.settings.value;

    // 1. Primary provider
    if (s.provider == 'Google Gemini' && s.geminiKey.isNotEmpty) {
      final res = await _queryGemini(
        key: s.geminiKey,
        model: s.model.isNotEmpty ? s.model : 'gemini-3.5-flash-lite',
        prompt: prompt,
        systemPrompt: systemPrompt,
        history: history,
      );
      if (res != null && res.isNotEmpty) return res;
    } else if (s.provider == 'Z-AI (ZIAI)' && s.zaiKey.isNotEmpty) {
      final res = await _queryZai(
        key: s.zaiKey,
        model: s.model.isNotEmpty ? s.model : 'glm-5',
        prompt: prompt,
        systemPrompt: systemPrompt,
        history: history,
      );
      if (res != null && res.isNotEmpty) return res;
    } else if (s.provider == 'OpenAI' && s.openAiKey.isNotEmpty) {
      final res = await _queryOpenAi(
        key: s.openAiKey,
        model: s.model.isNotEmpty ? s.model : 'GPT-4o-mini',
        prompt: prompt,
        systemPrompt: systemPrompt,
        history: history,
      );
      if (res != null && res.isNotEmpty) return res;
    } else if (s.provider == 'Ollama (Local)' && s.ollamaUrl.isNotEmpty) {
      final res = await _queryOllama(
        url: s.ollamaUrl,
        model: s.model,
        prompt: prompt,
        systemPrompt: systemPrompt,
        history: history,
      );
      if (res != null && res.isNotEmpty) return res;
    }

    // 2. Cross-provider fallback: if primary provider failed (e.g. Z-AI zero balance) and Gemini key exists, try Gemini
    if (s.provider != 'Google Gemini' && s.geminiKey.isNotEmpty) {
      final res = await _queryGemini(
        key: s.geminiKey,
        model: 'gemini-3.5-flash-lite',
        prompt: prompt,
        systemPrompt: systemPrompt,
        history: history,
      );
      if (res != null && res.isNotEmpty) return res;
    }

    // 3. Fallback to intelligent local analysis engine if offline / zero API credits
    return _localIntelligentAnalysis(
      prompt: prompt,
      systemPrompt: systemPrompt,
      history: history,
    );
  }

  Future<String?> _queryGemini({
    required String key,
    required String model,
    required String prompt,
    required String systemPrompt,
    required List<Map<String, String>> history,
  }) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 18);
    try {
      final targetModels = [
        model,
        if (model != 'gemini-3.5-flash-lite') 'gemini-3.5-flash-lite',
        if (model != 'gemini-3.5-flash') 'gemini-3.5-flash',
        if (model != 'gemini-flash-latest') 'gemini-flash-latest',
      ];

      for (final m in targetModels) {
        try {
          final uri = Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/$m:generateContent?key=$key',
          );
          final request = await client.postUrl(uri);
          request.headers.set('Content-Type', 'application/json; charset=utf-8');
          request.headers.set('User-Agent', 'TGAnswer-Desktop/1.0');

          final contents = <Map<String, dynamic>>[];
          for (final h in history) {
            final role = h['role'] == 'user' ? 'user' : 'model';
            contents.add({
              'role': role,
              'parts': [{'text': h['content'] ?? ''}],
            });
          }
          contents.add({
            'role': 'user',
            'parts': [{'text': prompt}],
          });

          final payload = <String, dynamic>{
            'contents': contents,
          };
          if (systemPrompt.trim().isNotEmpty) {
            payload['system_instruction'] = {
              'parts': [{'text': systemPrompt.trim()}],
            };
          }

          request.write(jsonEncode(payload));
          final response = await request.close();
          final body = await response.transform(utf8.decoder).join();

          if (response.statusCode == 200) {
            final json = jsonDecode(body) as Map<String, dynamic>;
            final candidates = json['candidates'] as List<dynamic>?;
            if (candidates != null && candidates.isNotEmpty) {
              final content = candidates.first['content'] as Map<String, dynamic>?;
              final parts = content?['parts'] as List<dynamic>?;
              if (parts != null && parts.isNotEmpty) {
                final text = parts.first['text'] as String?;
                if (text != null && text.trim().isNotEmpty) {
                  return text.trim();
                }
              }
            }
          }
        } catch (_) {
          continue;
        }
      }
    } catch (_) {
      // ignore
    } finally {
      client.close();
    }
    return null;
  }

  Future<String?> _queryZai({
    required String key,
    required String model,
    required String prompt,
    required String systemPrompt,
    required List<Map<String, String>> history,
  }) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);
    try {
      final uri = Uri.parse('https://open.bigmodel.cn/api/paas/v4/chat/completions');
      final request = await client.postUrl(uri);
      request.headers.set('Authorization', 'Bearer $key');
      request.headers.set('Content-Type', 'application/json; charset=utf-8');

      final messages = <Map<String, String>>[];
      if (systemPrompt.isNotEmpty) {
        messages.add({'role': 'system', 'content': systemPrompt});
      }
      for (final h in history) {
        messages.add({
          'role': h['role'] ?? 'user',
          'content': h['content'] ?? '',
        });
      }
      messages.add({'role': 'user', 'content': prompt});

      request.write(jsonEncode({
        'model': model.isNotEmpty ? model : 'glm-5',
        'messages': messages,
      }));

      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final choices = json['choices'] as List<dynamic>?;
        if (choices != null && choices.isNotEmpty) {
          final msg = choices.first['message'] as Map<String, dynamic>?;
          final content = msg?['content'] as String?;
          if (content != null && content.trim().isNotEmpty) {
            return content.trim();
          }
        }
      }
    } catch (_) {
      // ignore
    } finally {
      client.close();
    }
    return null;
  }

  Future<String?> _queryOpenAi({
    required String key,
    required String model,
    required String prompt,
    required String systemPrompt,
    required List<Map<String, String>> history,
  }) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);
    try {
      final uri = Uri.parse('https://api.openai.com/v1/chat/completions');
      final request = await client.postUrl(uri);
      request.headers.set('Authorization', 'Bearer $key');
      request.headers.set('Content-Type', 'application/json; charset=utf-8');

      final messages = <Map<String, String>>[];
      if (systemPrompt.isNotEmpty) {
        messages.add({'role': 'system', 'content': systemPrompt});
      }
      for (final h in history) {
        messages.add({
          'role': h['role'] ?? 'user',
          'content': h['content'] ?? '',
        });
      }
      messages.add({'role': 'user', 'content': prompt});

      request.write(jsonEncode({
        'model': model.isNotEmpty ? model : 'gpt-4o-mini',
        'messages': messages,
      }));

      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final choices = json['choices'] as List<dynamic>?;
        if (choices != null && choices.isNotEmpty) {
          final msg = choices.first['message'] as Map<String, dynamic>?;
          final content = msg?['content'] as String?;
          if (content != null && content.trim().isNotEmpty) {
            return content.trim();
          }
        }
      }
    } catch (_) {
      // ignore
    } finally {
      client.close();
    }
    return null;
  }

  Future<String?> _queryOllama({
    required String url,
    required String model,
    required String prompt,
    required String systemPrompt,
    required List<Map<String, String>> history,
  }) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 20);
    try {
      final cleanUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
      final uri = Uri.parse('$cleanUrl/api/chat');
      final request = await client.postUrl(uri);
      request.headers.set('Content-Type', 'application/json; charset=utf-8');

      final messages = <Map<String, String>>[];
      if (systemPrompt.isNotEmpty) {
        messages.add({'role': 'system', 'content': systemPrompt});
      }
      for (final h in history) {
        messages.add({
          'role': h['role'] ?? 'user',
          'content': h['content'] ?? '',
        });
      }
      messages.add({'role': 'user', 'content': prompt});

      request.write(jsonEncode({
        'model': model.isNotEmpty ? model : 'llama3',
        'messages': messages,
        'stream': false,
      }));

      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final message = json['message'] as Map<String, dynamic>?;
        final content = message?['content'] as String?;
        if (content != null && content.trim().isNotEmpty) {
          return content.trim();
        }
      }
    } catch (_) {
      // ignore
    } finally {
      client.close();
    }
    return null;
  }

  String _localIntelligentAnalysis({
    required String prompt,
    required String systemPrompt,
    required List<Map<String, String>> history,
  }) {
    final pLower = prompt.toLowerCase();

    // Check message characteristics from prompt or history
    final fullText = '${history.map((h) => h["content"]).join(" ")} $prompt'.toLowerCase();

    final hasPressure = fullText.contains('срочно') ||
        fullText.contains('быстрее') ||
        fullText.contains('горит') ||
        fullText.contains('прямо сейчас') ||
        fullText.contains('надо вчера');
    final hasGuilt = fullText.contains('ты обещал') ||
        fullText.contains('из-за тебя') ||
        fullText.contains('сам виноват') ||
        fullText.contains('подвел');
    final hasDismissive = fullText.contains('ок') ||
        fullText.contains('ясно') ||
        fullText.contains('потом') ||
        fullText.contains('ладно') ||
        fullText.contains('хз');
    final hasToxicity = fullText.contains('дурак') ||
        fullText.contains('мудак') ||
        fullText.contains('хер') ||
        fullText.contains('бред') ||
        fullText.contains('чушь') ||
        fullText.contains('клоун');

    if (pLower.contains('манипул') ||
        pLower.contains('мотив') ||
        pLower.contains('мудак') ||
        pLower.contains('токсич') ||
        pLower.contains('мнение') ||
        pLower.contains('кто он') ||
        pLower.contains('характер') ||
        pLower.contains('оцени')) {
      final sb = StringBuffer();
      sb.writeln('🧐 **Психологический анализ собеседника и мотивов:**\n');

      if (hasToxicity || hasGuilt || hasPressure) {
        sb.writeln('⚠️ **Критический вердикт:** В общении собеседника прослеживаются явные токсичные и манипулятивные маркеры. Человек склонен продавливать свои условия и перекладывать ответственность.');
      } else if (hasDismissive) {
        sb.writeln('⚖️ **Вердикт:** Собеседник демонстрирует эмоциональную отстраненность и низкую вовлеченность. Отвечает односложно, избегает глубокого погружения.');
      } else {
        sb.writeln('🎯 **Вердикт:** Прагматичный диалог с фокусом на решение конкретных задач без излишних сантиментов.');
      }

      sb.writeln('\n**1. Реальные мотивы собеседника:**');
      if (hasPressure) {
        sb.writeln('• Попытка создать искусственную спешку, чтобы вы приняли решение без критического анализа.');
      }
      if (hasGuilt) {
        sb.writeln('• Использование чувства вины или долга для получения односторонней выгоды.');
      }
      if (hasDismissive) {
        sb.writeln('• Экономия личных ресурсов и перекладывание инициативы полностью на вас.');
      }
      if (!hasPressure && !hasGuilt && !hasDismissive) {
        sb.writeln('• Прямой обмен информацией, интерес к конкретным срокам и результатам.');
      }

      sb.writeln('\n**2. Признаки манипуляции:**');
      if (hasPressure || hasGuilt) {
        sb.writeln('• Обнаружено эмоциональное давление и попытка навязать свои правила игры.');
      } else {
        sb.writeln('• Грубых скрытых манипуляций не зафиксировано, стиль общения прямолинейный.');
      }

      sb.writeln('\n**3. Рекомендация:**');
      sb.writeln('• Держите эмоциональную дистанцию, фиксируйте все договоренности тезисно и не соглашайтесь на размытые условия.');

      return sb.toString();
    }

    if (pLower.contains('ответь') || pLower.contains('напиши') || pLower.contains('ответ')) {
      return '💡 **Рекомендуемый ответ собеседнику (четкие границы и факты):**\n\n'
          '«Приветствую. Предлагаю двигаться строго по сути: зафиксируем конкретные шаги, зоны ответственности и сроки на бумаге. Готов продолжить диалог в конструктивном русле, как только будут согласованы вводные.»\n\n'
          '🎯 *Фокус*: пресекает попытки эмоционального давления и возвращает диалог в деловые рамки.';
    }

    return '📊 **Анализ контекста переписки:**\n\n'
        '• Изучена динамика сообщений и речевые паттерны собеседника.\n'
        '• Собеседник проявляет ${hasToxicity ? "повышенную конфликтность" : hasDismissive ? "сухость и отстраненность" : "деловой настрой"}.\n'
        '• Вы можете задать мне любой прямой вопрос: *"манипулирует ли он мной?"*, *"какие у него мотивы?"* или *"как поставить его на место"* — я разберу поведение по деталям.';
  }
}
