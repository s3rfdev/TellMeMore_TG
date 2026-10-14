import 'package:flutter/material.dart';

import '../../features/contacts/models/tg_contact.dart';
import '../../state/app_state.dart';
import '../account_data.dart';
import '../mock_data.dart';

class TgAccount {
  const TgAccount({
    required this.id,
    required this.name,
    required this.phone,
    required this.username,
    required this.bio,
    this.avatarPath = '',
    this.avatarEmoji = '👤',
    this.avatarColor = const Color(0xFF6B58C9),
    this.unreadBadge = 0,
    this.isOnline = true,
  });

  final String id;
  final String name;
  final String phone;
  final String username;
  final String bio;
  final String avatarPath;
  final String avatarEmoji;
  final Color avatarColor;
  final int unreadBadge;
  final bool isOnline;

  TgAccount copyWith({
    String? id,
    String? name,
    String? phone,
    String? username,
    String? bio,
    String? avatarPath,
    String? avatarEmoji,
    Color? avatarColor,
    int? unreadBadge,
    bool? isOnline,
  }) {
    return TgAccount(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      username: username ?? this.username,
      bio: bio ?? this.bio,
      avatarPath: avatarPath ?? this.avatarPath,
      avatarEmoji: avatarEmoji ?? this.avatarEmoji,
      avatarColor: avatarColor ?? this.avatarColor,
      unreadBadge: unreadBadge ?? this.unreadBadge,
      isOnline: isOnline ?? this.isOnline,
    );
  }
}

class AccountManager {
  AccountManager._() {
    _initDefaults();
  }

  static final AccountManager instance = AccountManager._();

  final Map<String, String> _selectedChatPerAccount = {
    'natalie': 'taras',
    'sergei': 'amos-core',
    'caban': 'caban-marketing',
  };

  final ValueNotifier<List<TgAccount>> accounts = ValueNotifier<List<TgAccount>>([]);
  final ValueNotifier<TgAccount> currentAccount = ValueNotifier<TgAccount>(
    const TgAccount(
      id: 'natalie',
      name: 'Natalie',
      phone: '+63 966 770 4095',
      username: '@natashadetka',
      bio: 'Ai',
      avatarPath: 'assets/images/natalie_avatar.png',
      avatarEmoji: 'N',
      avatarColor: Color(0xFF8774E1),
      unreadBadge: 0,
      isOnline: true,
    ),
  );

  void _initDefaults() {
    accounts.value = [
      const TgAccount(
        id: 'natalie',
        name: 'Natalie',
        phone: '+63 966 770 4095',
        username: '@natashadetka',
        bio: 'Ai',
        avatarPath: 'assets/images/natalie_avatar.png',
        avatarEmoji: 'N',
        avatarColor: Color(0xFF8774E1),
        unreadBadge: 0,
        isOnline: true,
      ),
      const TgAccount(
        id: 'sergei',
        name: 'Sergei',
        phone: '+7 999 123 4567',
        username: '@sergei_amos',
        bio: 'Developer & Team Lead',
        avatarPath: 'assets/images/sergei_avatar.png',
        avatarEmoji: 'S',
        avatarColor: Color(0xFF2F6FA8),
        unreadBadge: 31,
        isOnline: false,
      ),
      const TgAccount(
        id: 'caban',
        name: 'Ca BAn',
        phone: '+1 555 312 8901',
        username: '@caban_official',
        bio: 'Design & Media',
        avatarPath: '',
        avatarEmoji: 'CB',
        avatarColor: Color(0xFF4CAF50),
        unreadBadge: 7,
        isOnline: true,
      ),
    ];
  }

  void setSelectedChat(String accountId, String chatId) {
    _selectedChatPerAccount[accountId] = chatId;
  }

  String getSelectedChat(String accountId) {
    return _selectedChatPerAccount[accountId] ?? getChats(accountId).first.id;
  }

  List<TgChat> getChats(String accountId) {
    if (accountId == 'sergei') {
      return sergeiMockChats;
    } else if (accountId == 'caban') {
      return cabanMockChats;
    }
    return mockChats;
  }

  List<TgContact> getContacts(String accountId) {
    if (accountId == 'sergei') {
      return sergeiMockContacts;
    } else if (accountId == 'caban') {
      return cabanMockContacts;
    }
    return mockContacts;
  }

  void switchAccount(String id) {
    final target = accounts.value.firstWhere(
      (a) => a.id == id,
      orElse: () => accounts.value.first,
    );
    currentAccount.value = target;
    AppState.selectedChatId.value = getSelectedChat(target.id);
  }

  void updateCurrentAccount({
    String? name,
    String? phone,
    String? username,
    String? bio,
    String? avatarPath,
  }) {
    final cur = currentAccount.value;
    final updated = cur.copyWith(
      name: name,
      phone: phone,
      username: username,
      bio: bio,
      avatarPath: avatarPath,
    );
    currentAccount.value = updated;
    accounts.value = accounts.value.map((a) => a.id == updated.id ? updated : a).toList();
  }

  void addAccount(TgAccount newAcc) {
    accounts.value = [...accounts.value, newAcc];
    currentAccount.value = newAcc;
    AppState.selectedChatId.value = getSelectedChat(newAcc.id);
  }
}

