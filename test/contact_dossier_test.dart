import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tg_answer/data/models/tg_chat.dart';
import 'package:tg_answer/features/ai_copilot/models/contact_dossier.dart';
import 'package:tg_answer/features/ai_copilot/services/copilot_session_store.dart';
import 'package:tg_answer/features/ai_copilot/widgets/contact_dossier_sheet.dart';
import 'package:tg_answer/state/app_state.dart';

void main() {
  testWidgets('ContactDossierDialog has expandable 1-to-7 line fields for goal and psychotype', (tester) async {
    tester.view.physicalSize = const Size(1280, 960);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    const testChat = TgChat(
      id: 'test-dossier-chat',
      title: 'Иван Тестовый',
      sender: 'Иван',
      preview: 'Привет',
      time: '12:00',
      headerSubtitle: 'был(а) недавно',
      avatarEmoji: '👤',
      avatarColor: 0xFF51B2FF,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => ContactDossierDialog.show(context, testChat),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    // Open dialog
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final mainScrollable = find.byWidgetPredicate(
      (w) => w is Scrollable && (w.axisDirection == AxisDirection.down || w.axisDirection == AxisDirection.up),
    ).first;

    // Verify dialog title & goal section
    expect(find.text('Цель общения с контактом'), findsOneWidget);

    final goalFinder = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.hintText?.contains('цель общения') == true,
    );
    expect(goalFinder, findsOneWidget);
    final goalField = tester.widget<TextField>(goalFinder);
    expect(goalField.minLines, 1);
    expect(goalField.maxLines, 7);
    expect(goalField.keyboardType, TextInputType.multiline);

    // Scroll to find psychotype section
    final psychotypeFinder = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.hintText?.contains('психотип') == true,
    );
    await tester.scrollUntilVisible(psychotypeFinder, 100, scrollable: mainScrollable);
    expect(psychotypeFinder, findsOneWidget);

    final psychotypeField = tester.widget<TextField>(psychotypeFinder);
    expect(psychotypeField.minLines, 1);
    expect(psychotypeField.maxLines, 7);
    expect(psychotypeField.keyboardType, TextInputType.multiline);

    // Enter a multiline text into goal field
    await tester.scrollUntilVisible(goalFinder, -100, scrollable: mainScrollable);
    await tester.enterText(
      goalFinder,
      'Строка 1\nСтрока 2\nСтрока 3\nСтрока 4\nСтрока 5\nСтрока 6\nСтрока 7\nСтрока 8 (скролл)',
    );
    await tester.pump();

    // Enter multiline text into psychotype field
    await tester.scrollUntilVisible(psychotypeFinder, 100, scrollable: mainScrollable);
    await tester.enterText(
      psychotypeFinder,
      'Психотип:\n- Внимание к деталям\n- Аналитический склад\n- Высокая скорость реакции',
    );
    await tester.pump();

    // Save changes
    final saveButtonFinder = find.text('Сохранить изменения');
    expect(saveButtonFinder, findsOneWidget);
    await tester.tap(saveButtonFinder);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));

    // Verify stored dossier
    final savedDossier = ContactDossierStore.instance.getDossier('test-dossier-chat').value;
    expect(savedDossier.goal, contains('Строка 8 (скролл)'));
    expect(savedDossier.psychotype, contains('Аналитический склад'));
  });

  testWidgets('Clicking Чат с Copilot по контакту opens Copilot session and switches tab', (tester) async {
    tester.view.physicalSize = const Size(1280, 960);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    AppState.activeSidebarTab.value = SidebarTab.chats;

    const testChat = TgChat(
      id: 'dossier-copilot-chat',
      title: 'Алексей Инвестор',
      sender: 'Алексей',
      preview: 'Жду финмодель',
      time: '14:20',
      headerSubtitle: 'в сети',
      avatarEmoji: '💼',
      avatarColor: 0xFF8774E1,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => ContactDossierDialog.show(context, testChat),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    // Open dialog
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Tap "Чат с Copilot по контакту"
    final copilotBtn = find.text('Чат с Copilot по контакту');
    expect(copilotBtn, findsOneWidget);
    await tester.tap(copilotBtn);
    await tester.pumpAndSettle();

    // Verify tab switched to copilot
    expect(AppState.activeSidebarTab.value, SidebarTab.copilot);

    // Verify Copilot session created
    final sessions = CopilotSessionStore.instance.sessions.value;
    final createdSession = sessions.firstWhere((s) => s.id == 'contact_dossier-copilot-chat');
    expect(createdSession.title, contains('Алексей Инвестор'));
    expect(createdSession.systemPrompt, contains('Алексей Инвестор'));
    expect(CopilotSessionStore.instance.activeSessionId.value, 'contact_dossier-copilot-chat');
  });
}
