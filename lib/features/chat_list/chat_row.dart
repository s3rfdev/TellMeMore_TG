import 'package:flutter/material.dart';

import '../../core/theme/tg_theme.dart';
import '../../core/widgets/tg_avatar.dart';
import '../../data/models/tg_chat.dart';

/// Строка чата в левой колонке — как в оригинале: аватар, заголовок
/// с бейджами, превью последнего сообщения, время и счётчик непрочитанных.
class ChatRow extends StatelessWidget {
  const ChatRow({
    super.key,
    required this.chat,
    required this.selected,
    required this.onTap,
  });

  final TgChat chat;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final timeColor = selected
        ? const Color(0xFFBFDCF8)
        : (chat.muted ? Tg.textFaint : Tg.time);

    return InkWell(
      onTap: onTap,
      hoverColor: Colors.white.withValues(alpha: 0.04),
      child: Container(
        height: 62,
        color: selected ? Tg.selected : null,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            TgAvatar(
              emoji: chat.avatarEmoji,
              color: Color(chat.avatarColor),
              imagePath: chat.avatarPath,
              size: 44,
              fontSize: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          chat.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.8,
                            fontWeight: FontWeight.w600,
                            color: Tg.text,
                          ),
                        ),
                      ),
                      if (chat.verified) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified,
                            size: 14, color: Tg.verified),
                      ],
                      if (chat.muted) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.notifications_off,
                            size: 12, color: Tg.textFaint),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text.rich(
                    TextSpan(
                      children: [
                        if (chat.sender.isNotEmpty)
                          TextSpan(
                            text: '${chat.sender}: ',
                            style: TextStyle(
                              fontSize: 12.8,
                              fontWeight: FontWeight.w500,
                              color: selected ? Colors.white : Tg.textDim,
                            ),
                          ),
                        TextSpan(
                          text: chat.preview,
                          style: TextStyle(
                            fontSize: 12.8,
                            color: selected
                                ? const Color(0xFFDCEAF9)
                                : Tg.textFaint,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (chat.outgoing || chat.unreadOwn)
                      Padding(
                        padding: const EdgeInsets.only(right: 3),
                        child: Icon(
                          chat.outgoingRead ? Icons.done_all_rounded : Icons.done_rounded,
                          size: 13,
                          color: chat.outgoingRead ? const Color(0xFF8774E1) : timeColor,
                        ),
                      ),
                    Text(chat.time,
                        style: TextStyle(fontSize: 11, color: timeColor)),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final r in chat.reactions) ...[
                      Text(r.emoji,
                          style: const TextStyle(fontSize: 12, height: 1)),
                      const SizedBox(width: 3),
                      _pill(r.count.toString(), selected),
                      const SizedBox(width: 3),
                    ],
                    if (chat.unread > 0)
                      _pill(_formatCount(chat.unread), selected),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String label, bool selected) {
    final bg = selected
        ? Colors.white.withValues(alpha: 0.25)
        : (chat.muted ? Tg.badgeMuted : Tg.accent);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
    );
  }

  String _formatCount(int n) {
    if (n >= 1000000) {
      return '${(n / 1000000).toStringAsFixed(n % 1000000 == 0 ? 0 : 1)}M';
    }
    if (n >= 10000) {
      return '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}K';
    }
    return n.toString();
  }
}
