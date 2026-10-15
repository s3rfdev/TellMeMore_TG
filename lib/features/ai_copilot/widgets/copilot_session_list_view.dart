import 'package:flutter/material.dart';

import '../../../core/localization/app_locale.dart';
import '../../../core/theme/tg_theme.dart';
import '../../../core/widgets/tg_toast.dart';
import '../models/copilot_session.dart';
import '../services/copilot_session_store.dart';
import 'create_copilot_chat_dialog.dart';

/// Виджет левой колонки: список чатов и мультиагентов Copilot.
class CopilotSessionListView extends StatefulWidget {
  const CopilotSessionListView({super.key, this.onSessionOpened});

  final VoidCallback? onSessionOpened;

  @override
  State<CopilotSessionListView> createState() => _CopilotSessionListViewState();
}

class _CopilotSessionListViewState extends State<CopilotSessionListView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showRenameDialog(CopilotSession session) {
    final controller = TextEditingController(text: session.title);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Tg.sidebar,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          title: Text(tr('rename_chat_title'), style: const TextStyle(color: Tg.text, fontSize: 16)),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: Tg.text, fontSize: 13.5),
            decoration: InputDecoration(
              hintText: tr('chat_name_hint'),
              hintStyle: const TextStyle(color: Tg.textFaint),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(tr('cancel'), style: const TextStyle(color: Tg.textDim)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Tg.accent,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final text = controller.text.trim();
                if (text.isNotEmpty) {
                  CopilotSessionStore.instance.renameSession(session.id, text);
                }
                Navigator.of(context).pop();
              },
              child: Text(tr('save')),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteSession(CopilotSession session) {
    if (CopilotSessionStore.instance.sessions.value.length <= 1) {
      TgToast.show(context, tr('cannot_delete_only_chat'));
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Tg.sidebar,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          title: Text(tr('delete_copilot_chat_title'), style: const TextStyle(color: Tg.text, fontSize: 16)),
          content: Text(
            tr('delete_copilot_chat_desc', {'title': session.title}),
            style: const TextStyle(color: Tg.textDim, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(tr('cancel'), style: const TextStyle(color: Tg.textDim)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                CopilotSessionStore.instance.deleteSession(session.id);
                Navigator.of(context).pop();
                TgToast.show(context, tr('chat_deleted_toast'));
              },
              child: Text(tr('delete')),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        _buildSearchField(),
        Expanded(child: _buildSessionsList()),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8774E1), Color(0xFF51B2FF)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          ValueListenableBuilder<List<CopilotSession>>(
            valueListenable: CopilotSessionStore.instance.sessions,
            builder: (context, list, _) {
              return Row(
                children: [
                  Text(
                    tr('copilot_chats_header'),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Tg.text,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8774E1).withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${list.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF8774E1),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const Spacer(),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8774E1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () => CreateCopilotChatDialog.show(context),
            icon: const Icon(Icons.add, size: 16),
            label: Text(
              tr('new_chat_btn'),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 38,
      margin: const EdgeInsets.fromLTRB(10, 2, 10, 8),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Tg.field,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 18, color: Tg.textDim),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              style: const TextStyle(fontSize: 13, color: Tg.text),
              decoration: InputDecoration(
                hintText: tr('search_copilot_hint'),
                hintStyle: const TextStyle(color: Tg.textFaint, fontSize: 12.5),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
              child: const Icon(Icons.close, size: 16, color: Tg.textDim),
            ),
        ],
      ),
    );
  }

  Widget _buildSessionsList() {
    return ValueListenableBuilder<List<CopilotSession>>(
      valueListenable: CopilotSessionStore.instance.sessions,
      builder: (context, allSessions, _) {
        final filtered = allSessions.where((s) {
          if (_searchQuery.isEmpty) return true;
          return s.title.toLowerCase().contains(_searchQuery) ||
              s.agentRole.toLowerCase().contains(_searchQuery) ||
              s.messages.any((m) => m.text.toLowerCase().contains(_searchQuery));
        }).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.chat_bubble_outline, size: 38, color: Tg.textFaint),
                const SizedBox(height: 10),
                Text(
                  tr('copilot_chats_not_found'),
                  style: const TextStyle(color: Tg.textDim, fontSize: 13),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8774E1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => CreateCopilotChatDialog.show(context),
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(tr('create_first_chat_btn')),
                ),
              ],
            ),
          );
        }

        return ValueListenableBuilder<String>(
          valueListenable: CopilotSessionStore.instance.activeSessionId,
          builder: (context, activeId, _) {
            return ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              itemCount: filtered.length,
              separatorBuilder: (_, _) => const SizedBox(height: 2),
              itemBuilder: (context, index) {
                final session = filtered[index];
                final isActive = session.id == activeId;
                return _buildSessionTile(session, isActive);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSessionTile(CopilotSession session, bool isActive) {
    final lastMsg = session.lastMessage;
    final snippet = lastMsg != null
        ? lastMsg.text.replaceAll('\n', ' ')
        : tr('no_messages');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          CopilotSessionStore.instance.selectSession(session.id);
          widget.onSessionOpened?.call();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF2B5278) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isActive
                ? Border.all(color: const Color(0xFF8774E1).withValues(alpha: 0.4), width: 1)
                : null,
          ),
          child: Row(
            children: [
              // Аватар агента
              Stack(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: session.avatarColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: session.avatarColor.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Icon(session.avatarIcon, size: 22, color: session.avatarColor),
                    ),
                  ),
                  if (session.contextSummary != null)
                    Positioned(
                      right: -1,
                      bottom: -1,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Color(0xFF0F1721),
                          shape: BoxShape.circle,
                        ),
                        child: Container(
                          width: 13,
                          height: 13,
                          decoration: const BoxDecoration(
                            color: Color(0xFF00C48C),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Icon(Icons.compress, size: 8.5, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 11),

              // Название, роль и превью сообщения
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            session.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: isActive ? Colors.white : Tg.text,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Бейдж объема токенов
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: isActive
                                ? Colors.white.withValues(alpha: 0.18)
                                : Tg.field,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            session.contextSummary != null
                                ? '🗜️ ${session.totalTokens} tok'
                                : '${session.totalTokens} tok',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: isActive ? Colors.white : Tg.textDim,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        // Роль агента
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 0.5),
                          decoration: BoxDecoration(
                            color: session.avatarColor.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            session.agentRole,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: session.avatarColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            snippet,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: isActive
                                  ? Colors.white.withValues(alpha: 0.8)
                                  : Tg.textDim,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Выпадающее меню действий
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  size: 18,
                  color: isActive ? Colors.white.withValues(alpha: 0.8) : Tg.textDim,
                ),
                color: const Color(0xFF212D3B),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (val) {
                  switch (val) {
                    case 'rename':
                      _showRenameDialog(session);
                      break;
                    case 'compress':
                      CopilotSessionStore.instance.compressSession(session.id);
                      TgToast.show(context, tr('chat_context_compressed_toast', {'title': session.title}));
                      break;
                    case 'clear':
                      CopilotSessionStore.instance.clearSessionMessages(session.id);
                      TgToast.show(context, tr('chat_history_cleared_toast'));
                      break;
                    case 'delete':
                      _confirmDeleteSession(session);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'rename',
                    child: Row(
                      children: [
                        const Icon(Icons.edit_outlined, size: 18, color: Tg.text),
                        const SizedBox(width: 10),
                        Text(tr('rename_menu'), style: const TextStyle(color: Tg.text, fontSize: 13)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'compress',
                    child: Row(
                      children: [
                        const Icon(Icons.compress, size: 18, color: Color(0xFF00C48C)),
                        const SizedBox(width: 10),
                        Text(tr('compress_context_now'), style: const TextStyle(color: Tg.text, fontSize: 13)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'clear',
                    child: Row(
                      children: [
                        const Icon(Icons.cleaning_services_outlined, size: 18, color: Tg.textDim),
                        const SizedBox(width: 10),
                        Text(tr('clear_messages_menu'), style: const TextStyle(color: Tg.text, fontSize: 13)),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                        const SizedBox(width: 10),
                        Text(tr('delete_chat_menu'), style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
