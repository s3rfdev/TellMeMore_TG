import 'package:flutter/material.dart';

import '../../../core/localization/app_locale.dart';
import '../../../core/theme/tg_theme.dart';
import '../../../core/widgets/tg_avatar.dart';
import '../../../core/widgets/tg_toast.dart';
import '../../../data/models/tg_chat.dart';
import '../../../data/tdlib/tdlib_service.dart';

/// Диалог выбора чата для пересылки сообщения (Forward).
class ForwardDialog extends StatefulWidget {
  const ForwardDialog({
    super.key,
    required this.message,
    required this.currentChatId,
  });

  final TgMessage message;
  final String currentChatId;

  static void show(
    BuildContext context, {
    required TgMessage message,
    required String currentChatId,
  }) {
    showDialog(
      context: context,
      builder: (_) => ForwardDialog(
        message: message,
        currentChatId: currentChatId,
      ),
    );
  }

  @override
  State<ForwardDialog> createState() => _ForwardDialogState();
}

class _ForwardDialogState extends State<ForwardDialog> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF212124),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tr('forward_message_title'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            height: 32,
            decoration: BoxDecoration(
              color: Tg.field,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                const Icon(Icons.search, size: 16, color: Tg.textFaint),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
                    style: const TextStyle(fontSize: 13, color: Colors.white),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: tr('search_chat_hint'),
                      hintStyle: const TextStyle(fontSize: 13, color: Tg.textFaint),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 320,
        height: 340,
        child: ValueListenableBuilder<List<TgChat>>(
          valueListenable: TdlibService.instance.chats,
          builder: (context, chats, _) {
            final filtered = chats.where((c) {
              if (c.id == widget.currentChatId) return false;
              if (_search.isEmpty) return true;
              return c.title.toLowerCase().contains(_search);
            }).toList();

            if (filtered.isEmpty) {
              return Center(
                child: Text(
                  tr('chats_not_found'),
                  style: const TextStyle(color: Tg.textDim, fontSize: 13),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: filtered.length,
              itemBuilder: (context, i) {
                final c = filtered[i];
                return ListTile(
                  dense: true,
                  visualDensity: const VisualDensity(vertical: -2),
                  leading: TgAvatar(
                    emoji: c.avatarEmoji,
                    color: Color(c.avatarColor),
                    imagePath: c.avatarPath,
                    size: 34,
                    fontSize: 14,
                  ),
                  title: Text(
                    c.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    final targetId = int.tryParse(c.id);
                    final fromId = int.tryParse(widget.currentChatId);
                    if (targetId != null) {
                      if (fromId != null && widget.message.id > 0) {
                        TdlibService.instance.forwardMessage(
                          targetId,
                          fromId,
                          widget.message.id,
                        );
                      } else if (widget.message.mediaPath.isNotEmpty) {
                        TdlibService.instance.sendFile(targetId, widget.message.mediaPath);
                      } else if (widget.message.text.isNotEmpty) {
                        TdlibService.instance.sendMessage(targetId, widget.message.text);
                      }
                      TgToast.show(
                        context,
                        tr('forwarded_to_chat', {'title': c.title}),
                        icon: Icons.forward_rounded,
                      );
                    }
                  },
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tr('cancel'), style: const TextStyle(color: Tg.textDim, fontSize: 13)),
        ),
      ],
    );
  }
}
