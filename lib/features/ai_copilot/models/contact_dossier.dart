import 'package:flutter/foundation.dart';

class ContactDossier {
  ContactDossier({
    required this.chatId,
    required this.goal,
    required this.tone,
    required this.facts,
    required this.summary,
    required this.psychotype,
    this.lastAnalyzed,
  });

  final String chatId;
  String goal;
  String tone;
  List<String> facts;
  String summary;
  String psychotype;
  DateTime? lastAnalyzed;

  ContactDossier copyWith({
    String? goal,
    String? tone,
    List<String>? facts,
    String? summary,
    String? psychotype,
    DateTime? lastAnalyzed,
  }) {
    return ContactDossier(
      chatId: chatId,
      goal: goal ?? this.goal,
      tone: tone ?? this.tone,
      facts: facts ?? List.from(this.facts),
      summary: summary ?? this.summary,
      psychotype: psychotype ?? this.psychotype,
      lastAnalyzed: lastAnalyzed ?? this.lastAnalyzed,
    );
  }
}

class ContactDossierStore {
  ContactDossierStore._();
  static final ContactDossierStore instance = ContactDossierStore._();

  final Map<String, ValueNotifier<ContactDossier>> _cache = {};

  ValueNotifier<ContactDossier> getDossier(String chatId) {
    return _cache.putIfAbsent(chatId, () {
      if (chatId == 'taras') {
        return ValueNotifier<ContactDossier>(
          ContactDossier(
            chatId: 'taras',
            goal: '🤝 Совместная разработка Telegram AI ассистента',
            tone: 'Дружелюбный IT-разработчик',
            psychotype: 'Инноватор / Визионер: горит пет-проектами, ценит скорость и открытый код',
            summary: 'Тарас делает пет-проект клиента Telegram с внедрением LLM и шерлоком по профилям. Планирует английский и портфолио на GitHub.',
            facts: [
              'Разработчик, ценит открытые решения и GitHub',
              'Хочет инструмент для пробива профилей и психотипов',
              'Активно тестирует LLM (Claude, китайские модели)',
              'Любит короткие, ёмкие ответы по существу',
            ],
            lastAnalyzed: DateTime.now().subtract(const Duration(minutes: 42)),
          ),
        );
      }

      if (chatId == 'nha-trang-estate') {
        return ValueNotifier<ContactDossier>(
          ContactDossier(
            chatId: 'nha-trang-estate',
            goal: '🏡 Закрыть сделку по аренде виллы в Нячанге',
            tone: 'Деловой и вежливый эксперт',
            psychotype: 'Прагматик: нужны точные локации, цены и условия депозита',
            summary: 'Агент по недвижимости во Вьетнаме (Нячанг, Дананг). Публикует варианты аренды и продажи.',
            facts: [
              'Локация: Нячанг, Вьетнам',
              'Основной фокус: аренда апартаментов и вилл у моря',
              'Отвечает оперативно, ценит готовность внести бронь',
            ],
            lastAnalyzed: DateTime.now().subtract(const Duration(hours: 3)),
          ),
        );
      }

      return ValueNotifier<ContactDossier>(
        ContactDossier(
          chatId: chatId,
          goal: 'Установить контакт и выявить потребности',
          tone: 'Вежливый и открытый',
          psychotype: 'Не определен (требуется авто-анализ)',
          summary: 'Новый контакт. Анализ переписки еще не производился.',
          facts: [
            'Первичное знакомство',
          ],
        ),
      );
    });
  }
}
