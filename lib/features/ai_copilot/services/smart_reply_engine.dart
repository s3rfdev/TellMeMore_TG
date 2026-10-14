import '../../../data/models/tg_chat.dart';
import '../models/contact_dossier.dart';

/// Движок генерации контекстных ответов на базе:
/// 1. Истории диалога (сообщения, вопросы, контекст)
/// 2. Досье контакта (цель общения, психотип, Tone of Voice, CRM-факты, саммари)
/// 3. Личных голосовых/текстовых директив пользователя
class SmartReplyEngine {
  /// Автоответ с глубоким учетом контекста переписки И досье контакта (цели, психотип, тон).
  static String generateAutoReply({
    required String chatTitle,
    required List<TgMessage> messages,
    ContactDossier? dossier,
  }) {
    final lastIncoming = messages.reversed.firstWhere(
      (m) => !m.outgoing && m.text.trim().isNotEmpty,
      orElse: () => messages.isNotEmpty
          ? messages.last
          : const TgMessage(kind: MessageKind.text, text: ''),
    );
    final text = lastIncoming.text.trim();
    final lower = text.toLowerCase();

    // 1. Учет цели общения из досье (Goal-Oriented AI Response)
    if (dossier != null && dossier.goal.trim().isNotEmpty) {
      final goalLower = dossier.goal.toLowerCase().trim();

      // Цель: Закрыть сделку
      if (goalLower.contains('сделк') || goalLower.contains('закрыть сделку')) {
        if (lower.contains('сколько') ||
            lower.contains('цена') ||
            lower.contains('стоим') ||
            lower.contains('руб') ||
            lower.contains('\$')) {
          return 'По стоимости сориентировал. Если условия подходят — готов зафиксировать договорённость и выставить счёт на предоплату для старта.';
        }
        if (lower.contains('созвон') || lower.contains('звонок') || lower.contains('на связи')) {
          return 'Да, отличная мысль! Давайте созвонимся на 10 минут, согласуем финальные детали и сразу запустим процесс по сделке.';
        }
        if (text.endsWith('?')) {
          return 'По этому пункту всё реализуемо. Если принципиально согласны двигаться дальше — фиксируем условия и выходим на подписание договора.';
        }
        if (text.isNotEmpty) {
          return 'По всем моментам согласен. Предлагаю зафиксировать ключевые условия и переходить к оформлению сделки. Отправить проект договора?';
        }
      }

      // Цель: Позвать на свидание
      if (goalLower.contains('свидан') || goalLower.contains('позвать на свидание') || goalLower.contains('любов')) {
        return 'Привет! Как насчет того, чтобы выбраться на днях в уютное место, выпить кофе или поужинать вместе? 😊 Когда ты свободна?';
      }

      // Цель: Нанять сотрудника
      if (goalLower.contains('нанять') || goalLower.contains('сотрудник') || goalLower.contains('ваканси')) {
        return 'Здравствуйте! Изучил ваш опыт и стек — выглядит очень релевантно нашим задачам. Подскажите, когда вам удобно созвониться на 15 минут для технического интервью?';
      }

      // Цель: Привлечь инвестиции
      if (goalLower.contains('инвест') || goalLower.contains('привлечь инвестиции')) {
        return 'Здравствуйте! Мы как раз обновили инвестиционную презентацию и метрики проекта. Могу прислать дек для ознакомления или кратко созвонимся с фаундерами на 10 минут.';
      }

      // Цель: Нетворкинг и партнёрство
      if (goalLower.contains('нетворк') || goalLower.contains('партнёр')) {
        return 'Отличная экспертиза! Здорово обменяться опытом. Давайте будем на связи и обсудим совместные точки пересечения и партнёрство.';
      }

      // Цель: Дружеское общение
      if (goalLower.contains('друж') || goalLower.contains('приятел')) {
        return 'Привет! Рад тебя слышать, сто лет не виделись. Как дела, что нового происходит?';
      }

      // Кастомная пользовательская цель: отшить / поставить на паузу
      if (goalLower.contains('отш') || goalLower.contains('отста') || goalLower.contains('пауз')) {
        return 'Слушай, я сейчас очень сильно загружен текущими проектами и в ближайшее время точно не смогу уделить этому время. Давай пока поставим на паузу, если ситуация изменится — я сам выйду на связь.';
      }

      // Кастомная цель: выбить скидку
      if (goalLower.contains('скидк') || goalLower.contains('дисконт')) {
        return 'Предложение интересное, мы готовы стартовать в ближайшие дни, если согласуем дисконт 15% на первый период. Удастся зафиксировать такие условия?';
      }
    }

    // 2. Учет темы переписки (контекстный анализ сообщений)
    if (lower.contains('возвращали') ||
        lower.contains('билет') ||
        lower.contains('авиа') ||
        lower.contains('рейс')) {
      return 'Да, раньше с этим проще было. Сейчас правила поменялись — большинство авиакомпаний удерживают приличную комиссию, так что приходится перепроверять каждый тариф.';
    }
    if (lower.contains('виз') || lower.contains('паспорт') || lower.contains('дней')) {
      return 'По визе сейчас лучше делать электронную заранее, либо продлевать на месте в миграционке — это самый спокойный вариант.';
    }
    if (lower.contains('сколько') ||
        lower.contains('цена') ||
        lower.contains('стоим') ||
        lower.contains('руб') ||
        lower.contains('\$')) {
      return 'Слушай, по точной стоимости давай я чуть позже сверюсь с деталями и напишу точную цифру.';
    }
    if (lower.contains('ты где') ||
        lower.contains('как дела') ||
        lower.contains('привет') ||
        lower.contains('здравствуй')) {
      return 'Привет! Всё в порядке, в рабочих задачах. Ты как? Что нового?';
    }
    if (lower.contains('созвон') ||
        lower.contains('на связи') ||
        lower.contains('позвони') ||
        lower.contains('звонок')) {
      return 'Да, давай созвонимся ближе к вечеру, спокойно всё обсудим голосом.';
    }
    if (lower.contains('свободн') ||
        lower.contains('вилл') ||
        lower.contains('аренд') ||
        lower.contains('квартир')) {
      return 'Здравствуйте! Объект доступен на указанные даты. Подскажите, на какой срок планируете заезд?';
    }
    if (text.endsWith('?')) {
      return 'Хороший вопрос, сейчас всё проверю и отпишусь в течение нескольких минут.';
    }
    if (text.isNotEmpty) {
      return 'Понял тебя, согласен по всем моментам. Давай так и сделаем!';
    }
    return 'Привет! Буду на связи, как освободишься — маякни.';
  }

  /// Автоответ с учетом чата + личной голосовой/текстовой директивы + досье контакта.
  static String generateInstructionReply({
    required String chatTitle,
    required List<TgMessage> messages,
    required String instruction,
    ContactDossier? dossier,
  }) {
    final lower = instruction.toLowerCase().trim();

    // 1. Вежливо отшить / неприятен / отстать без грубости
    if (lower.contains('отш') ||
        lower.contains('неприят') ||
        lower.contains('отстал') ||
        lower.contains('отвали') ||
        lower.contains('груб') ||
        lower.contains('отстать') ||
        lower.contains('слить')) {
      return 'Слушай, я сейчас очень сильно загружен текущими проектами и в ближайшее время точно не смогу уделить этому время. Давай пока поставим на паузу, если ситуация изменится — я сам выйду на связь.';
    }

    // 2. Сказать, что занят / ответить позже
    if (lower.contains('занят') ||
        lower.contains('позже') ||
        lower.contains('некогда') ||
        lower.contains('потом') ||
        lower.contains('спешу')) {
      return 'Привет! Я сейчас на встрече и по уши в делах. Освобожусь чуть позже и обязательно гляну подробнее.';
    }

    // 3. Предложить созвон
    if (lower.contains('созвон') ||
        lower.contains('голос') ||
        lower.contains('набер') ||
        lower.contains('позвони')) {
      return 'Давай лучше созвонимся на пару минут и голосом всё решим — так будет намного быстрее. Во сколько тебе удобно?';
    }

    // 4. Денежный вопрос / предоплата / платный проект
    if (lower.contains('деньг') ||
        lower.contains('оплат') ||
        lower.contains('предоплат') ||
        lower.contains('счет') ||
        lower.contains('платн') ||
        lower.contains('прайс')) {
      return 'По задаче концептуально договорились. Единственное — давай сразу согласуем вопрос по предоплате и условиям, чтобы всё было зафиксировано.';
    }

    // 5. Любовный / флирт / личный контекст
    if (lower.contains('люб') ||
        lower.contains('мил') ||
        lower.contains('скуча') ||
        lower.contains('гуля') ||
        lower.contains('вечер') ||
        lower.contains('красот')) {
      return 'Привет! Тоже о тебе вспоминал 😊 Давай выберемся куда-нибудь выпить кофе на днях, как у тебя по времени?';
    }

    // 6. Холодно / нейтрально / сухо
    if (lower.contains('холодн') ||
        lower.contains('нейтральн') ||
        lower.contains('сухо') ||
        lower.contains('официальн')) {
      return 'Принято. Информацию зафиксировал, спасибо.';
    }

    // 7. Отказ / не согласен
    if (lower.contains('откаж') ||
        lower.contains('не соглас') ||
        lower.contains('не подход') ||
        lower.contains('нет')) {
      return 'Спасибо за информацию и предложение, но на текущий момент такой формат мне не подходит.';
    }

    // Если есть цель и тон в досье, гармонизируем ответ под задачу
    if (dossier != null && dossier.tone.toLowerCase().contains('строго деловой')) {
      return 'Добрый день. По вашему вопросу: $instruction. Предлагаю зафиксировать дальнейшие шаги письменно.';
    }

    // Пользовательская формулировка в свободной форме
    return 'По поводу этого вопроса: $instruction. Давай спишемся чуть позже и согласуем следующий шаг.';
  }
}
