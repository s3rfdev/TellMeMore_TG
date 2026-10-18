import 'dart:async';
import 'dart:io';
import '../../../core/localization/app_locale.dart';
import '../../../data/models/tg_chat.dart';
import '../../../data/tdlib/tdlib_service.dart';
import '../models/ai_settings_model.dart';
import '../models/contact_dossier.dart';
import '../services/copilot_session_store.dart';
import 'ai_model_service.dart';
import 'image_description_service.dart';
import 'voice_transcription_service.dart';

/// Движок генерации контекстных ответов на базе:
/// 1. Истории диалога (сообщения, вопросы, контекст)
/// 2. Досье контакта (цель общения, психотип, Tone of Voice, CRM-факты, саммари)
/// 3. Личных голосовых/текстовых директив пользователя
class SmartReplyEngine {
  /// Извлечение эффективного текста из сообщения: текст, расшифровка голосового или описание фото.
  static String getEffectiveMessageText(TgMessage m) {
    if (m.text.trim().isNotEmpty) return m.text.trim();
    if (m.kind == MessageKind.voice) {
      final trans = VoiceTranscriptionService.instance.getCachedTranscription(m.id) ??
          VoiceTranscriptionService.instance.getCachedTranscription(m.mediaPath);
      if (trans != null && trans.isNotEmpty && !trans.startsWith('[')) {
        return trans;
      }
      return I18n.instance.isRu ? 'голосовое сообщение' : 'voice message';
    }
    if (ImageDescriptionService.isImageMessage(m)) {
      final desc = ImageDescriptionService.instance.getCachedDescription(m.id) ??
          ImageDescriptionService.instance.getCachedDescription(m.mediaPath) ??
          ImageDescriptionService.instance.getCachedDescription(m.thumbnailPath);
      if (desc != null && desc.isNotEmpty) {
        return desc;
      }
      final nameHint = m.fileName.isNotEmpty ? ': ${m.fileName}' : '';
      return I18n.instance.isRu ? 'фотография$nameHint' : 'photo$nameHint';
    }
    if (m.kind == MessageKind.video) {
      return I18n.instance.isRu ? 'видеозапись' : 'video';
    }
    if (m.kind == MessageKind.document) {
      return I18n.instance.isRu ? 'документ ${m.fileName}' : 'document ${m.fileName}';
    }
    return '';
  }

  /// Асинхронная генерация автоответа через LLM с глубоким Sandwich Context (досье, RAG, история, медиа, ToV).
  static Future<String> generateAutoReplyAsync({
    required String chatTitle,
    String? chatId,
    String? chatSubtitle,
    required List<TgMessage> messages,
    ContactDossier? dossier,
  }) async {
    return _generateContextualReplyInternal(
      chatTitle: chatTitle,
      chatId: chatId,
      chatSubtitle: chatSubtitle,
      messages: messages,
      dossier: dossier,
      instruction: null,
    );
  }

  /// Асинхронная генерация ответа по личной директиве/голосу через LLM с глубоким Sandwich Context.
  static Future<String> generateInstructionReplyAsync({
    required String chatTitle,
    String? chatId,
    String? chatSubtitle,
    required List<TgMessage> messages,
    required String instruction,
    ContactDossier? dossier,
  }) async {
    return _generateContextualReplyInternal(
      chatTitle: chatTitle,
      chatId: chatId,
      chatSubtitle: chatSubtitle,
      messages: messages,
      dossier: dossier,
      instruction: instruction,
    );
  }

  /// Внутренняя сборка глубокого Sandwich Context идентично полноценному Copilot:
  /// - Верхний слой: жесткие системные директивы (живой стиль, никаких "Здравствуйте!" в неформальном чате)
  /// - Досье контакта: цели, Tone of Voice, психотип, CRM-факты, Шерлок-саммари
  /// - RAG-факты: из сессии или досье
  /// - Скользящее окно сообщений: со звуковыми транскрипциями (STT) и описаниями фото (Vision)
  /// - Нижний слой: задача (автономный автоответ или исполнение голосовой директивы)
  static Future<String> _generateContextualReplyInternal({
    required String chatTitle,
    String? chatId,
    String? chatSubtitle,
    required List<TgMessage> messages,
    ContactDossier? dossier,
    String? instruction,
  }) async {
    final isRu = I18n.instance.isRu;
    final settings = AiSettingsStore.instance.settings.value;

    // 1. Извлекаем сообщения (приоритет живому хранилищу TdlibService при наличии chatId)
    List<TgMessage> allMsgs = messages;
    if (chatId != null && chatId.isNotEmpty) {
      try {
        final liveMsgs = TdlibService.instance.messagesOf(chatId).value.messages;
        if (liveMsgs.isNotEmpty) {
          allMsgs = liveMsgs;
        }
      } catch (_) {}
    }

    final realMsgs = allMsgs
        .where((m) => m.kind != MessageKind.date && m.kind != MessageKind.unreadDivider)
        .toList();

    final limit = settings.contextMessageCount > 0 ? settings.contextMessageCount : 30;
    final recent = realMsgs.length > limit
        ? realMsgs.sublist(realMsgs.length - limit)
        : realMsgs;

    // 2. Форматируем сообщения с распознаванием голосовых (STT) и описанием изображений (Vision)
    final formattedHistory = <String>[];
    for (final m in recent) {
      final sender = m.outgoing
          ? (isRu ? '[Пользователь (Вы)]' : '[User (You)]')
          : (m.senderName.isNotEmpty && m.senderName != chatTitle
              ? (isRu ? '[Собеседник (${m.senderName})]' : '[Interlocutor (${m.senderName})]')
              : (isRu ? '[Собеседник ($chatTitle)]' : '[Interlocutor ($chatTitle)]'));

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
        String? desc = ImageDescriptionService.instance.getCachedDescription(m.id) ??
            ImageDescriptionService.instance.getCachedDescription(m.mediaPath) ??
            ImageDescriptionService.instance.getCachedDescription(m.thumbnailPath);
        if (desc != null && desc.isNotEmpty) {
          content = isRu
              ? '[🖼 Фото: $desc${content.isNotEmpty ? " (подпись: $content)" : ""}]'
              : '[🖼 Photo: $desc${content.isNotEmpty ? " (caption: $content)" : ""}]';
        } else {
          final nameHint = m.fileName.isNotEmpty ? ': ${m.fileName}' : (content.isNotEmpty ? ': $content' : '');
          content = isRu ? '[🖼 Фото$nameHint]' : '[🖼 Photo$nameHint]';
        }
      } else if (m.kind == MessageKind.video) {
        content = isRu
            ? '[🎬 Видео (${m.duration} сек)${content.isNotEmpty ? ": $content" : ""}]'
            : '[🎬 Video (${m.duration}s)${content.isNotEmpty ? ": $content" : ""}]';
      } else if (m.kind == MessageKind.document) {
        content = isRu
            ? '[📎 Документ: ${m.fileName} (${m.fileSize})${content.isNotEmpty ? ": $content" : ""}]'
            : '[📎 Document: ${m.fileName} (${m.fileSize})${content.isNotEmpty ? ": $content" : ""}]';
      }

      if (content.isNotEmpty) {
        formattedHistory.add('$sender: $content');
      }
    }

    // 3. Досье контакта и RAG-факты
    final targetDossier = dossier ?? (chatId != null ? ContactDossierStore.instance.getDossier(chatId).value : null);

    String ragSummary = targetDossier?.ragFactSummary ?? '';
    if (ragSummary.isEmpty && chatId != null) {
      final session = CopilotSessionStore.instance.sessions.value
          .where((s) => s.id == 'contact_$chatId')
          .firstOrNull;
      if (session != null && session.ragFactSummary != null && session.ragFactSummary!.isNotEmpty) {
        ragSummary = session.ragFactSummary!;
      }
    }

    // 4. Верхний слой Sandwich Context: жесткие системные директивы для LLM
    final systemPrompt = isRu
        ? '''
Ты — персональный AI-копилот пользователя, составляющий ответ в Telegram для "$chatTitle".
ПРАВИЛА И ПРИНЦИПЫ:
1. Пиши СТРОГО от первого лица («я») от имени пользователя.
2. Подстраивайся под РЕАЛЬНЫЙ стиль и тональность диалога. Если общение идет по-дружески или неформально («на ты», сленг, непринужденный тон, краткие фразы) — отвечай ИСКЛЮЧИТЕЛЬНО в таком же живом неформальном стиле. КАТЕГОРИЧЕСКИ ЗАПРЕЩЕНО использовать шаблонные официозные приветствия («Здравствуйте!», «Уважаемый...») и пустые корпоративные фразы!
3. Опирайся на цель пользователя, заданный Tone of Voice, психотип и факты о контакте.
4. ВАЖНОЕ ПРАВИЛО РАЗДЕЛЕНИЯ РОЛЕЙ:
   - «[Пользователь (Вы)]» в истории чата — это реплики САМОГО ПОЛЬЗОВАТЕЛЯ. Твой ответ должен быть продолжением его реплик!
   - «[Собеседник ($chatTitle)]» — это реплики ОППОНЕНТА / СОБЕСЕДНИКА.
   Никогда не путай роли участников!
5. Ответ должен быть полностью готов к немедленной отправке (1-3 живых, емких предложения).
6. Выводи ТОЛЬКО готовый текст сообщения без кавычек, без кавычек-ёлочек, без вводных слов и без пояснений.
'''
        : '''
You are the user's personal AI Copilot drafting a Telegram response to "$chatTitle".
RULES & PRINCIPLES:
1. Write strictly in the first person ("I") on behalf of the user.
2. Match the ACTUAL style and tone of this chat. If the participants talk casually or informally as friends (first-name basis, relaxed, conversational) — reply in the EXACT SAME natural casual style. NEVER use robotic formal greetings ("Hello!", "Dear...") or corporate clichés in informal chats!
3. Respect user objectives, specified Tone of Voice, psychotype, and known CRM facts.
4. CRITICAL ROLE SEPARATION:
   - "[User (You)]" in chat history denotes messages by the USER HIMSELF. Your generated reply must continue his side of the conversation!
   - "[Interlocutor ($chatTitle)]" denotes messages by the COUNTERPART.
   Never invert or confuse the participants!
5. The response must be ready to send immediately (1-3 concise, natural sentences).
6. Output ONLY the response text itself without quotes, introductory text, or explanations.
''';

    // 5. Формируем тело промпта с блоками Sandwich Context
    final promptBuffer = StringBuffer();

    // Блок целевого контакта
    promptBuffer.writeln('<target_contact>');
    promptBuffer.writeln(isRu ? 'Имя контакта: "$chatTitle"' : 'Contact Name: "$chatTitle"');
    if (chatSubtitle != null && chatSubtitle.isNotEmpty) {
      promptBuffer.writeln(isRu ? 'Статус/роль: "$chatSubtitle"' : 'Status/Role: "$chatSubtitle"');
    }
    if (targetDossier != null) {
      if (targetDossier.goal.isNotEmpty) {
        promptBuffer.writeln(isRu ? 'Цель пользователя: "${targetDossier.goal}"' : 'User Goal: "${targetDossier.goal}"');
      }
      if (targetDossier.tone.isNotEmpty) {
        promptBuffer.writeln(isRu ? 'Tone of Voice: "${targetDossier.tone}"' : 'Tone of Voice: "${targetDossier.tone}"');
      }
      if (targetDossier.psychotype.isNotEmpty) {
        promptBuffer.writeln(isRu ? 'Психотип контакта: "${targetDossier.psychotype}"' : 'Psychotype: "${targetDossier.psychotype}"');
      }
      if (targetDossier.facts.isNotEmpty) {
        promptBuffer.writeln(isRu ? 'Факты о контакте: ${targetDossier.facts.join("; ")}' : 'Facts: ${targetDossier.facts.join("; ")}');
      }
      if (targetDossier.summary.isNotEmpty) {
        promptBuffer.writeln(isRu ? 'Резюме переписки (Шерлок): "${targetDossier.summary}"' : 'Chat Summary: "${targetDossier.summary}"');
      }
      if (targetDossier.systemPrompt.isNotEmpty) {
        promptBuffer.writeln(isRu ? 'Индивидуальные инструкции: "${targetDossier.systemPrompt}"' : 'Contact Directives: "${targetDossier.systemPrompt}"');
      }
    }
    promptBuffer.writeln('</target_contact>\n');

    // Блок RAG-фактов
    if (ragSummary.isNotEmpty) {
      promptBuffer.writeln('<rag_chat_facts>');
      promptBuffer.writeln(ragSummary);
      promptBuffer.writeln('</rag_chat_facts>\n');
    }

    // Блок истории диалога
    promptBuffer.writeln('<telegram_chat_history count="${recent.length}">');
    if (formattedHistory.isNotEmpty) {
      promptBuffer.writeln(formattedHistory.join('\n'));
    } else {
      promptBuffer.writeln(isRu ? '(Диалог только начинается)' : '(Conversation is just beginning)');
    }
    promptBuffer.writeln('</telegram_chat_history>\n');

    // Нижний слой Sandwich Context: директива от пользователя или автономное решение AI
    if (instruction != null && instruction.trim().isNotEmpty) {
      promptBuffer.writeln(isRu
          ? '''
ЗАДАЧА:
Пользователь передал следующую голосовую или текстовую инструкцию (смысл и намерение):
"$instruction"

Сформулируй готовый текст ответа от лица пользователя строго по этой инструкции, адаптировав его под естественный стиль переписки с "$chatTitle" и цель общения.
Выведи ТОЛЬКО финальный текст сообщения.
'''
          : '''
TASK:
The user provided the following voice or text instruction (intent & core message):
"$instruction"

Draft a ready-to-send reply on behalf of the user strictly following this instruction, adapted to the natural style of the conversation with "$chatTitle" and the user's objective.
Output ONLY the final message text.
''');
    } else {
      promptBuffer.writeln(isRu
          ? '''
ЗАДАЧА AI-КОПИЛОТА:
Внимательно проанализируй последнее сообщение собеседника и общую динамику разговора.
Самостоятельно сформулируй идеальный, живой и логичный следующий ответ от лица пользователя, который органично продолжает беседу с "$chatTitle", учитывает цель общения и попадает в стиль чата.
Выведи ТОЛЬКО финальный текст сообщения.
'''
          : '''
TASK:
Analyze the interlocutor's latest message and the conversation context.
Formulate the ideal, organic next reply on behalf of the user that naturally advances the conversation with "$chatTitle", aligns with the goal, and matches the chat's style.
Output ONLY the final message text.
''');
    }

    // 6. Вызов LLM через AiModelService с 30-секундным таймаутом
    final rawReply = await AiModelService.instance
        .generateChatCompletion(
          prompt: promptBuffer.toString(),
          systemPrompt: systemPrompt,
          settings: settings,
        )
        .timeout(const Duration(seconds: 30));

    final cleaned = rawReply.trim()
        .replaceAll('"', '')
        .replaceAll('«', '')
        .replaceAll('»', '');

    if (cleaned.isNotEmpty) {
      return cleaned;
    }

    throw Exception(isRu ? 'Пустой ответ от нейросети' : 'Empty reply from AI model');
  }

  /// Автоответ с глубоким учетом контекста переписки И досье контакта (цели, психотип, тон).
  static String generateAutoReply({
    required String chatTitle,
    required List<TgMessage> messages,
    ContactDossier? dossier,
  }) {
    final realMsgs = messages.where((m) => m.kind != MessageKind.date && m.kind != MessageKind.unreadDivider).toList();
    final recent = realMsgs.length > 20
        ? realMsgs.sublist(realMsgs.length - 20)
        : realMsgs;

    final lastIncoming = recent.reversed.firstWhere(
      (m) => !m.outgoing && getEffectiveMessageText(m).trim().isNotEmpty,
      orElse: () => recent.reversed.firstWhere(
        (m) => getEffectiveMessageText(m).trim().isNotEmpty,
        orElse: () => recent.isNotEmpty
            ? recent.last
            : const TgMessage(kind: MessageKind.text, text: ''),
      ),
    );
    final text = getEffectiveMessageText(lastIncoming);
    final lower = text.toLowerCase();

    final isRu = I18n.instance.isRu;

    // 1. Учет цели общения из досье (Goal-Oriented AI Response)
    if (dossier != null && dossier.goal.trim().isNotEmpty) {
      final goalLower = dossier.goal.toLowerCase().trim();

      // Цель: Закрыть сделку
      if (goalLower.contains('сделк') ||
          goalLower.contains('закрыть сделку') ||
          goalLower.contains('deal') ||
          goalLower.contains('close deal')) {
        if (lower.contains('сколько') ||
            lower.contains('цена') ||
            lower.contains('стоим') ||
            lower.contains('руб') ||
            lower.contains('price') ||
            lower.contains('cost') ||
            lower.contains('\$')) {
          return isRu
              ? 'По стоимости сориентировал. Если условия подходят — готов зафиксировать договорённость и выставить счёт на предоплату для старта.'
              : 'I\'ve outlined the pricing details. If the terms work for you, I\'m ready to finalize the agreement and send an invoice for the initial payment to get started.';
        }
        if (lower.contains('созвон') ||
            lower.contains('звонок') ||
            lower.contains('на связи') ||
            lower.contains('call') ||
            lower.contains('zoom') ||
            lower.contains('meet')) {
          return isRu
              ? 'Да, отличная мысль! Давайте созвонимся на 10 минут, согласуем финальные детали и сразу запустим процесс по сделке.'
              : 'Yes, great idea! Let\'s jump on a quick 10-minute call to align on the final details and get the deal rolling.';
        }
        if (text.endsWith('?')) {
          return isRu
              ? 'По этому пункту всё реализуемо. Если принципиально согласны двигаться дальше — фиксируем условия и выходим на подписание договора.'
              : 'Everything regarding this point is completely feasible. If you\'re fundamentally on board to proceed, let\'s lock in the terms and move towards signing.';
        }
        if (text.isNotEmpty) {
          return isRu
              ? 'По всем моментам согласен. Предлагаю зафиксировать ключевые условия и переходить к оформлению сделки. Отправить проект договора?'
              : 'I agree on all points. Let\'s lock in the key terms and proceed with closing the deal. Shall I send over the contract draft?';
        }
      }

      // Цель: Позвать на свидание
      if (goalLower.contains('свидан') ||
          goalLower.contains('позвать на свидание') ||
          goalLower.contains('любов') ||
          goalLower.contains('date') ||
          goalLower.contains('love')) {
        return isRu
            ? 'Привет! Как насчет того, чтобы выбраться на днях в уютное место, выпить кофе или поужинать вместе? 😊 Когда ты свободна?'
            : 'Hey! How about grabbing a coffee or dinner together sometime this week? 😊 When are you free?';
      }

      // Цель: Нанять сотрудника
      if (goalLower.contains('нанять') ||
          goalLower.contains('сотрудник') ||
          goalLower.contains('ваканси') ||
          goalLower.contains('hire') ||
          goalLower.contains('interview')) {
        final tone = dossier.tone.toLowerCase();
        final isFormal = tone.contains('делов') || tone.contains('formal') || tone.contains('business');
        return isRu
            ? (isFormal
                ? 'Здравствуйте! Изучил ваш опыт и стек — выглядит очень релевантно нашим задачам. Подскажите, когда вам удобно созвониться на 15 минут для технического интервью?'
                : 'Привет! Посмотрел твой опыт и стек — выглядит очень интересно и по делу. Подскажи, когда тебе удобно созвониться на 15 минут пообщаться?')
            : (isFormal
                ? 'Hello! I reviewed your background and tech stack — looks very relevant to our goals. When would it be convenient for you to hop on a 15-minute technical intro call?'
                : 'Hey! Looked over your background and tech stack — looks really solid. When would you be free for a quick 15-minute intro chat?');
      }

      // Цель: Привлечь инвестиции
      if (goalLower.contains('инвест') ||
          goalLower.contains('привлечь инвестиции') ||
          goalLower.contains('invest')) {
        final tone = dossier.tone.toLowerCase();
        final isFormal = tone.contains('делов') || tone.contains('formal') || tone.contains('business');
        return isRu
            ? (isFormal
                ? 'Добрый день! По инвестиционному направлению и метрикам проекта готовы обсудить детали. Подскажите, когда вам удобно созвониться на 10-15 минут?'
                : 'Привет! По проекту и инвестициям как раз финализируем детали. Давай на днях созвонимся на 10 минут голосом или спишемся подробнее?')
            : (isFormal
                ? 'Hello! We are ready to discuss the investment overview and project metrics. When would be a convenient time to jump on a brief 10-15 minute call with the founders?'
                : 'Hey! We\'re wrapping up the project details and metrics. Let\'s catch up for a quick 10-minute call or chat soon?');
      }

      // Цель: Нетворкинг и партнёрство
      if (goalLower.contains('нетворк') ||
          goalLower.contains('партнёр') ||
          goalLower.contains('network') ||
          goalLower.contains('partner')) {
        return isRu
            ? 'Отличная экспертиза! Здорово обменяться опытом. Давайте будем на связи и обсудим совместные точки пересечения и партнёрство.'
            : 'Great expertise! It\'s great to connect and exchange experience. Let\'s stay in touch to explore potential synergies and collaboration.';
      }

      // Цель: Дружеское общение
      if (goalLower.contains('друж') ||
          goalLower.contains('приятел') ||
          goalLower.contains('friend')) {
        return isRu
            ? 'Привет! Рад тебя слышать, сто лет не виделись. Как дела, что нового происходит?'
            : 'Hey! Great to hear from you, it\'s been a while. How have you been? What\'s new?';
      }

      // Кастомная пользовательская цель: отшить / поставить на паузу
      if (goalLower.contains('отш') ||
          goalLower.contains('отста') ||
          goalLower.contains('пауз') ||
          goalLower.contains('pause') ||
          goalLower.contains('dismiss')) {
        return isRu
            ? 'Слушай, я сейчас очень сильно загружен текущими проектами и в ближайшее время точно не смогу уделить этому время. Давай пока поставим на паузу, если ситуация изменится — я сам выйду на связь.'
            : 'Hey, I\'m currently overwhelmed with ongoing commitments and won\'t be able to dedicate time to this right now. Let\'s put this on pause for now, and if things change I\'ll reach back out.';
      }

      // Кастомная цель: выбить скидку
      if (goalLower.contains('скидк') ||
          goalLower.contains('дисконт') ||
          goalLower.contains('discount')) {
        return isRu
            ? 'Предложение интересное, мы готовы стартовать в ближайшие дни, если согласуем дисконт 15% на первый период. Удастся зафиксировать такие условия?'
            : 'The proposal looks interesting, and we\'d be ready to kick off soon if we can agree on a 15% discount for the initial period. Would that be feasible?';
      }
    }

    // 2. Учет темы переписки (контекстный анализ сообщений)
    if (lower.contains('возвращали') ||
        lower.contains('билет') ||
        lower.contains('авиа') ||
        lower.contains('рейс') ||
        lower.contains('flight') ||
        lower.contains('ticket') ||
        lower.contains('airline')) {
      return isRu
          ? 'Да, раньше с этим проще было. Сейчас правила поменялись — большинство авиакомпаний удерживают приличную комиссию, так что приходится перепроверять каждый тариф.'
          : 'Yeah, it used to be much simpler. Airline policies have changed and most charge significant fees now, so each fare has to be double-checked.';
    }
    if (lower.contains('виз') ||
        lower.contains('паспорт') ||
        lower.contains('дней') ||
        lower.contains('visa') ||
        lower.contains('passport')) {
      return isRu
          ? 'По визе сейчас лучше делать электронную заранее, либо продлевать на месте в миграционке — это самый спокойный вариант.'
          : 'Regarding visas, it\'s best to apply for an e-visa in advance or extend locally at immigration — that\'s the safest route.';
    }
    if (lower.contains('сколько') ||
        lower.contains('цена') ||
        lower.contains('стоим') ||
        lower.contains('руб') ||
        lower.contains('price') ||
        lower.contains('cost') ||
        lower.contains('\$')) {
      return isRu
          ? 'Слушай, по точной стоимости давай я чуть позже сверюсь с деталями и напишу точную цифру.'
          : 'Regarding the exact price, let me check the details in a moment and I\'ll send you the exact number.';
    }
    if (lower.contains('ты где') ||
        lower.contains('как дела') ||
        lower.contains('привет') ||
        lower.contains('здравствуй') ||
        lower.contains('where are you') ||
        lower.contains('how are you') ||
        lower.contains('hello') ||
        lower.contains('hi')) {
      return isRu
          ? 'Привет! Всё в порядке, в рабочих задачах. Ты как? Что нового?'
          : 'Hey! Doing well, caught up in work. How are things with you? What\'s new?';
    }
    if (lower.contains('созвон') ||
        lower.contains('на связи') ||
        lower.contains('позвони') ||
        lower.contains('звонок') ||
        lower.contains('call') ||
        lower.contains('zoom')) {
      return isRu
          ? 'Да, давай созвонимся ближе к вечеру, спокойно всё обсудим голосом.'
          : 'Sure, let\'s catch up later today and discuss everything over voice.';
    }
    if (lower.contains('свободн') ||
        lower.contains('вилл') ||
        lower.contains('аренд') ||
        lower.contains('квартир') ||
        lower.contains('rent') ||
        lower.contains('apartment') ||
        lower.contains('villa') ||
        lower.contains('available')) {
      return isRu
          ? 'Здравствуйте! Объект доступен на указанные даты. Подскажите, на какой срок планируете заезд?'
          : 'Hello! The place is available for the specified dates. How long do you plan to stay?';
    }
    if (lower.contains('контакт') || lower.contains('телеграм') || lower.contains('список')) {
      return isRu
          ? 'Посмотрел скриншот списка контактов, всё понятно. Сейчас сориентируюсь и напишу!'
          : 'Checked the contact list screenshot, got it. Let me review and follow up shortly!';
    }
    if (lower.contains('девушк') || lower.contains('девочк') || lower.contains('портрет')) {
      return isRu
          ? 'Отличное фото! 😊'
          : 'Great photo! 😊';
    }
    if (lower.contains('фото') || lower.contains('photo') || lower.contains('скрин') || lower.contains('изображени')) {
      return isRu
          ? 'Спасибо за фото, всё вижу! Сейчас изучу подробнее и отвечу.'
          : 'Thanks for the photo, got it! Let me check the details and reply shortly.';
    }
    if (text.endsWith('?')) {
      return isRu
          ? 'Хороший вопрос, сейчас всё проверю и отпишусь в течение нескольких минут.'
          : 'Good question, let me check and get back to you in a few minutes.';
    }
    if (text.isNotEmpty) {
      return isRu
          ? 'Понял тебя, согласен по всем моментам. Давай так и сделаем!'
          : 'Got it, sounds good to me. Let\'s do that!';
    }
    return isRu
        ? 'Привет! Буду на связи, как освободишься — маякни.'
        : 'Hey! I\'ll be around, ping me whenever you\'re free.';
  }

  /// Автоответ с учетом чата + личной голосовой/текстовой директивы + досье контакта.
  static String generateInstructionReply({
    required String chatTitle,
    required List<TgMessage> messages,
    required String instruction,
    ContactDossier? dossier,
  }) {
    final isRu = I18n.instance.isRu;
    final lower = instruction.toLowerCase().trim();

    // 1. Вежливо отшить / неприятен / отстать без грубости
    if (lower.contains('отш') ||
        lower.contains('неприят') ||
        lower.contains('отстал') ||
        lower.contains('отвали') ||
        lower.contains('груб') ||
        lower.contains('отстать') ||
        lower.contains('слить') ||
        lower.contains('reject') ||
        lower.contains('dismiss') ||
        lower.contains('pause')) {
      return isRu
          ? 'Слушай, я сейчас очень сильно загружен текущими проектами и в ближайшее время точно не смогу уделить этому время. Давай пока поставим на паузу, если ситуация изменится — я сам выйду на связь.'
          : 'Hey, I am currently swamped with ongoing projects and won\'t be able to commit time to this right now. Let\'s put this on pause, and I\'ll reach back out if things change.';
    }

    // 2. Сказать, что занят / ответить позже
    if (lower.contains('занят') ||
        lower.contains('позже') ||
        lower.contains('некогда') ||
        lower.contains('потом') ||
        lower.contains('спешу') ||
        lower.contains('busy') ||
        lower.contains('later')) {
      return isRu
          ? 'Привет! Я сейчас на встрече и по уши в делах. Освобожусь чуть позже и обязательно гляну подробнее.'
          : 'Hey! I\'m in a meeting and tied up with tasks right now. I\'ll get back to you as soon as I\'m free to review in detail.';
    }

    // 3. Предложить созвон
    if (lower.contains('созвон') ||
        lower.contains('голос') ||
        lower.contains('набер') ||
        lower.contains('позвони') ||
        lower.contains('call') ||
        lower.contains('voice') ||
        lower.contains('zoom')) {
      return isRu
          ? 'Давай лучше созвонимся на пару минут и голосом всё решим — так будет намного быстрее. Во сколько тебе удобно?'
          : 'Let\'s hop on a quick call for a couple of minutes to sort it out — that will be much faster. When are you free?';
    }

    // 4. Денежный вопрос / предоплата / платный проект
    if (lower.contains('деньг') ||
        lower.contains('оплат') ||
        lower.contains('предоплат') ||
        lower.contains('счет') ||
        lower.contains('платн') ||
        lower.contains('прайс') ||
        lower.contains('price') ||
        lower.contains('pay') ||
        lower.contains('money')) {
      return isRu
          ? 'По задаче концептуально договорились. Единственное — давай сразу согласуем вопрос по предоплате и условиям, чтобы всё было зафиксировано.'
          : 'We\'re conceptually aligned on the task. Let\'s just agree on the payment terms and advance upfront so everything is clearly set.';
    }

    // 5. Любовный / флирт / личный контекст
    if (lower.contains('люб') ||
        lower.contains('мил') ||
        lower.contains('скуча') ||
        lower.contains('гуля') ||
        lower.contains('вечер') ||
        lower.contains('красот') ||
        lower.contains('date') ||
        lower.contains('love') ||
        lower.contains('dinner')) {
      return isRu
          ? 'Привет! Тоже о тебе вспоминал 😊 Давай выберемся куда-нибудь выпить кофе на днях, как у тебя по времени?'
          : 'Hey! Was thinking of you too 😊 How about grabbing a coffee sometime this week? How\'s your schedule?';
    }

    // 6. Холодно / нейтрально / сухо
    if (lower.contains('холодн') ||
        lower.contains('нейтральн') ||
        lower.contains('сухо') ||
        lower.contains('официальн') ||
        lower.contains('formal') ||
        lower.contains('cold') ||
        lower.contains('neutral')) {
      return isRu
          ? 'Принято. Информацию зафиксировал, спасибо.'
          : 'Acknowledged. Noted the details, thank you.';
    }

    // 7. Отказ / не согласен
    if (lower.contains('откаж') ||
        lower.contains('не соглас') ||
        lower.contains('не подход') ||
        lower.contains('нет') ||
        lower.contains('decline') ||
        lower.contains('refuse') ||
        lower.contains('disagree')) {
      return isRu
          ? 'Спасибо за информацию и предложение, но на текущий момент такой формат мне не подходит.'
          : 'Thank you for the proposal, but at this point that doesn\'t align with what I\'m looking for.';
    }

    // Если есть цель и тон в досье, гармонизируем ответ под задачу
    if (dossier != null &&
        (dossier.tone.toLowerCase().contains('строго деловой') ||
         dossier.tone.toLowerCase().contains('business'))) {
      return isRu
          ? 'Добрый день. По вашему вопросу: $instruction. Предлагаю зафиксировать дальнейшие шаги письменно.'
          : 'Good day. Regarding your inquiry: $instruction. I suggest documenting next steps in writing.';
    }

    // Пользовательская формулировка в свободной форме
    return isRu
        ? 'По поводу этого вопроса: $instruction. Давай спишемся чуть позже и согласуем следующий шаг.'
        : 'Regarding this matter: $instruction. Let\'s reconnect a bit later to align on next steps.';
  }
}
