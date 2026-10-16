import 'package:flutter/material.dart';

import '../../../core/localization/app_locale.dart';
import '../../../core/theme/tg_theme.dart';
import '../../../core/widgets/circle_icon_button.dart';
import '../../../core/widgets/tg_avatar.dart';
import '../../../core/widgets/tg_toast.dart';
import '../../../data/models/tg_chat.dart';
import '../../../data/tdlib/tdlib_service.dart';
import '../../../state/app_state.dart';
import '../../ai_copilot/widgets/contact_dossier_sheet.dart';
import '../services/chat_export_service.dart';
import 'chat_export_dialog.dart';
import 'chat_system_prompt_dialog.dart';
import 'forward_dialog.dart';

/// Верхняя панель активного чата Telegram (поддерживает обычный режим, режим поиска и режим мульти-выбора сообщений).
class ChatHeader extends StatelessWidget {
  const ChatHeader({
    super.key,
    required this.chat,
    required this.showBack,
    this.onBack,
  });

  final TgChat chat;
  final bool showBack;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        AppState.messageSelectionMode,
        AppState.selectedMessages,
        AppState.chatSearchActive,
      ]),
      builder: (context, _) {
        final isSelection = AppState.messageSelectionMode.value;
        final isSearch = AppState.chatSearchActive.value;

        return Container(
          height: 52,
          margin: const EdgeInsets.fromLTRB(10, 10, 10, 6),
          decoration: BoxDecoration(
            color: Tg.sidebar,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Tg.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: isSelection
              ? _buildSelectionHeader(context)
              : isSearch
                  ? _buildSearchHeader(context)
                  : _buildNormalHeader(context),
        );
      },
    );
  }

  Widget _buildSelectionHeader(BuildContext context) {
    final count = AppState.selectedMessages.value.length;
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.close_rounded, color: Tg.textDim),
          onPressed: () {
            AppState.messageSelectionMode.value = false;
            AppState.selectedMessages.value = {};
          },
        ),
        const SizedBox(width: 6),
        Text(
          tr('selected_count', {'count': count.toString()}),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Tg.text),
        ),
        const Spacer(),
        if (count > 0) ...[
          IconButton(
            icon: const Icon(Icons.shortcut_rounded, color: Tg.accent),
            tooltip: tr('forward'),
            onPressed: () {
              final msgIds = AppState.selectedMessages.value;
              final history = TdlibService.instance.messagesOf(chat.id).value.messages;
              final found = history.where((m) => msgIds.contains(m.id)).toList();
              if (found.isNotEmpty) {
                ForwardDialog.show(context, message: found.first, currentChatId: chat.id);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Tg.danger),
            tooltip: tr('delete'),
            onPressed: () => _confirmDeleteSelected(context),
          ),
        ],
        const SizedBox(width: 8),
      ],
    );
  }

  void _confirmDeleteSelected(BuildContext context) {
    final count = AppState.selectedMessages.value.length;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF212D3B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(tr('delete_messages_title'), style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
        content: Text(tr('delete_messages_confirm', {'count': count.toString()}), style: const TextStyle(color: Tg.textDim, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(tr('cancel'), style: const TextStyle(color: Tg.textDim)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              final id = int.tryParse(chat.id);
              if (id != null) {
                TdlibService.instance.deleteMessages(id, AppState.selectedMessages.value.toList());
                AppState.messageSelectionMode.value = false;
                AppState.selectedMessages.value = {};
                TgToast.show(context, tr('deleted_messages_toast', {'count': count.toString()}), icon: Icons.delete_outline_rounded);
              }
            },
            child: Text(tr('delete'), style: const TextStyle(color: Tg.danger, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchHeader(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 14),
        const Icon(Icons.search_rounded, size: 20, color: Tg.textDim),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            autofocus: true,
            onChanged: (v) => AppState.chatSearchQuery.value = v,
            style: const TextStyle(fontSize: 14, color: Tg.text),
            decoration: InputDecoration(
              hintText: tr('search_messages_hint'),
              hintStyle: const TextStyle(fontSize: 14, color: Tg.textFaint),
              border: InputBorder.none,
              isDense: true,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded, size: 20, color: Tg.textDim),
          onPressed: () {
            AppState.chatSearchActive.value = false;
            AppState.chatSearchQuery.value = '';
          },
        ),
        const SizedBox(width: 6),
      ],
    );
  }

  Widget _buildNormalHeader(BuildContext context) {
    return Row(
      children: [
        if (showBack) ...[
          const SizedBox(width: 4),
          CircleIconButton(
            icon: Icons.arrow_back_ios_new,
            iconSize: 16,
            color: Tg.textDim,
            onTap: onBack,
          ),
        ],
        const SizedBox(width: 12),
        TgAvatar(
          emoji: chat.avatarEmoji,
          color: Color(chat.avatarColor),
          imagePath: chat.avatarPath,
          size: 36,
          fontSize: 15,
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
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Tg.text,
                      ),
                    ),
                  ),
                  if (chat.verified) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.verified, size: 14, color: Tg.verified),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                chat.headerSubtitle,
                style: const TextStyle(fontSize: 11.5, color: Tg.textFaint),
              ),
            ],
          ),
        ),
        Tooltip(
          message: I18n.instance.isRu ? 'AI-ассистент: досье и промпт' : 'AI Assistant: Dossier & Prompt',
          child: CircleIconButton(
            icon: Icons.psychology_rounded,
            iconSize: 20,
            color: Tg.accent,
            onTap: () => ContactDossierDialog.show(context, chat),
          ),
        ),
        CircleIconButton(
          icon: Icons.search,
          iconSize: 20,
          color: Tg.textDim,
          onTap: () => AppState.chatSearchActive.value = true,
        ),
        SizedBox(
          width: 36,
          height: 36,
          child: PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, size: 20, color: Tg.textDim),
            padding: EdgeInsets.zero,
            color: Tg.card,
            elevation: 0,
            constraints: const BoxConstraints(minWidth: 260, maxWidth: 320),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: Tg.border),
            ),
            onSelected: (val) {
              if (val == 'system_prompt') {
                ChatSystemPromptDialog.show(context, chat);
              } else if (val == 'select') {
                AppState.messageSelectionMode.value = true;
                AppState.selectedMessages.value = {};
              } else if (val == 'export_advisor') {
                ChatExportDialog.show(
                  context,
                  chat,
                  initialType: ExportContentType.advisorProfile,
                );
              } else if (val == 'export_chat') {
                ChatExportDialog.show(
                  context,
                  chat,
                  initialType: ExportContentType.chatHistory,
                );
              } else if (val == 'clear') {
                _confirmClearHistory(context);
              } else if (val == 'delete') {
                _confirmDeleteChat(context);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'system_prompt',
                child: Row(
                  children: [
                    const Icon(Icons.psychology_rounded, size: 18, color: Tg.accent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        I18n.instance.isRu ? 'Системный промпт AI' : 'AI System Prompt',
                        style: const TextStyle(color: Tg.text, fontSize: 13.5),
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'select',
                child: Row(
                  children: [
                    const Icon(Icons.checklist_rounded, size: 18, color: Tg.textDim),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(tr('select_messages'), style: const TextStyle(color: Tg.text, fontSize: 13.5)),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'export_advisor',
                child: Row(
                  children: [
                    const Icon(Icons.badge_outlined, size: 18, color: Tg.accent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(tr('export_profile_advisor'), style: const TextStyle(color: Tg.text, fontSize: 13.5)),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'export_chat',
                child: Row(
                  children: [
                    const Icon(Icons.file_download_outlined, size: 18, color: Color(0xFF4FAAFF)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(tr('export_chat_txt'), style: const TextStyle(color: Tg.text, fontSize: 13.5)),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(height: 1),
              PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    const Icon(Icons.cleaning_services_rounded, size: 18, color: Tg.textDim),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(tr('clear_history'), style: const TextStyle(color: Tg.text, fontSize: 13.5)),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    const Icon(Icons.delete_outline_rounded, size: 18, color: Tg.danger),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(tr('delete_chat'), style: const TextStyle(color: Tg.danger, fontSize: 13.5)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
      ],
    );
  }

  void _confirmClearHistory(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF212D3B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(tr('clear_history'), style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
        content: Text(tr('clear_history_confirm', {'title': chat.title}), style: const TextStyle(color: Tg.textDim, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(tr('cancel'), style: const TextStyle(color: Tg.textDim)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              final id = int.tryParse(chat.id);
              if (id != null) {
                TdlibService.instance.clearHistory(id);
                TgToast.show(context, tr('history_cleared_toast'), icon: Icons.cleaning_services_rounded);
              }
            },
            child: Text(tr('clear'), style: const TextStyle(color: Tg.danger, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteChat(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF212D3B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(tr('delete_chat'), style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
        content: Text(tr('delete_chat_confirm', {'title': chat.title}), style: const TextStyle(color: Tg.textDim, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(tr('cancel'), style: const TextStyle(color: Tg.textDim)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              final id = int.tryParse(chat.id);
              if (id != null) {
                TdlibService.instance.deleteChat(id);
                AppState.selectedChatId.value = '';
                TgToast.show(context, tr('chat_deleted_toast'), icon: Icons.delete_outline_rounded);
              }
            },
            child: Text(tr('delete'), style: const TextStyle(color: Tg.danger, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
