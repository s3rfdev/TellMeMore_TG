import 'package:flutter/material.dart';

enum AppLanguage { ru, en }

class I18n {
  I18n._();

  static final I18n instance = I18n._();

  final ValueNotifier<AppLanguage> currentLanguage =
      ValueNotifier<AppLanguage>(AppLanguage.ru);

  AppLanguage get lang => currentLanguage.value;

  bool get isRu => currentLanguage.value == AppLanguage.ru;

  void setLanguage(AppLanguage language) {
    currentLanguage.value = language;
  }

  static String t(String key) => instance.translate(key);

  String translate(String key) {
    final map = isRu ? _ruStrings : _enStrings;
    return map[key] ?? _ruStrings[key] ?? key;
  }

  static const Map<String, String> _ruStrings = {
    // Navigation
    'chats': 'Чаты',
    'contacts': 'Контакты',
    'copilot': 'AI Copilot',
    'settings': 'Настройки',
    'archived_chats': 'В архиве',
    'search': 'Поиск',
    'search_chats_or_msgs': 'Поиск по чатам и сообщениям...',
    'search_contacts': 'Поиск контактов...',
    'no_results': 'Ничего не найдено',
    'no_contacts': 'Контакты не найдены',
    'invite_friends': 'Пригласить друзей',
    'recent_calls': 'Недавние звонки',
    'sorted_by_name': 'По алфавиту',

    // Status
    'online': 'в сети',
    'offline': 'не в сети',
    'last_seen_recently': 'был(а) недавно',
    'last_seen': 'был(а)',
    'members': 'участников',

    // Chat
    'write_message': 'Сообщение...',
    'reply': 'Ответить',
    'forward': 'Переслать',
    'copy_text': 'Копировать текст',
    'pin': 'Закрепить',
    'delete': 'Удалить',
    'save_to_downloads': 'Сохранить в Загрузки',
    'call': 'Звонок',
    'ai_dossier': 'Досье и анализ чата',
    'options': 'Опции',

    // Profile & Menu
    'profile': 'Профиль',
    'edit_info': 'Изм. данные',
    'set_photo': 'Сменить фото',
    'settings_title': 'Настройки',
    'posts': 'Посты',
    'archived_posts': 'Архив постов',
    'add_post': 'Добавить пост',
    'no_posts_yet': 'Пока нет ни одного поста',
    'first_name': 'Имя',
    'last_name': 'Фамилия',
    'bio': 'О себе',
    'phone': 'Номер телефона',
    'username': 'Имя пользователя',
    'birthday': 'День рождения',
    'personal_channel': 'Личный канал',
    'chat_automation': 'Автоответчик (Chat Automation)',
    'accounts': 'Аккаунты',
    'add_account': 'Добавить аккаунт',
    'log_out': 'Выйти из аккаунта',
    'delete_account': 'Удалить аккаунт',
    'cancel': 'Отмена',
    'save': 'Сохранить',
    'done': 'Готово',
    'close': 'Закрыть',

    // Settings
    'account_settings': 'Мой аккаунт',
    'chat_settings': 'Настройки чатов',
    'privacy_security': 'Конфиденциальность',
    'notifications_sounds': 'Уведомления и звуки',
    'ai_copilot_settings': 'AI Copilot & Модели',
    'data_storage': 'Данные и память',
    'chat_folders': 'Папки с чатами',
    'devices': 'Устройства',
    'language': 'Язык',
    'all_accounts': 'Все аккаунты',
    'private_chats': 'Личные чаты',
    'groups': 'Группы',
    'channels': 'Каналы',
    'stories': 'Истории',
    'reactions': 'Реакции',
    'calls': 'Звонки',
    'vibrate': 'Вибрация',
    'ringtone': 'Мелодия звонка',
    'badge_counter': 'Счетчик непрочитанных',
    'events': 'События',
    'other': 'Другое',
    'contact_joined': 'Контакт присоединился к Telegram',
    'pinned_messages': 'Закрепленные сообщения',
    'keep_alive': 'Фоновая служба',
    'background_conn': 'Фоновое соединение',

    // Add Account Dialog
    'add_account_dialog_title': 'Добавить аккаунт',
    'login_qr_tab': 'Вход по QR-коду',
    'login_phone_tab': 'По номеру телефона',
    'qr_step_1': 'Откройте Telegram на телефоне',
    'qr_step_2': 'Перейдите в Настройки > Устройства > Привязать устройство',
    'qr_step_3': 'Наведите камеру телефона на этот экран',
    'login_by_phone_btn': 'Войти по номеру телефона',
    'phone_number_label': 'Номер телефона',
    'phone_number_hint': '+7 999 123-45-67',
    'country_label': 'Страна',
    'keep_signed_in': 'Оставаться в системе',
    'next_btn': 'Продолжить',
    'enter_code_title': 'Введите код подтверждения',
    'code_sent_hint': 'Код отправлен в ваше приложение Telegram или по SMS',
    'code_input_label': 'Код из Telegram',
    'verify_and_login': 'Войти в аккаунт',

    // Confirm dialogs
    'log_out_confirm_title': 'Выйти из аккаунта?',
    'log_out_confirm_msg': 'Вы действительно хотите выйти из аккаунта {name} ({phone})? Сессия на этом устройстве будет завершена.',
    'delete_account_confirm_title': 'Удалить аккаунт?',
    'delete_account_confirm_msg': 'Вы действительно хотите удалить аккаунт {name} из приложения? Все локальные настройки этого профиля будут удалены.',
  };

  static const Map<String, String> _enStrings = {
    // Navigation
    'chats': 'Chats',
    'contacts': 'Contacts',
    'copilot': 'AI Copilot',
    'settings': 'Settings',
    'archived_chats': 'Archived Chats',
    'search': 'Search',
    'search_chats_or_msgs': 'Search chats and messages...',
    'search_contacts': 'Search contacts...',
    'no_results': 'Nothing found',
    'no_contacts': 'No contacts found',
    'invite_friends': 'Invite Friends',
    'recent_calls': 'Recent calls',
    'sorted_by_name': 'Sorted by name',

    // Status
    'online': 'online',
    'offline': 'offline',
    'last_seen_recently': 'last seen recently',
    'last_seen': 'last seen',
    'members': 'members',

    // Chat
    'write_message': 'Write a message...',
    'reply': 'Reply',
    'forward': 'Forward',
    'copy_text': 'Copy text',
    'pin': 'Pin',
    'delete': 'Delete',
    'save_to_downloads': 'Save to Downloads',
    'call': 'Call',
    'ai_dossier': 'Dossier & Chat Analysis',
    'options': 'Options',

    // Profile & Menu
    'profile': 'Profile',
    'edit_info': 'Edit Info',
    'set_photo': 'Set Photo',
    'settings_title': 'Settings',
    'posts': 'Posts',
    'archived_posts': 'Archived Posts',
    'add_post': 'Add a post',
    'no_posts_yet': 'No posts yet',
    'first_name': 'First name',
    'last_name': 'Last name',
    'bio': 'Bio',
    'phone': 'Phone number',
    'username': 'Username',
    'birthday': 'Birthday',
    'personal_channel': 'Personal channel',
    'chat_automation': 'Chat Automation',
    'accounts': 'Accounts',
    'add_account': 'Add Account',
    'log_out': 'Log Out',
    'delete_account': 'Delete Account',
    'cancel': 'Cancel',
    'save': 'Save',
    'done': 'Done',
    'close': 'Close',

    // Settings
    'account_settings': 'My Account',
    'chat_settings': 'Chat Settings',
    'privacy_security': 'Privacy and Security',
    'notifications_sounds': 'Notifications and Sounds',
    'ai_copilot_settings': 'AI Copilot & Models',
    'data_storage': 'Data and Storage',
    'chat_folders': 'Chat Folders',
    'devices': 'Devices',
    'language': 'Language',
    'all_accounts': 'All Accounts',
    'private_chats': 'Private Chats',
    'groups': 'Groups',
    'channels': 'Channels',
    'stories': 'Stories',
    'reactions': 'Reactions',
    'calls': 'Calls',
    'vibrate': 'Vibrate',
    'ringtone': 'Ringtone',
    'badge_counter': 'Badge Counter',
    'events': 'Events',
    'other': 'Other',
    'contact_joined': 'Contact joined Telegram',
    'pinned_messages': 'Pinned Messages',
    'keep_alive': 'Keep-Alive Service',
    'background_conn': 'Background Connection',

    // Add Account Dialog
    'add_account_dialog_title': 'Add Account',
    'login_qr_tab': 'Log in by QR Code',
    'login_phone_tab': 'Log in by Phone',
    'qr_step_1': 'Open Telegram on your phone',
    'qr_step_2': 'Go to Settings > Devices > Link Desktop Device',
    'qr_step_3': 'Point your phone at this screen to confirm login',
    'login_by_phone_btn': 'Log in using phone number',
    'phone_number_label': 'Phone Number',
    'phone_number_hint': '+1 234 567-8900',
    'country_label': 'Country',
    'keep_signed_in': 'Keep me signed in',
    'next_btn': 'Next',
    'enter_code_title': 'Enter confirmation code',
    'code_sent_hint': 'Code sent to your Telegram app or via SMS',
    'code_input_label': 'Telegram Code',
    'verify_and_login': 'Verify & Log in',

    // Confirm dialogs
    'log_out_confirm_title': 'Log Out?',
    'log_out_confirm_msg': 'Are you sure you want to log out of {name} ({phone})? Your local session on this device will be terminated.',
    'delete_account_confirm_title': 'Delete Account?',
    'delete_account_confirm_msg': 'Are you sure you want to delete account {name} from this application? All local preferences will be cleared.',
  };
}

String tr(String key) => I18n.t(key);
