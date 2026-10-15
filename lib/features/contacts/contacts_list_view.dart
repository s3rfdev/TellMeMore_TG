import 'package:flutter/material.dart';

import '../../core/localization/app_locale.dart';
import '../../core/theme/tg_theme.dart';
import '../../core/widgets/tg_avatar.dart';
import '../../core/widgets/tg_toast.dart';
import '../../data/models/tg_account.dart';
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
    return ValueListenableBuilder<TgAccount>(
      valueListenable: AccountManager.instance.currentAccount,
      builder: (context, currentAcc, _) {
        final sourceContacts = AccountManager.instance.getContacts(currentAcc.id);
        final contacts = sourceContacts.where((c) {
          if (_filter.isEmpty) return true;
          final q = _filter.toLowerCase();
          return c.name.toLowerCase().contains(q) ||
              c.username.toLowerCase().contains(q) ||
              c.phone.contains(q);
        }).toList();

        return Stack(
          children: [
            Column(
              children: [
                _buildHeader(context),
                _buildSearchBar(),
                Expanded(
                  child: contacts.isEmpty
                      ? Center(
                          child: Text(
                            tr('no_contacts'),
                            style: const TextStyle(color: Tg.textDim, fontSize: 13.5),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
                          children: [
                            if (_filter.isEmpty) ...[
                              _buildQuickActionsCard(context),
                              const SizedBox(height: 12),
                            ],
                            _buildContactsSection(contacts),
                          ],
                        ),
                ),
              ],
            ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            backgroundColor: Tg.accentDark,
            foregroundColor: Colors.white,
            elevation: 0,
            focusElevation: 0,
            hoverElevation: 0,
            highlightElevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Tg.border),
            ),
            mini: true,
            tooltip: tr('add_contact'),
            onPressed: () => TgToast.show(context, tr('add_contact_toast')),
            child: const Icon(Icons.person_add_alt_1_rounded, size: 20),
          ),
        ),
      ],
    );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          ValueListenableBuilder<TgAccount>(
            valueListenable: AccountManager.instance.currentAccount,
            builder: (context, acc, _) {
              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => AppState.drawerOpen.value = true,
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: TgAvatar(
                    emoji: acc.avatarEmoji,
                    color: acc.avatarColor,
                    imagePath: acc.avatarPath,
                    size: 30,
                    fontSize: 13,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              tr('contacts'),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: Tg.fontMedium,
                color: Tg.text,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.sort_rounded, size: 20, color: Tg.textDim),
            tooltip: tr('sorted_by_name'),
            onPressed: () => TgToast.show(context, tr('sort_contacts_toast')),
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
        border: Border.all(color: Tg.borderSubtle),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 19, color: Tg.textFaint),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onChanged: (val) => setState(() => _filter = val.trim()),
              style: const TextStyle(fontSize: 13, color: Tg.text),
              decoration: InputDecoration(
                hintText: tr('search_contacts'),
                hintStyle: const TextStyle(fontSize: 13, color: Tg.textFaint),
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
              child: const Icon(Icons.close_rounded, size: 16, color: Tg.textDim),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Tg.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Tg.border),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            onTap: () => TgToast.show(context, tr('invite_friends_toast')),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: Tg.accent.withValues(alpha: 0.2),
                    child: const Icon(Icons.person_add_alt_1_rounded, size: 17, color: Tg.accent),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    tr('invite_friends'),
                    style: const TextStyle(fontSize: 13.5, color: Colors.white, fontWeight: Tg.fontRegular),
                  ),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.05)),
          InkWell(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
            onTap: () => TgToast.show(context, tr('recent_calls_toast')),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: const Color(0xFF4CAF50).withValues(alpha: 0.2),
                    child: const Icon(Icons.phone_rounded, size: 17, color: Color(0xFF4CAF50)),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    tr('recent_calls'),
                    style: const TextStyle(fontSize: 13.5, color: Colors.white, fontWeight: Tg.fontRegular),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactsSection(List<TgContact> contacts) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Tg.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Tg.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
            child: Text(
              tr('sorted_by_name'),
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: Tg.fontMedium,
                color: Tg.accent,
              ),
            ),
          ),
          ...contacts.map((contact) {
            final letter = contact.name.isNotEmpty
                ? contact.name.characters.first.toUpperCase()
                : '';

            return InkWell(
              onTap: () {
                AppState.selectedChatId.value = contact.id;
                AppState.activeSidebarTab.value = SidebarTab.chats;
                widget.onContactOpened?.call();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                child: Row(
                  children: [
                    SizedBox(
                      width: 22,
                      child: Text(
                        letter,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: Tg.fontRegular,
                          color: Tg.textDim,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TgAvatar(
                      emoji: contact.avatarEmoji,
                      color: Color(contact.avatarColor),
                      imagePath: contact.avatarPath ?? '',
                      size: 38,
                      fontSize: 15,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            contact.name,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: Tg.fontMedium,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            contact.status,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: Tg.fontRegular,
                              color: contact.isOnline ? const Color(0xFF4BD964) : Tg.textDim,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
