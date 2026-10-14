import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tg_answer/core/utils/link_handler.dart';
import 'package:tg_answer/state/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LinkHandler Tests', () {
    test('Regex correctly captures @mentions, http/https, and t.me links', () {
      final sample = 'Свяжись со мной @s3rf_im или @crypto_fin_hr, сайт https://google.com или t.me/durov';
      final matches = LinkHandler.linkRegex.allMatches(sample).map((m) => m.group(0)).toList();

      expect(matches, contains('@s3rf_im'));
      expect(matches, contains('@crypto_fin_hr'));
      expect(matches, contains('https://google.com'));
      expect(matches, contains('t.me/durov'));
    });

    testWidgets('buildSpans generates interactive clickable TextSpans', (tester) async {
      late BuildContext testContext;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              testContext = context;
              final spans = LinkHandler.buildSpans(
                context: context,
                text: 'Привет @taras перейди на https://flutter.dev',
                outgoing: false,
              );
              return Scaffold(
                body: SelectableText.rich(
                  TextSpan(children: spans),
                ),
              );
            },
          ),
        ),
      );

      final spans = LinkHandler.buildSpans(
        context: testContext,
        text: 'Привет @taras перейди на https://flutter.dev',
        outgoing: false,
      );

      expect(spans.length, 4);
      expect(spans[0].toPlainText(), 'Привет ');
      expect(spans[1].toPlainText(), '@taras');
      expect((spans[1] as TextSpan).recognizer, isA<TapGestureRecognizer>());
      expect((spans[1] as TextSpan).mouseCursor, SystemMouseCursors.click);

      expect(spans[2].toPlainText(), ' перейди на ');
      expect(spans[3].toPlainText(), 'https://flutter.dev');
      expect((spans[3] as TextSpan).recognizer, isA<TapGestureRecognizer>());
      expect((spans[3] as TextSpan).mouseCursor, SystemMouseCursors.click);
    });

    testWidgets('Clicking @taras opens chat and switches to chats tab', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  LinkHandler.openLink(context, '@taras');
                },
                child: const Text('Open Taras'),
              );
            },
          ),
        ),
      );

      // Start on copilot tab
      AppState.activeSidebarTab.value = SidebarTab.copilot;
      AppState.selectedChatId.value = 'none';

      await tester.tap(find.text('Open Taras'));
      await tester.pump();

      // Verified: switches to chats tab and selects chat 'taras'
      expect(AppState.activeSidebarTab.value, SidebarTab.chats);
      expect(AppState.selectedChatId.value, 'taras');

      // Let TgToast auto-dismiss timer finish
      await tester.pump(const Duration(seconds: 3));
    });
  });
}
