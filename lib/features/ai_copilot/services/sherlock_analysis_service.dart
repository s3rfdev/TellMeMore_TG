import 'dart:io';

import '../../../data/models/tg_chat.dart';
import 'ai_model_service.dart';
import 'image_description_service.dart';
import 'voice_transcription_service.dart';

/// Результат психологического анализа контакта Sherlock Analysis.
class SherlockAnalysisResult {
  const SherlockAnalysisResult({
    required this.psychotype,
    required this.summary,
    required this.extractedFacts,
    required this.analyzedAt,
  });

  final String psychotype;
  final String summary;
  final List<String> extractedFacts;
  final DateTime analyzedAt;
}

/// Сервис психологического анализа переписки и выявления скрытых мотивов/манипуляций (Sherlock Engine).
class SherlockAnalysisService {
  const SherlockAnalysisService._();
  static const SherlockAnalysisService instance = SherlockAnalysisService._();

  Future<SherlockAnalysisResult> analyzeChat({
    required String chatTitle,
    required List<TgMessage> messages,
    required String userGoal,
    int messageLimit = 50,
    bool isRu = true,
  }) async {
    final realMsgs = messages
        .where((m) => m.kind != MessageKind.date && m.kind != MessageKind.unreadDivider)
        .toList();

    final limit = messageLimit > 0 ? messageLimit : 50;
    final messagesToAnalyze = realMsgs.length > limit
        ? realMsgs.sublist(realMsgs.length - limit)
        : realMsgs;

    if (messagesToAnalyze.isEmpty) {
      throw Exception(isRu ? 'История переписки пуста' : 'Chat history is empty');
    }

    final liveAllowed = <dynamic>{};
    for (final m in messagesToAnalyze.reversed) {
      if (ImageDescriptionService.isImageMessage(m)) {
        final hasCache = (m.id != 0 && ImageDescriptionService.instance.hasDescription(m.id)) ||
            ImageDescriptionService.instance.hasDescription(m.mediaPath) ||
            ImageDescriptionService.instance.hasDescription(m.thumbnailPath);
        if (!hasCache) {
          final key = m.id != 0 ? m.id : (m.mediaPath.isNotEmpty ? m.mediaPath : m.thumbnailPath);
          if (key.toString().isNotEmpty) {
            liveAllowed.add(key);
            if (liveAllowed.length >= 3) break;
          }
        }
      }
    }

    final formattedList = <String>[];
    for (final m in messagesToAnalyze) {
      final sender = m.outgoing
          ? (isRu ? 'Вы' : 'You')
          : (m.senderName.isNotEmpty ? m.senderName : chatTitle);
      String content = m.text.replaceAll('\n', ' ').trim();
      if (m.kind == MessageKind.voice) {
        String? trans = VoiceTranscriptionService.instance.getCachedTranscription(m.id) ??
            VoiceTranscriptionService.instance.getCachedTranscription(m.mediaPath);
        if (trans == null || trans.isEmpty) {
          if (m.mediaPath.isNotEmpty && File(m.mediaPath).existsSync()) {
            try {
              trans = await VoiceTranscriptionService.instance.transcribeVoiceFile(
                filePath: m.mediaPath,
                messageId: m.id,
                durationSeconds: m.duration,
              );
            } catch (_) {}
          }
        }
        if (trans != null && trans.isNotEmpty && !trans.startsWith('[')) {
          content = isRu ? '[🎤 Расшифровка голосового: "$trans"]' : '[🎤 Voice transcript: "$trans"]';
        } else {
          content = isRu ? '[🎤 Голосовое сообщение (${m.duration} сек)]' : '[🎤 Voice note (${m.duration}s)]';
        }
      } else if (ImageDescriptionService.isImageMessage(m)) {
        final key = m.id != 0 ? m.id : (m.mediaPath.isNotEmpty ? m.mediaPath : m.thumbnailPath);
        final allowLive = liveAllowed.contains(key);
        String? desc = await ImageDescriptionService.instance.resolveImageDescriptionForContext(
          message: m,
          allowLiveVision: allowLive,
        );
        if (desc != null && desc.isNotEmpty) {
          content = isRu
              ? '[🖼 Фото: $desc${content.isNotEmpty ? " (подпись: $content)" : ""}]'
              : '[🖼 Photo: $desc${content.isNotEmpty ? " (caption: $content)" : ""}]';
        } else {
          final nameHint = m.fileName.isNotEmpty ? ': ${m.fileName}' : (content.isNotEmpty ? ': $content' : '');
          content = isRu ? '[🖼 Фото$nameHint]' : '[🖼 Photo$nameHint]';
        }
      } else if (m.kind == MessageKind.video) {
        content = isRu ? '[🎬 Видео (${m.duration} сек)${content.isNotEmpty ? ": $content" : ""}]' : '[🎬 Video (${m.duration}s)${content.isNotEmpty ? ": $content" : ""}]';
      } else if (m.kind == MessageKind.document) {
        content = isRu ? '[📎 Документ: ${m.fileName} (${m.fileSize})${content.isNotEmpty ? ": $content" : ""}]' : '[📎 Document: ${m.fileName} (${m.fileSize})${content.isNotEmpty ? ": $content" : ""}]';
      }
      formattedList.add('$sender: $content');
    }
    final transcript = formattedList.join('\n');

    final prompt = isRu
        ? '''
Проведи объективный психологический анализ человека и диалога с "$chatTitle" по реальной истории переписки (изучено ${messagesToAnalyze.length} сообщений):
$transcript

Цель пользователя: "${userGoal.isNotEmpty ? userGoal : 'Выяснить позицию и защитить свои интересы'}"

Выведи ответ строго по структуре:
[ПСИХОТИП]: 1-2 предложения, честный психологический портрет и стиль общения
[РЕЗЮМЕ]: 3-4 предложения: истинные мотивы, манипуляции, токсичность или ее отсутствие, уровень адекватности
[ФАКТЫ]:
- Реальный факт 1 из текста диалога
- Реальный факт 2 из текста диалога
'''
        : '''
Analyze the contact "$chatTitle" based on conversation history (${messagesToAnalyze.length} messages):
$transcript

User goal: "${userGoal.isNotEmpty ? userGoal : 'Clarify terms and safeguard interests'}"

Format strictly as:
[PSYCHOTYPE]: 1-2 sentences candid profile
[SUMMARY]: Motives and manipulation analysis
[FACTS]:
- Extracted fact 1
- Extracted fact 2
''';

    final aiResponse = await AiModelService.instance.generateChatCompletion(
      prompt: prompt,
      systemPrompt: 'Ты — независимый психолог и эксперт по переговорам. Анализируешь людей честно, без цензуры и корпоративных штампов.',
    );

    String extractedPsycho = '';
    String extractedSummary = '';
    final extractedFacts = <String>[];

    final lines = aiResponse.split('\n');
    String currentSection = '';
    final summaryBuffer = StringBuffer();
    final psychoBuffer = StringBuffer();

    final psychoRegex = RegExp(r'^(?:\d+\.|\*+|#+)?\s*\[?(?:ПСИХОТИП|PSYCHOTYPE)\]?\*?:?\s*(.*)$', caseSensitive: false);
    final summaryRegex = RegExp(r'^(?:\d+\.|\*+|#+)?\s*\[?(?:РЕЗЮМЕ|SUMMARY)\]?\*?:?\s*(.*)$', caseSensitive: false);
    final factsRegex = RegExp(r'^(?:\d+\.|\*+|#+)?\s*\[?(?:ФАКТЫ|FACTS)\]?\*?:?\s*(.*)$', caseSensitive: false);

    for (final line in lines) {
      final t = line.trim();
      if (t.isEmpty) continue;
      final pMatch = psychoRegex.firstMatch(t);
      final sMatch = summaryRegex.firstMatch(t);
      final fMatch = factsRegex.firstMatch(t);

      if (pMatch != null) {
        currentSection = 'psycho';
        final rest = pMatch.group(1)?.replaceAll(RegExp(r'^\*+|\*+$'), '').trim() ?? '';
        if (rest.isNotEmpty) psychoBuffer.writeln(rest);
      } else if (sMatch != null) {
        currentSection = 'summary';
        final rest = sMatch.group(1)?.replaceAll(RegExp(r'^\*+|\*+$'), '').trim() ?? '';
        if (rest.isNotEmpty) summaryBuffer.writeln(rest);
      } else if (fMatch != null) {
        currentSection = 'facts';
      } else if (currentSection == 'psycho') {
        if (sMatch == null && fMatch == null && !t.startsWith('[') && !t.toLowerCase().startsWith('резюме') && !t.toLowerCase().startsWith('факты')) {
          psychoBuffer.writeln(t);
        }
      } else if (currentSection == 'summary') {
        if (fMatch == null && !t.startsWith('[') && !t.toLowerCase().startsWith('факты')) {
          summaryBuffer.writeln(t);
        }
      } else if (currentSection == 'facts') {
        if (t.startsWith('-') || t.startsWith('•') || t.startsWith('*')) {
          final fact = t.replaceFirst(RegExp(r'^[-•*]\s*'), '').trim();
          if (fact.isNotEmpty && !fact.startsWith('[')) extractedFacts.add(fact);
        }
      }
    }

    extractedPsycho = psychoBuffer.toString().trim();
    extractedSummary = summaryBuffer.toString().trim();

    if (extractedPsycho.isEmpty) {
      extractedPsycho = aiResponse.split('\n').first.trim();
    }
    if (extractedSummary.isEmpty) {
      extractedSummary = aiResponse.trim();
    }

    return SherlockAnalysisResult(
      psychotype: extractedPsycho,
      summary: extractedSummary,
      extractedFacts: extractedFacts,
      analyzedAt: DateTime.now(),
    );
  }
}
