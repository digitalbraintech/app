import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:digitalbrain_flutter/ui_kit/ui_dialog.dart';

void main() {
  testWidgets('Dialog with open:true presents its title', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: FToaster(
        child: FTheme(
          data: FThemes.neutral.light.touch,
          child: FScaffold(
            child: UiKitDialog(open: true, title: 'Confirm', children: const [Text('Sure?')]),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Confirm'), findsOneWidget);
    expect(find.text('Sure?'), findsOneWidget);
  });
}
