import '../../../data/models/tg_chat.dart';

/// Движок генерации контекстных ответов на базе истории чата и голосовых/текстовых директив пользователя.
class SmartReplyEngine {
  /// Автоответ исключительно на основе контекста последних сообщений чата.
  static String generateAutoReply({
    required String chatTitle,
    required List<TgMessage> messages,
  }) {
    final lastIncoming = messages.reversed.firstWhere(
      (m) => !m.outgoing && m.text.trim().isNotEmpty,
      orElse: () => messages.isNotEmpty
          ? messages.last
          : const TgMessage(kind: MessageKind.text, text: ''),
    );
    final text = lastIncoming.text.trim();
    final lower = text.toLowerCase();

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

  /// Автоответ с учетом чата + личной голосовой/текстовой директивы пользователя.
  static String generateInstructionReply({
    required String chatTitle,
    required List<TgMessage> messages,
    required String instruction,
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

    // Пользовательская формулировка в свободной форме
    return 'По поводу этого вопроса: $instruction. Давай спишемся чуть позже и согласуем следующий шаг.';
  }
}
