import 'dart:async';
import '../../../core/localization/app_locale.dart';
import '../../../data/models/tg_chat.dart';
import '../models/contact_dossier.dart';
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

  /// Асинхронная умная генерация ответа через LLM с откатом на эвристический движок.
  static Future<String> generateAutoReplyAsync({
    required String chatTitle,
    required List<TgMessage> messages,
    ContactDossier? dossier,
  }) async {
    final isRu = I18n.instance.isRu;
    try {
      final realMsgs = messages.where((m) => m.kind != MessageKind.date && m.kind != MessageKind.unreadDivider).toList();
      final recent = realMsgs.length > 15
          ? realMsgs.sublist(realMsgs.length - 15)
          : realMsgs;

      if (recent.isNotEmpty) {
        final formattedHistory = <String>[];
        for (final m in recent) {
          final sender = m.outgoing
              ? (isRu ? 'Вы' : 'You')
              : (m.senderName.isNotEmpty ? m.senderName : chatTitle);
          final content = getEffectiveMessageText(m);
          if (content.isNotEmpty) {
            formattedHistory.add('$sender: $content');
          }
        }

        if (formattedHistory.isNotEmpty) {
          final prompt = isRu
              ? '''
Вот последние реплики переписки с "$chatTitle":
${formattedHistory.join('\n')}

${dossier != null && dossier.goal.isNotEmpty ? "Цель общения: ${dossier.goal}\n" : ""}${dossier != null && dossier.tone.isNotEmpty ? "Тон: ${dossier.tone}\n" : ""}
Напиши один естественный, готовый к отправке ответ собеседнику. Ответ должен быть лаконичным (1-2 предложения), живым, без вводных слов и без кавычек.
'''
              : '''
Recent messages with "$chatTitle":
${formattedHistory.join('\n')}

${dossier != null && dossier.goal.isNotEmpty ? "Goal: ${dossier.goal}\n" : ""}${dossier != null && dossier.tone.isNotEmpty ? "Tone: ${dossier.tone}\n" : ""}
Write a natural, ready-to-send reply. Keep it concise (1-2 sentences), conversational, without preamble or quotation marks.
''';

          final reply = await AiModelService.instance
              .generateChatCompletion(
                prompt: prompt,
                systemPrompt: isRu
                    ? 'Ты — умный помощник по быстрым ответам в Telegram. Твоя задача — сгенерировать идеальный ответ на последнее сообщение.'
                    : 'You are a smart Telegram assistant generating the ideal quick reply to the latest message.',
              )
              .timeout(const Duration(seconds: 4));

          final cleaned = reply.trim().replaceAll('"', '').replaceAll('«', '').replaceAll('»', '');
          if (cleaned.isNotEmpty && !cleaned.toLowerCase().contains('яндекс') && !cleaned.toLowerCase().contains('openai')) {
            return cleaned;
          }
        }
      }
    } catch (_) {}

    return generateAutoReply(
      chatTitle: chatTitle,
      messages: messages,
      dossier: dossier,
    );
  }

  /// Асинхронная умная генерация по личной директиве через LLM с откатом на эвристический движок.
  static Future<String> generateInstructionReplyAsync({
    required String chatTitle,
    required List<TgMessage> messages,
    required String instruction,
    ContactDossier? dossier,
  }) async {
    final isRu = I18n.instance.isRu;
    try {
      final realMsgs = messages.where((m) => m.kind != MessageKind.date && m.kind != MessageKind.unreadDivider).toList();
      final recent = realMsgs.length > 15
          ? realMsgs.sublist(realMsgs.length - 15)
          : realMsgs;

      if (recent.isNotEmpty) {
        final formattedHistory = <String>[];
        for (final m in recent) {
          final sender = m.outgoing
              ? (isRu ? 'Вы' : 'You')
              : (m.senderName.isNotEmpty ? m.senderName : chatTitle);
          final content = getEffectiveMessageText(m);
          if (content.isNotEmpty) {
            formattedHistory.add('$sender: $content');
          }
        }

        final prompt = isRu
            ? '''
Контекст последних реплик с "$chatTitle":
${formattedHistory.join('\n')}

${dossier != null && dossier.goal.isNotEmpty ? "Цель: ${dossier.goal}\n" : ""}${dossier != null && dossier.tone.isNotEmpty ? "Тон: ${dossier.tone}\n" : ""}
Инструкция пользователя, как нужно ответить: "$instruction"

Сформулируй готовый текст ответа от лица пользователя строго по инструкции. Без кавычек, без лишних вводных слов, 1-3 предложения.
'''
            : '''
Context of chat with "$chatTitle":
${formattedHistory.join('\n')}

${dossier != null && dossier.goal.isNotEmpty ? "Goal: ${dossier.goal}\n" : ""}${dossier != null && dossier.tone.isNotEmpty ? "Tone: ${dossier.tone}\n" : ""}
User instruction on how to reply: "$instruction"

Draft a ready-to-send reply on behalf of the user following this instruction. No quotes, 1-3 sentences.
''';

        final reply = await AiModelService.instance
            .generateChatCompletion(
              prompt: prompt,
              systemPrompt: isRu
                  ? 'Ты — персональный AI-копилот по ответам в Telegram. Сформулируй точный ответ по инструкции пользователя.'
                  : 'You are a personal Telegram AI assistant. Draft an exact reply based on user instructions.',
            )
            .timeout(const Duration(seconds: 4));

        final cleaned = reply.trim().replaceAll('"', '').replaceAll('«', '').replaceAll('»', '');
        if (cleaned.isNotEmpty) {
          return cleaned;
        }
      }
    } catch (_) {}

    return generateInstructionReply(
      chatTitle: chatTitle,
      messages: messages,
      instruction: instruction,
      dossier: dossier,
    );
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
        return isRu
            ? 'Здравствуйте! Изучил ваш опыт и стек — выглядит очень релевантно нашим задачам. Подскажите, когда вам удобно созвониться на 15 минут для технического интервью?'
            : 'Hello! I reviewed your background and tech stack — looks very relevant to our goals. When would it be convenient for you to hop on a 15-minute technical intro call?';
      }

      // Цель: Привлечь инвестиции
      if (goalLower.contains('инвест') ||
          goalLower.contains('привлечь инвестиции') ||
          goalLower.contains('invest')) {
        return isRu
            ? 'Здравствуйте! Мы как раз обновили инвестиционную презентацию и метрики проекта. Могу прислать дек для ознакомления или кратко созвонимся с фаундерами на 10 минут.'
            : 'Hello! We just updated our investment pitch deck and key metrics. I can send the deck over for review, or we can do a brief 10-minute intro call with the founders.';
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
