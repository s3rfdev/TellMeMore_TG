import 'dart:io';

import '../../../data/models/tg_account.dart';
import '../../../data/models/tg_chat.dart';
import '../../../data/tdlib/tdlib_service.dart';
import '../models/ai_settings_model.dart';
import '../models/contact_dossier.dart';
import '../models/copilot_session.dart';
import 'image_description_service.dart';
import 'voice_transcription_service.dart';

/// Результат построения сэндвич-контекста для Copilot.
class CopilotPromptResult {
  const CopilotPromptResult({
    required this.systemPrompt,
    this.toolName,
    this.toolOutput,
  });

  final String systemPrompt;
  final String? toolName;
  final String? toolOutput;
}

/// Сервис сборки сэндвич-промпта (Sandwich Context) и форматирования диалогов для AI Copilot.
class CopilotPromptBuilder {
  const CopilotPromptBuilder._();
  static const CopilotPromptBuilder instance = CopilotPromptBuilder._();

  /// Поиск связанного с сессией чата (по ID контакта, названию или активному экрану).
  TgChat? resolveTargetChat({
    required CopilotSession session,
    String? userQuery,
    String? activeChatId,
  }) {
    final currentAcc = AccountManager.instance.currentAccount.value;
    final chats = [
      ...TdlibService.instance.chats.value,
      ...AccountManager.instance.getChats(currentAcc.id),
    ];

    // 1. По ID в сессии (contact_<id>)
    if (session.id.startsWith('contact_')) {
      final cId = session.id.replaceFirst('contact_', '');
      final found = chats.where((c) => c.id == cId).toList();
      if (found.isNotEmpty) return found.first;
    }

    if (userQuery == null || userQuery.isEmpty) {
      if (activeChatId != null) {
        final found = chats.where((c) => c.id == activeChatId).toList();
        if (found.isNotEmpty) return found.first;
      }
      return null;
    }

    final lower = userQuery.toLowerCase();

    // 2. По имени в тексте запроса
    for (final c in chats) {
      if (c.title.isNotEmpty && lower.contains(c.title.toLowerCase())) {
        return c;
      }
    }

    // 3. Если упоминаются слова "чат", "диалог" и т.п., берем активный чат
    if (lower.contains('чат') ||
        lower.contains('диалог') ||
        lower.contains('переписк') ||
        lower.contains('chat') ||
        lower.contains('conversation')) {
      if (activeChatId != null) {
        final found = chats.where((c) => c.id == activeChatId).toList();
        if (found.isNotEmpty) return found.first;
      }
    }

    return null;
  }

  /// Сборка полного Sandwich-промпта для запроса к LLM.
  Future<CopilotPromptResult> buildSandwichPrompt({
    required CopilotSession session,
    required AiSettings settings,
    required String query,
    TgChat? matchedChat,
    bool isRu = true,
  }) async {
    // 1. Сбор базового промпта
    String effectivePrompt = session.systemPrompt.trim();
    if (matchedChat != null) {
      final chatDossier = ContactDossierStore.instance.getDossier(matchedChat.id).value;
      if (chatDossier.systemPrompt.isNotEmpty) {
        effectivePrompt = effectivePrompt.isNotEmpty
            ? '$effectivePrompt\n\n${chatDossier.systemPrompt}'
            : chatDossier.systemPrompt;
      }
    }

    if (matchedChat != null) {
      final activeChat = matchedChat;
      final realHistory = TdlibService.instance.messagesOf(activeChat.id).value;
      final msgs = realHistory.messages.isNotEmpty ? realHistory.messages : activeChat.messages;
      final realMsgs = msgs.where((m) => m.kind != MessageKind.date && m.kind != MessageKind.unreadDivider).toList();

      final chatDossier = ContactDossierStore.instance.getDossier(activeChat.id).value;
      final limit = session.messageLimit > 0
          ? session.messageLimit
          : (chatDossier.analysisMessageLimit > 0
              ? chatDossier.analysisMessageLimit
              : settings.contextMessageCount);
      final msgsToAnalyze = realMsgs.length > limit
          ? realMsgs.sublist(realMsgs.length - limit)
          : realMsgs;

      final hasRag = (session.ragFactSummary?.isNotEmpty == true) ||
          (chatDossier.ragFactSummary?.isNotEmpty == true);
      final ragSummary = session.ragFactSummary?.isNotEmpty == true
          ? session.ragFactSummary!
          : (chatDossier.ragFactSummary ?? '');
      final ragCount = session.ragFactSummaryCount > 0
          ? session.ragFactSummaryCount
          : (chatDossier.ragFactSummaryCount > 0 ? chatDossier.ragFactSummaryCount : msgsToAnalyze.length);

      final systemDirectives = StringBuffer();
      if (isRu) {
        systemDirectives.writeln('Ты — проницательный, откровенный и независимый AI-копилот и аналитик переговоров.');
        systemDirectives.writeln('Ты помогаешь пользователю анализировать переписку в Telegram и вести диалоги.');
        systemDirectives.writeln('');
        systemDirectives.writeln('ГЛАВНЫЕ ПРИНЦИПЫ:');
        systemDirectives.writeln('1. Будь предельно честен, прямолинеен и объективен. Не пытайся сглаживать углы, придумывать лесть или использовать пустые корпоративные штампы.');
        systemDirectives.writeln('2. Если пользователь спрашивает твое мнение, оценку человека, мотивы, манипуляции, токсичность — дай бескомпромиссную, психологически точную и доказательную оценку на основе реальных фактов и реплик.');
        systemDirectives.writeln('3. Если собеседник некомпетентен, ведет себя неадекватно, перекладывает работу, юлит или манипулирует — укажи на конкретные сигналы и предложи четкую линию защиты.');
        systemDirectives.writeln('4. Если пользователь просит предложить ответ — напиши уверенный, выверенный ответ, пресекающий манипуляции.');
        systemDirectives.writeln('');
        systemDirectives.writeln('ВАЖНЕЙШЕЕ ПРАВИЛО РАЗДЕЛЕНИЯ РОЛЕЙ:');
        systemDirectives.writeln('В блоках истории сообщений (<telegram_chat_history> и <telegram_recent_raw_messages>):');
        systemDirectives.writeln('• «[Пользователь (Вы)]» — это САМ ПОЛЬЗОВАТЕЛЬ (автор запроса к тебе, владелец аккаунта Telegram, от чьего лица ты действуешь и кому помогаешь).');
        systemDirectives.writeln('• «[Собеседник (${activeChat.title})]» — это его ОППОНЕНТ / ВИЗАВИ в данном чате.');
        systemDirectives.writeln('СТРОЖАЙШЕ ЗАПРЕЩЕНО путать роли: никогда не приписывай слова оппонента пользователю и слова пользователя оппоненту!');
      } else {
        systemDirectives.writeln('You are an insightful, candid, and independent AI Copilot and negotiation analyst.');
        systemDirectives.writeln('You help the user analyze Telegram conversations and conduct effective dialogue.');
        systemDirectives.writeln('');
        systemDirectives.writeln('CORE PRINCIPLES:');
        systemDirectives.writeln('1. Be completely truthful, direct, and objective. Never sugarcoat, flatter, or resort to empty corporate jargon.');
        systemDirectives.writeln('2. If the user asks for your psychological assessment, intentions, toxic behavior, or manipulation signals — provide an uncompromising, grounded evaluation citing concrete message facts.');
        systemDirectives.writeln('3. If the other person is evasive, gaslighting, or shifting blame — identify the exact signals and recommend a firm defense posture.');
        systemDirectives.writeln('4. If the user asks for a response suggestion — draft a sharp, poised, and strategic reply that protects user interests.');
        systemDirectives.writeln('');
        systemDirectives.writeln('CRITICAL ROLE SEPARATION RULE:');
        systemDirectives.writeln('In conversation history blocks (<telegram_chat_history> and <telegram_recent_raw_messages>):');
        systemDirectives.writeln('• "[User (You)]" denotes the USER HIMSELF (the person asking you for advice, Telegram account owner).');
        systemDirectives.writeln('• "[Interlocutor (${activeChat.title})]" denotes his OPPONENT / COUNTERPART in this chat.');
        systemDirectives.writeln('STRICTLY FORBIDDEN to invert roles: never attribute counterpart messages to the user or vice versa!');
      }

      if (effectivePrompt.isNotEmpty) {
        systemDirectives.writeln(isRu
            ? '\nДОПОЛНИТЕЛЬНЫЕ ДИРЕКТИВЫ ПОЛЬЗОВАТЕЛЯ:\n$effectivePrompt'
            : '\nADDITIONAL USER DIRECTIVES:\n$effectivePrompt');
      }

      if (session.contextSummary != null && session.contextSummary!.isNotEmpty) {
        systemDirectives.writeln('\n<dialogue_memory_summary>');
        systemDirectives.writeln(session.contextSummary!);
        systemDirectives.writeln('</dialogue_memory_summary>');
      }

      systemDirectives.writeln('');
      systemDirectives.writeln('<target_contact>');
      systemDirectives.writeln(isRu ? 'Имя контакта: "${activeChat.title}"' : 'Contact Name: "${activeChat.title}"');
      if (activeChat.headerSubtitle.isNotEmpty) {
        systemDirectives.writeln(isRu ? 'Статус/роль: "${activeChat.headerSubtitle}"' : 'Status/role: "${activeChat.headerSubtitle}"');
      }
      if (chatDossier.goal.isNotEmpty) {
        systemDirectives.writeln(isRu ? 'Цель пользователя: "${chatDossier.goal}"' : 'User Goal: "${chatDossier.goal}"');
      }
      if (chatDossier.psychotype.isNotEmpty) {
        systemDirectives.writeln(isRu ? 'Психотип контакта: "${chatDossier.psychotype}"' : 'Psychotype: "${chatDossier.psychotype}"');
      }
      if (chatDossier.tone.isNotEmpty) {
        systemDirectives.writeln(isRu ? 'Рекомендуемый тон: "${chatDossier.tone}"' : 'Recommended Tone: "${chatDossier.tone}"');
      }
      if (chatDossier.facts.isNotEmpty) {
        systemDirectives.writeln(isRu ? 'Факты: ${chatDossier.facts.join("; ")}' : 'Facts: ${chatDossier.facts.join("; ")}');
      }
      if (chatDossier.summary.isNotEmpty) {
        systemDirectives.writeln(isRu ? 'Саммари: "${chatDossier.summary}"' : 'Summary: "${chatDossier.summary}"');
      }
      systemDirectives.writeln('</target_contact>');
      systemDirectives.writeln('');

      String tool;
      String output;

      if (hasRag && ragSummary.isNotEmpty) {
        final recentRaw = realMsgs.length > 10
            ? realMsgs.sublist(realMsgs.length - 10)
            : realMsgs;
        final recentFormatted = <String>[];
        final ragLiveAllowed = <dynamic>{};

        for (final m in recentRaw.reversed) {
          if (ImageDescriptionService.isImageMessage(m)) {
            final hasCache = (m.id != 0 && ImageDescriptionService.instance.hasDescription(m.id)) ||
                ImageDescriptionService.instance.hasDescription(m.mediaPath) ||
                ImageDescriptionService.instance.hasDescription(m.thumbnailPath);
            if (!hasCache) {
              final key = m.id != 0 ? m.id : (m.mediaPath.isNotEmpty ? m.mediaPath : m.thumbnailPath);
              if (key.toString().isNotEmpty) {
                ragLiveAllowed.add(key);
                if (ragLiveAllowed.length >= 2) break;
              }
            }
          }
        }

        for (final m in recentRaw) {
          final sender = m.outgoing
              ? (isRu ? '[Пользователь (Вы)]' : '[User (You)]')
              : (m.senderName.isNotEmpty && m.senderName != activeChat.title
                  ? (isRu ? '[Собеседник (${m.senderName})]' : '[Interlocutor (${m.senderName})]')
                  : (isRu ? '[Собеседник (${activeChat.title})]' : '[Interlocutor (${activeChat.title})]'));
          String content = m.text.replaceAll('\n', ' ').trim();
          if (m.kind == MessageKind.voice) {
            final trans = VoiceTranscriptionService.instance.getCachedTranscription(m.id) ??
                VoiceTranscriptionService.instance.getCachedTranscription(m.mediaPath);
            if (trans != null && trans.isNotEmpty && !trans.startsWith('[')) {
              content = isRu ? '[🎤 Расшифровка: "$trans"]' : '[🎤 Voice: "$trans"]';
            } else {
              content = isRu ? '[🎤 Голосовое (${m.duration} сек)]' : '[🎤 Voice note (${m.duration}s)]';
            }
          } else if (ImageDescriptionService.isImageMessage(m)) {
            final key = m.id != 0 ? m.id : (m.mediaPath.isNotEmpty ? m.mediaPath : m.thumbnailPath);
            final allowLive = ragLiveAllowed.contains(key);
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
          } else if (m.kind == MessageKind.document) {
            content = isRu
                ? '[📎 Документ: ${m.fileName} (${m.fileSize})${content.isNotEmpty ? ": $content" : ""}]'
                : '[📎 Document: ${m.fileName} (${m.fileSize})${content.isNotEmpty ? ": $content" : ""}]';
          }
          recentFormatted.add('$sender: $content');
        }

        systemDirectives.writeln('<rag_chat_facts messages_analyzed="$ragCount" chat="${activeChat.title}">');
        systemDirectives.writeln(ragSummary);
        systemDirectives.writeln('</rag_chat_facts>');
        systemDirectives.writeln('');
        systemDirectives.writeln('<telegram_recent_raw_messages count="${recentRaw.length}">');
        systemDirectives.writeln(recentFormatted.join('\n'));
        systemDirectives.writeln('</telegram_recent_raw_messages>');

        tool = 'llm.analyzeRAG(chat: "${activeChat.title}", ragCount: $ragCount, recent: ${recentRaw.length}, model: "${settings.model}")';
        output = isRu
            ? 'Использована RAG-выжимка из $ragCount сообщ. + ${recentRaw.length} свежих реплик («${activeChat.title}»)'
            : 'Used RAG summary of $ragCount msgs + ${recentRaw.length} recent replies ("${activeChat.title}")';
      } else {
        final liveVisionAllowed = <dynamic>{};
        for (final m in msgsToAnalyze.reversed) {
          if (ImageDescriptionService.isImageMessage(m)) {
            final hasCache = (m.id != 0 && ImageDescriptionService.instance.hasDescription(m.id)) ||
                ImageDescriptionService.instance.hasDescription(m.mediaPath) ||
                ImageDescriptionService.instance.hasDescription(m.thumbnailPath);
            if (!hasCache) {
              final key = m.id != 0 ? m.id : (m.mediaPath.isNotEmpty ? m.mediaPath : m.thumbnailPath);
              if (key.toString().isNotEmpty) {
                liveVisionAllowed.add(key);
                if (liveVisionAllowed.length >= 3) break;
              }
            }
          }
        }

        final formattedList = <String>[];
        for (final m in msgsToAnalyze) {
          final sender = m.outgoing
              ? (isRu ? '[Пользователь (Вы)]' : '[User (You)]')
              : (m.senderName.isNotEmpty && m.senderName != activeChat.title
                  ? (isRu ? '[Собеседник (${m.senderName})]' : '[Interlocutor (${m.senderName})]')
                  : (isRu ? '[Собеседник (${activeChat.title})]' : '[Interlocutor (${activeChat.title})]'));
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
            final allowLive = liveVisionAllowed.contains(key);
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

        systemDirectives.writeln('<telegram_chat_history chat="${activeChat.title}" messages_count="${msgsToAnalyze.length}">');
        systemDirectives.writeln(transcript);
        systemDirectives.writeln('</telegram_chat_history>');

        tool = 'llm.analyzeChat(chat: "${activeChat.title}", limit: ${msgsToAnalyze.length}, model: "${settings.model}")';
        output = isRu
            ? 'Проанализировано ${msgsToAnalyze.length} сообщений из чата «${activeChat.title}»'
            : 'Analyzed ${msgsToAnalyze.length} messages from "${activeChat.title}"';
      }

      return CopilotPromptResult(
        systemPrompt: systemDirectives.toString(),
        toolName: tool,
        toolOutput: output,
      );
    } else {
      final tool = 'llm.chat(model: "${settings.model}")';
      final output = isRu ? 'Обработка запроса нейросетью ${settings.model}' : 'Processing via ${settings.model}';

      final systemDirectives = StringBuffer();
      if (isRu) {
        systemDirectives.writeln('Ты — интеллектуальный персональный ассистент и советник.');
        systemDirectives.writeln('Роль агента: ${session.agentRole}.');
        if (effectivePrompt.isNotEmpty) {
          systemDirectives.writeln('Директивы: $effectivePrompt');
        }
      } else {
        systemDirectives.writeln('You are an intelligent personal AI assistant and advisor.');
        systemDirectives.writeln('Agent role: ${session.agentRole}.');
        if (effectivePrompt.isNotEmpty) {
          systemDirectives.writeln('Directives: $effectivePrompt');
        }
      }

      if (session.contextSummary != null && session.contextSummary!.isNotEmpty) {
        systemDirectives.writeln('\n<dialogue_memory_summary>');
        systemDirectives.writeln(session.contextSummary!);
        systemDirectives.writeln('</dialogue_memory_summary>');
      }

      return CopilotPromptResult(
        systemPrompt: systemDirectives.toString(),
        toolName: tool,
        toolOutput: output,
      );
    }
  }
}
