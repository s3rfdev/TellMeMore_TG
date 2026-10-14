import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../core/theme/tg_theme.dart';
import '../../core/widgets/circle_icon_button.dart';
import '../../data/mock_data.dart';
import '../../data/tdlib/tdlib_service.dart';
import '../../state/app_state.dart';
import '../contacts/contacts_list_view.dart';
import 'chat_row.dart';

/// Левая колонка: шапка, профиль, поиск, архив, список чатов, нижняя панель.
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key, this.onChatOpened, this.elevated = false});

  final VoidCallback? onChatOpened;
  final bool elevated;

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  String _query = '';
  final _searchFocus = FocusNode();
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(() => setState(() {}));
    TdlibService.instance.loadMe();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = Container(
      decoration: BoxDecoration(
        color: Tg.sidebar,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: ValueListenableBuilder<SidebarTab>(
        valueListenable: AppState.activeSidebarTab,
        builder: (context, activeTab, _) {
          return Column(
            children: [
              if (activeTab == SidebarTab.contacts)
                Expanded(
                  child: ContactsListView(onContactOpened: widget.onChatOpened),
                )
              else ...[
                _header(),
                _archivedRow(),
                Expanded(child: _chatList()),
              ],
              _bottomBar(),
            ],
          );
        },
      ),
    );

    final content = widget.elevated
        ? DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 28,
                ),
              ],
            ),
            child: body,
          )
        : body;

    return content;
  }

  Widget _header() {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          CircleIconButton(
            icon: Icons.menu_rounded,
            iconSize: 20,
            color: Tg.textDim,
            onTap: () => AppState.drawerOpen.value = true,
          ),
          const SizedBox(width: 8),
          Expanded(child: _searchField()),
        ],
      ),
    );
  }

  Widget _searchField() {
    return Container(
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
              controller: _searchController,
              focusNode: _searchFocus,
              onChanged: (v) {
                setState(() => _query = v);
                TdlibService.instance.searchChats(v);
              },
              style: const TextStyle(fontSize: 13, color: Tg.text),
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'Поиск…',
                hintStyle: TextStyle(fontSize: 13, color: Tg.textFaint),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 6),
              ),
            ),
          ),
          if (_query.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
                setState(() => _query = '');
                TdlibService.instance.searchChats('');
              },
              child: const Icon(Icons.close, size: 14, color: Tg.textFaint),
            ),
        ],
      ),
    );
  }

  Widget _archivedRow() {
    return InkWell(
      onTap: () {},
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: Tg.hairline),
            bottom: BorderSide(color: Tg.hairline),
          ),
        ),
        child: Stack(
          children: [
            const Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inventory_2_outlined,
                      size: 18, color: Tg.textDim),
                  SizedBox(width: 8),
                  Text(
                    'Archived Chats',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: Tg.text,
                    ),
                  ),
                ],
              ),
            ),
            const Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: Center(
                child: Icon(CupertinoIcons.chevron_forward,
                    size: 13, color: Tg.textFaint),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chatList() {
    return ListenableBuilder(
      listenable: Listenable.merge([
        AppState.selectedChatId,
        AppState.demoMode,
        TdlibService.instance.chats,
        TdlibService.instance.searchResults,
      ]),
      builder: (context, _) {
        final realChats = TdlibService.instance.chats.value;
        final searchChats = TdlibService.instance.searchResults.value;
        final useReal =
            !kIsWeb && !AppState.demoMode.value && realChats.isNotEmpty;
        final source = useReal ? realChats : mockChats;
        final q = _query.trim().toLowerCase();
        final List<TgChat> chats;
        if (q.isNotEmpty && searchChats.isNotEmpty) {
          chats = searchChats;
        } else {
          chats = source
              .where((c) => q.isEmpty || c.title.toLowerCase().contains(q))
              .toList();
        }
        if (chats.isEmpty && q.isNotEmpty) {
          return Center(
            child: Text(
              'Ничего не найдено по "$_query"',
              style: const TextStyle(fontSize: 13, color: Tg.textDim),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 2),
          itemCount: chats.length,
          itemBuilder: (context, i) {
            final chat = chats[i];
            return ChatRow(
              chat: chat,
              selected: chat.id == AppState.selectedChatId.value,
              onTap: () {
                AppState.selectedChatId.value = chat.id;
                widget.onChatOpened?.call();
              },
            );
          },
        );
      },
    );
  }

  Widget _bottomBar() {
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Tg.hairline)),
      ),
      child: ValueListenableBuilder<SidebarTab>(
        valueListenable: AppState.activeSidebarTab,
        builder: (context, activeTab, _) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _bottomTabButton(
                tab: SidebarTab.contacts,
                active: activeTab == SidebarTab.contacts,
                icon: Icons.people_alt_outlined,
                activeIcon: Icons.people_alt_rounded,
                tooltip: 'Контакты',
              ),
              _chatsTabButton(active: activeTab == SidebarTab.chats),
              _bottomTabButton(
                tab: SidebarTab.copilot,
                active: activeTab == SidebarTab.copilot,
                icon: Icons.auto_awesome_outlined,
                activeIcon: Icons.auto_awesome,
                tooltip: 'AI Copilot',
                activeColor: const Color(0xFF8774E1),
              ),
              _bottomTabButton(
                tab: SidebarTab.settings,
                active: activeTab == SidebarTab.settings,
                icon: Icons.settings_outlined,
                activeIcon: Icons.settings_rounded,
                tooltip: 'Настройки',
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _bottomTabButton({
    required SidebarTab tab,
    required bool active,
    required IconData icon,
    required IconData activeIcon,
    required String tooltip,
    Color? activeColor,
  }) {
    final color = active ? (activeColor ?? Tg.accent) : Tg.textFaint;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => AppState.activeSidebarTab.value = tab,
        child: SizedBox(
          width: 44,
          height: 38,
          child: Center(
            child: Icon(active ? activeIcon : icon, size: 21, color: color),
          ),
        ),
      ),
    );
  }

  Widget _chatsTabButton({required bool active}) {
    return Tooltip(
      message: 'Чаты',
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => AppState.activeSidebarTab.value = SidebarTab.chats,
        child: SizedBox(
          width: 44,
          height: 38,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: Icon(
                  active ? Icons.chat_bubble : Icons.chat_bubble_outline,
                  size: 20,
                  color: active ? Tg.accent : Tg.textFaint,
                ),
              ),
              Positioned(
                right: 2,
                top: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Tg.accent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '33',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
