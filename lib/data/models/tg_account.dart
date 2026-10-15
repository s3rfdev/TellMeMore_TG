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

class TgPost {
  const TgPost({
    required this.id,
    required this.text,
    this.mediaPath = '',
    this.mediaUrl = '',
    required this.date,
    this.views = 0,
    this.likes = 0,
    this.isArchived = false,
  });

  final String id;
  final String text;
  final String mediaPath;
  final String mediaUrl;
  final DateTime date;
  final int views;
  final int likes;
  final bool isArchived;

  TgPost copyWith({
    String? id,
    String? text,
    String? mediaPath,
    String? mediaUrl,
    DateTime? date,
    int? views,
    int? likes,
    bool? isArchived,
  }) {
    return TgPost(
      id: id ?? this.id,
      text: text ?? this.text,
      mediaPath: mediaPath ?? this.mediaPath,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      date: date ?? this.date,
      views: views ?? this.views,
      likes: likes ?? this.likes,
      isArchived: isArchived ?? this.isArchived,
    );
  }
}

class AccountManager {
  AccountManager._() {
    _initDefaults();
  }

  static final AccountManager instance = AccountManager._();

  final Map<String, String> _selectedChatPerAccount = {
    'sergei': 'amos-core',
    'natalie': 'taras',
    'caban': 'caban-marketing',
  };

  final ValueNotifier<List<TgAccount>> accounts = ValueNotifier<List<TgAccount>>([]);
  final ValueNotifier<TgAccount> currentAccount = ValueNotifier<TgAccount>(
    const TgAccount(
      id: 'sergei',
      name: 'Сергей',
      phone: '+7 928 296 50 54',
      username: '',
      bio: '',
      avatarPath: '',
      avatarEmoji: 'S',
      avatarColor: Color(0xFF2F6FA8),
      unreadBadge: 0,
      isOnline: true,
    ),
  );

  final ValueNotifier<List<TgPost>> myPosts = ValueNotifier<List<TgPost>>([]);
  final ValueNotifier<List<TgPost>> myArchivedPosts = ValueNotifier<List<TgPost>>([]);
  final ValueNotifier<bool> isSyncingProfile = ValueNotifier<bool>(false);

  void _initDefaults() {
    accounts.value = [
      const TgAccount(
        id: 'sergei',
        name: 'Сергей',
        phone: '+7 928 296 50 54',
        username: '',
        bio: '',
        avatarPath: '',
        avatarEmoji: 'S',
        avatarColor: Color(0xFF2F6FA8),
        unreadBadge: 0,
        isOnline: true,
      ),
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

  bool isRealTelegramUser = false;
  final ValueNotifier<List<TgContact>> realContacts = ValueNotifier<List<TgContact>>([]);
  final Map<String, List<TgContact>> _contactsPerAccount = {};

  void setContacts(List<TgContact> contacts, {String? accountId}) {
    final accId = accountId ?? currentAccount.value.id;
    _contactsPerAccount[accId] = contacts;
    realContacts.value = contacts;
  }

  List<TgContact> getContacts(String accountId) {
    if (_contactsPerAccount.containsKey(accountId) && _contactsPerAccount[accountId]!.isNotEmpty) {
      return _contactsPerAccount[accountId]!;
    }
    if (realContacts.value.isNotEmpty && (accountId == 'sergei' || accountId == currentAccount.value.id)) {
      return realContacts.value;
    }
    if (isRealTelegramUser && (accountId == 'sergei' || accountId == currentAccount.value.id)) {
      return const [];
    }
    if (accountId == 'sergei') {
      return sergeiMockContacts;
    } else if (accountId == 'caban') {
      return cabanMockContacts;
    }
    return mockContacts;
  }

  void syncAuthorizedUser(TgUser user, {String? bio, String? avatarPath}) {
    isRealTelegramUser = true;
    final cur = accounts.value.firstWhere(
      (a) => a.id == 'sergei',
      orElse: () => accounts.value.first,
    );
    final fullName = user.fullName.trim();
    final name = fullName.isNotEmpty ? fullName : cur.name;
    final rawPhone = user.phoneNumber.trim();
    final phone = rawPhone.isNotEmpty
        ? (rawPhone.startsWith('+') ? rawPhone : '+$rawPhone')
        : cur.phone;
    final username = user.username.isNotEmpty ? '@${user.username}' : cur.username;
    final newBio = bio ?? cur.bio;
    final newAvatar = avatarPath ?? cur.avatarPath;
    final updated = cur.copyWith(
      name: name,
      phone: phone,
      username: username,
      bio: newBio,
      avatarPath: newAvatar,
      isOnline: true,
    );
    accounts.value = accounts.value.map((a) => a.id == updated.id ? updated : a).toList();
    if (currentAccount.value.id == updated.id) {
      currentAccount.value = updated;
    }
  }

  void syncBio(String bio) {
    final cur = currentAccount.value;
    final updated = cur.copyWith(bio: bio);
    currentAccount.value = updated;
    accounts.value = accounts.value.map((a) => a.id == updated.id ? updated : a).toList();
  }

  void syncAvatar(String avatarPath) {
    final cur = currentAccount.value;
    final updated = cur.copyWith(avatarPath: avatarPath);
    currentAccount.value = updated;
    accounts.value = accounts.value.map((a) => a.id == updated.id ? updated : a).toList();
  }

  void mergeProfilePhotos(List<TgPost> activePhotoPosts, List<TgPost> archivedPhotoPosts) {
    myArchivedPosts.value = archivedPhotoPosts;
    final current = myPosts.value;
    final channelPosts = current.where((p) => !p.text.contains('Фото профиля')).toList();
    final combined = <TgPost>[...channelPosts, ...activePhotoPosts];
    final seen = <String>{};
    final unique = <TgPost>[];
    for (final p in combined) {
      if (seen.add(p.id)) unique.add(p);
    }
    myPosts.value = unique;
  }

  void setChannelPosts(List<TgPost> channelPosts) {
    final current = myPosts.value;
    final preserved = current.where((p) => p.id.startsWith('local_') || p.id.startsWith('test_') || p.text.contains('Фото профиля')).toList();
    final combined = <TgPost>[...channelPosts, ...preserved];
    final seen = <String>{};
    final unique = <TgPost>[];
    for (final p in combined) {
      if (seen.add(p.id)) unique.add(p);
    }
    myPosts.value = unique;
  }

  void updatePostMedia(String postId, String path) {
    myPosts.value = myPosts.value.map((p) => p.id == postId ? p.copyWith(mediaPath: path) : p).toList();
    myArchivedPosts.value = myArchivedPosts.value.map((p) => p.id == postId ? p.copyWith(mediaPath: path) : p).toList();
  }

  void setPosts(List<TgPost> posts, {bool isArchived = false}) {
    if (isArchived) {
      myArchivedPosts.value = posts;
    } else {
      myPosts.value = posts;
    }
  }

  void addPost(TgPost post, {bool isArchived = false}) {
    if (isArchived) {
      myArchivedPosts.value = [post, ...myArchivedPosts.value];
    } else {
      myPosts.value = [post, ...myPosts.value];
    }
  }

  void deletePost(String postId) {
    myPosts.value = myPosts.value.where((p) => p.id != postId).toList();
    myArchivedPosts.value = myArchivedPosts.value.where((p) => p.id != postId).toList();
  }

  void clearChannelPosts() {
    myPosts.value = myPosts.value.where((p) => p.text.contains('Фото профиля')).toList();
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

  void removeAccount(String id) {
    final list = accounts.value.where((a) => a.id != id).toList();
    if (list.isEmpty) return;
    accounts.value = list;
    if (currentAccount.value.id == id) {
      currentAccount.value = list.first;
      AppState.selectedChatId.value = getSelectedChat(list.first.id);
    }
  }
}

