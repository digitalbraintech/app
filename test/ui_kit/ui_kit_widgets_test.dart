import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';

import 'package:digitalbrain_flutter/ui_kit/ui_form_scope.dart';
import 'package:digitalbrain_flutter/ui_kit/ui_screen.dart';
import 'package:digitalbrain_flutter/ui_kit/ui_text.dart';
import 'package:digitalbrain_flutter/ui_kit/ui_text_field.dart';
import 'package:digitalbrain_flutter/ui_kit/ui_button.dart';
import 'package:digitalbrain_flutter/ui_kit/ui_panel.dart';

Widget _wrap(Widget child) => MaterialApp(
  builder: (_, w) => FTheme(
    data: FThemes.neutral.light.touch,
    child: w!,
  ),
  home: Scaffold(body: child),
);

void main() {
  group('UiKitFormScope', () {
    test('controller.set stores values and notifies', () {
      final controller = UiKitFormController();
      var notified = false;
      controller.addListener(() => notified = true);

      controller.set('name', 'Alice');

      expect(controller.values['name'], 'Alice');
      expect(notified, isTrue);
      controller.dispose();
    });

    test('values map is unmodifiable', () {
      final controller = UiKitFormController();
      controller.set('x', '1');
      expect(() => controller.values['x'] = 'oops', throwsUnsupportedError);
      controller.dispose();
    });
  });

  group('UiKitScreen', () {
    testWidgets('wraps child in UiKitFormScope', (tester) async {
      UiKitFormController? capturedController;

      await tester.pumpWidget(
        _wrap(
          UiKitScreen(
            child: Builder(
              builder: (ctx) {
                capturedController = UiKitFormScope.of(ctx);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(capturedController, isNotNull);
    });
  });

  group('UiKitText', () {
    testWidgets('renders the text string', (tester) async {
      await tester.pumpWidget(_wrap(const UiKitText(text: 'Hello World')));
      expect(find.text('Hello World'), findsOneWidget);
    });
  });

  group('UiKitTextField', () {
    testWidgets('writes typed value into scope', (tester) async {
      final controller = UiKitFormController();

      await tester.pumpWidget(
        MaterialApp(
          builder: (_, w) => FTheme(
            data: FThemes.neutral.light.touch,
            child: w!,
          ),
          home: Scaffold(
            body: UiKitFormScope(
              controller: controller,
              child: const UiKitTextField(name: 'email', hint: 'you@example.com'),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(EditableText), 'test@example.com');
      await tester.pump();

      expect(controller.values['email'], 'test@example.com');
      controller.dispose();
    });
  });

  group('UiKitButton', () {
    testWidgets('fires onEvent with correct payload including scope values',
        (tester) async {
      final controller = UiKitFormController();
      controller.set('email', 'alice@example.com');

      String? capturedName;
      Map<String, Object?>? capturedArgs;

      await tester.pumpWidget(
        MaterialApp(
          builder: (_, w) => FTheme(
            data: FThemes.neutral.light.touch,
            child: w!,
          ),
          home: Scaffold(
            body: UiKitFormScope(
              controller: controller,
              child: UiKitButton(
                label: 'Submit',
                pack: 'onboarding',
                experienceId: 'welcome',
                eventName: 'submit',
                onEvent: (name, args) {
                  capturedName = name;
                  capturedArgs = args;
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      expect(capturedName, 'press');
      expect(capturedArgs?['synapseType'], 'ExperienceStep');
      final props = capturedArgs?['props'] as Map<String, Object?>;
      expect(props['pack'], 'onboarding');
      expect(props['experienceId'], 'welcome');
      expect(props['eventName'], 'submit');
      expect(props['email'], 'alice@example.com');
      controller.dispose();
    });

    testWidgets('renders button label', (tester) async {
      await tester.pumpWidget(
        _wrap(
          UiKitButton(
            label: 'Go',
            pack: 'p',
            experienceId: 'e',
            eventName: 'n',
            onEvent: (_, _) {},
          ),
        ),
      );
      expect(find.text('Go'), findsOneWidget);
    });
  });

  group('UiKitPanel', () {
    testWidgets('renders title and child', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const UiKitPanel(
            title: 'My Panel',
            child: Text('panel content'),
          ),
        ),
      );
      expect(find.text('My Panel'), findsOneWidget);
      expect(find.text('panel content'), findsOneWidget);
    });
  });
}
