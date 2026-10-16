import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tg_answer/core/localization/app_locale.dart';
import 'package:tg_answer/data/models/tg_account.dart';
import 'package:tg_answer/features/chat_list/widgets/main_drawer.dart';
import 'package:tg_answer/features/profile/widgets/profile_accounts_section.dart';
import 'package:tg_answer/features/profile/widgets/profile_pane.dart';
import 'package:tg_answer/state/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    I18n.instance.setLanguage(AppLanguage.ru);
    AccountManager.instance.switchAccount('sergei');
    AppState.activeSidebarTab.value = SidebarTab.chats;
    AppState.drawerOpen.value = false;
  });

  group('MainDrawer Clean Unified Menu Tests', () {
    testWidgets('MainDrawer displays strictly 6 utility actions and removes redundant profile item', (tester) async {
      bool closed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MainDrawer(
              onClose: () => closed = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check strictly the 6 items exist
      expect(find.text('Создать группу'), findsOneWidget);
      expect(find.text('Создать канал'), findsOneWidget);
      expect(find.text('Контакты'), findsOneWidget);
      expect(find.text('Звонки'), findsOneWidget);
      expect(find.text('Избранное'), findsOneWidget);
      expect(find.text('Настройки'), findsOneWidget);

      // Verify redundant "Профиль" item is NOT in the drawer menu
      expect(find.text('Профиль'), findsNothing);

      // Verify "+ Добавить аккаунт" is not duplicated in drawer (moved to settings)
      expect(find.text('Добавить аккаунт'), findsNothing);

      // Tap on "Настройки"
      await tester.tap(find.text('Настройки'));
      await tester.pumpAndSettle();

      // Verify it invoked onClose and switched to SidebarTab.settings
      expect(closed, isTrue);
      expect(AppState.activeSidebarTab.value, SidebarTab.settings);
    });
  });

  group('Profile & Multi-Account Management in Settings Tests', () {
    testWidgets('ProfileAccountsSection displays all accounts and switches active account on tap', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ProfileAccountsSection(
                currentAccount: AccountManager.instance.currentAccount.value,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check section header
      expect(find.text('Аккаунты'), findsOneWidget);
      expect(find.text('Добавить аккаунт'), findsOneWidget);

      // Check that accounts are listed
      expect(find.text('Сергей'), findsOneWidget);
      expect(find.text('Natalie'), findsOneWidget);
      expect(find.text('Ca BAn'), findsOneWidget);

      // Sergei is active initially
      expect(find.text('Активен'), findsOneWidget);

      // Tap on 'Natalie' to switch account
      await tester.tap(find.text('Natalie'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));

      expect(AccountManager.instance.currentAccount.value.id, 'natalie');

      // Switch back to Sergei
      AccountManager.instance.switchAccount('sergei');
      expect(AccountManager.instance.currentAccount.value.id, 'sergei');
    });

    testWidgets('ProfilePane embeds ProfileAccountsSection seamlessly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 1000,
              child: ProfilePane(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // ProfilePane renders ProfileAccountsSection
      expect(find.byType(ProfileAccountsSection), findsOneWidget);
      expect(find.text('Аккаунты'), findsOneWidget);
      expect(find.text('Добавить аккаунт'), findsOneWidget);
    });
  });
}
