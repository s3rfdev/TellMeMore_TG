import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tg_answer/core/localization/app_locale.dart';
import 'package:tg_answer/data/models/tg_account.dart';
import 'package:tg_answer/features/contacts/models/tg_contact.dart';
import 'package:tg_answer/features/contacts/contacts_list_view.dart';
import 'package:tg_answer/features/settings/widgets/settings_sidebar_view.dart';
import 'package:tg_answer/state/app_state.dart';

void main() {
  setUp(() {
    I18n.instance.setLanguage(AppLanguage.ru);
    AppState.activeSidebarTab.value = SidebarTab.settings;
    AppState.activeSettingsSection.value = SettingsSection.profile;
  });

  group('Settings Navigation & Sidebar Tests', () {
    testWidgets('SettingsSidebarView renders all 6 sections and updates activeSettingsSection', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 700,
              child: SettingsSidebarView(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check header title
      expect(find.text('Настройки'), findsOneWidget);

      // Check all 6 section titles
      expect(find.text('Профиль и аккаунт'), findsWidgets);
      expect(find.text('Общие настройки'), findsOneWidget);
      expect(find.text('Автопилот'), findsOneWidget);
      expect(find.text('Контекст и память'), findsOneWidget);
      expect(find.text('Распознавание речи'), findsOneWidget);
      expect(find.text('Кэш и базы данных'), findsOneWidget);

      // Tap on 'Автопилот'
      await tester.tap(find.text('Автопилот'));
      await tester.pumpAndSettle();
      expect(AppState.activeSettingsSection.value, SettingsSection.autopilot);

      // Tap on 'Кэш и базы данных'
      await tester.tap(find.text('Кэш и базы данных'));
      await tester.pumpAndSettle();
      expect(AppState.activeSettingsSection.value, SettingsSection.cache);

      // Tap on 'Контекст и память'
      await tester.tap(find.text('Контекст и память'));
      await tester.pumpAndSettle();
      expect(AppState.activeSettingsSection.value, SettingsSection.context);
    });
  });

  group('Contacts Filtering Tests', () {
    testWidgets('ContactsListView filters out ghost and empty-named contacts', (tester) async {
      AccountManager.instance.isRealTelegramUser = true;
      AccountManager.instance.setContacts([
        const TgContact(
          id: '1',
          name: '',
          username: '',
          phone: '',
          status: 'не в сети',
          avatarColor: 0xFF5288C1,
          avatarEmoji: '#',
          isOnline: false,
        ),
        const TgContact(
          id: '2',
          name: '#',
          username: '',
          phone: '',
          status: 'не в сети',
          avatarColor: 0xFF5288C1,
          avatarEmoji: '#',
          isOnline: false,
        ),
        const TgContact(
          id: '3',
          name: 'Удаленный аккаунт',
          username: '',
          phone: '',
          status: 'не в сети',
          avatarColor: 0xFF5288C1,
          avatarEmoji: '#',
          isOnline: false,
        ),
        const TgContact(
          id: '4',
          name: 'Алексей Смирнов',
          username: '@alex',
          phone: '+79991234567',
          status: 'в сети',
          avatarColor: 0xFF5288C1,
          avatarEmoji: 'АС',
          isOnline: true,
        ),
      ]);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 700,
              child: ContactsListView(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Only 'Алексей Смирнов' should be rendered, ghosts/deleted must be filtered
      expect(find.text('Алексей Смирнов'), findsOneWidget);
      expect(find.text('Удаленный аккаунт'), findsNothing);
      expect(find.text('#'), findsNothing);
    });
  });
}
