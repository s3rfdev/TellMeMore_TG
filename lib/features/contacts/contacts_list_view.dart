import 'package:flutter/material.dart';

import '../../core/theme/tg_theme.dart';
import '../../core/widgets/circle_icon_button.dart';
import '../../core/widgets/tg_avatar.dart';
import '../../state/app_state.dart';
import 'models/tg_contact.dart';

class ContactsListView extends StatefulWidget {
  const ContactsListView({super.key, this.onContactOpened});

  final VoidCallback? onContactOpened;

  @override
  State<ContactsListView> createState() => _ContactsListViewState();
}

class _ContactsListViewState extends State<ContactsListView> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contacts = mockContacts.where((c) {
      if (_filter.isEmpty) return true;
      final q = _filter.toLowerCase();
      return c.name.toLowerCase().contains(q) ||
          c.username.toLowerCase().contains(q) ||
          c.phone.contains(q);
    }).toList();

    return Column(
      children: [
        _buildHeader(context),
        _buildSearchBar(),
        Expanded(
          child: contacts.isEmpty
              ? const Center(
                  child: Text(
                    'Контакты не найдены',
                    style: TextStyle(color: Tg.textDim, fontSize: 13.5),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: contacts.length,
                  itemBuilder: (context, index) {
                    final contact = contacts[index];
                    return _ContactTile(
                      contact: contact,
                      onTap: () {
                        AppState.selectedChatId.value = contact.id;
                        AppState.activeSidebarTab.value = SidebarTab.chats;
                        widget.onContactOpened?.call();
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          CircleIconButton(
            icon: Icons.menu_rounded,
            iconSize: 22,
            color: Tg.textDim,
            onTap: () => AppState.drawerOpen.value = true,
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              'Контакты',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Tg.text,
              ),
            ),
          ),
          CircleIconButton(
            icon: Icons.person_add_alt_1_outlined,
            iconSize: 20,
            color: Tg.accent,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Добавление нового контакта в разработке'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 38,
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Tg.field,
        borderRadius: BorderRadius.circular(19),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 19, color: Tg.textFaint),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onChanged: (val) => setState(() => _filter = val.trim()),
              style: const TextStyle(fontSize: 13.5, color: Tg.text),
              decoration: const InputDecoration(
                hintText: 'Поиск контактов…',
                hintStyle: TextStyle(fontSize: 13.5, color: Tg.textFaint),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          if (_filter.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchCtrl.clear();
                setState(() => _filter = '');
              },
              child: const Icon(Icons.close_rounded, size: 18, color: Tg.textFaint),
            ),
        ],
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.contact,
    required this.onTap,
  });

  final TgContact contact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Stack(
              children: [
                TgAvatar(
                  emoji: contact.avatarEmoji,
                  color: Color(contact.avatarColor),
                  imagePath: contact.avatarPath ?? '',
                  size: 46,
                  fontSize: 18,
                ),
                if (contact.isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFF43C053),
                        shape: BoxShape.circle,
                        border: Border.all(color: Tg.sidebar, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: Tg.text,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        contact.status,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: contact.isOnline
                              ? const Color(0xFF51B2FF)
                              : Tg.textFaint,
                          fontWeight: contact.isOnline
                              ? FontWeight.w500
                              : FontWeight.normal,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '• ${contact.phone}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Tg.textDim,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
