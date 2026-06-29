import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:digitalbrain_flutter/ui_kit/ui_alert.dart';

Widget _host(Widget child) => MaterialApp(
      home: FTheme(data: FThemes.neutral.light.touch, child: FScaffold(child: child)),
    );

void main() {
  testWidgets('Alert shows title and subtitle', (tester) async {
    await tester.pumpWidget(_host(const UiKitAlert(title: 'Heads up', subtitle: 'details')));
    expect(find.text('Heads up'), findsOneWidget);
    expect(find.text('details'), findsOneWidget);
  });
}
