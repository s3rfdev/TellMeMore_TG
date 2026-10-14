import 'package:flutter/material.dart';

import '../../../core/theme/tg_theme.dart';

class SmartRepliesBar extends StatelessWidget {
  const SmartRepliesBar({
    super.key,
    required this.chatId,
    required this.onSelected,
    required this.onClose,
  });

  final String chatId;
  final ValueChanged<String> onSelected;
  final VoidCallback onClose;

  List<String> _getSuggestions() {
    if (chatId == 'taras') {
      return [
        '🔥 Классная идея! Давай сделаем шерлок по аве',
        'Отличная скорость у Claude! А какую китайскую модель гонял?',
        'Давай закинем портфолио на GitHub и оформим README',
      ];
    }
    if (chatId == 'nha-trang-estate') {
      return [
        'Здравствуйте! Подскажите, свободна ли вилла на следующей неделе?',
        'Какой депозит и минимальный срок аренды?',
        'Пришлите, пожалуйста, точную геолокацию и видео объекта',
      ];
    }
    return [
      '🤝 Да, всё в силе! Буду на связи.',
      'Подскажите, пожалуйста, подробнее условия?',
      'Звучит отлично, давайте обсудим детали!',
    ];
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = _getSuggestions();

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 6),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2735),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF8774E1).withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 14, color: Color(0xFF8774E1)),
              const SizedBox(width: 6),
              const Text(
                'AI Smart Reply (на основе цели и контекста диалога):',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF8774E1),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onClose,
                child: const Icon(Icons.close_rounded, size: 16, color: Tg.textFaint),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: suggestions.map((text) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => onSelected(text),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Tg.sidebar,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.bolt_rounded, size: 14, color: Color(0xFF51B2FF)),
                          const SizedBox(width: 5),
                          Text(
                            text,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Tg.text,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
