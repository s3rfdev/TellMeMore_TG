import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tg_answer/core/localization/app_locale.dart';
import 'package:tg_answer/features/ai_copilot/screens/ai_copilot_screen.dart';
import 'package:tg_answer/features/ai_copilot/screens/ai_settings_screen.dart';
import 'package:tg_answer/features/settings/widgets/settings_sidebar_view.dart';
import 'package:tg_answer/shell/home_shell.dart';
import 'package:tg_answer/state/app_state.dart';

void main() {
  setUp(() {
    I18n.instance.setLanguage(AppLanguage.ru);
    AppState.demoMode.value = true;
    AppState.activeSidebarTab.value = SidebarTab.settings;
    AppState.activeSettingsSection.value = SettingsSection.profile;
  });

  group('Adaptive Navigation & Back Button Tests', () {
    testWidgets('AiSettingsScreen renders back button when showBack is true and invokes onBack', (tester) async {
      bool backTapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AiSettingsScreen(
              showBack: true,
              onBack: () => backTapped = true,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final backBtn = find.byTooltip('Назад');
      expect(backBtn, findsOneWidget);

      await tester.tap(backBtn);
      await tester.pump(const Duration(milliseconds: 100));
      expect(backTapped, isTrue);
    });

    testWidgets('AiCopilotScreen renders back button when showBack is true and invokes onBack', (tester) async {
      bool backTapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AiCopilotScreen(
              showBack: true,
              onBack: () => backTapped = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final backBtn = find.byTooltip('Назад');
      expect(backBtn, findsOneWidget);

      await tester.tap(backBtn);
      await tester.pumpAndSettle();
      expect(backTapped, isTrue);
    });

    testWidgets('SettingsSidebarView onSectionSelected callback is called when section is selected', (tester) async {
      bool sectionSelected = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 700,
              child: SettingsSidebarView(
                onSectionSelected: () => sectionSelected = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Автопилот'));
      await tester.pumpAndSettle();
      expect(sectionSelected, isTrue);
      expect(AppState.activeSettingsSection.value, SettingsSection.autopilot);
    });

    testWidgets('HomeShell on narrow screen (mobile) provides back navigation from Settings to Sidebar', (tester) async {
      // Set tester window to mobile phone size (400x800)
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      AppState.activeSidebarTab.value = SidebarTab.settings;
      AppState.activeSettingsSection.value = SettingsSection.general;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HomeShell(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // In Settings tab on mobile, initially sidebar is visible
      final sidebarSectionTile = find.descendant(
        of: find.byType(SettingsSidebarView),
        matching: find.text('Общие настройки'),
      );
      expect(sidebarSectionTile, findsOneWidget);

      // Tap on section to enter detail
      await tester.tap(sidebarSectionTile);
      await tester.pumpAndSettle();

      // Back button should now be accessible in header
      final backBtn = find.byTooltip('Назад');
      expect(backBtn, findsOneWidget);

      // Tap back button: should return to sidebar
      await tester.tap(backBtn);
      await tester.pumpAndSettle();

      // SettingsSidebarView header is visible
      expect(find.text('Настройки'), findsWidgets);
    });
  });
}
