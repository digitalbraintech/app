import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:digitalbrain_flutter/ui_kit/ui_tile.dart';

Widget _host(Widget child) => MaterialApp(
      home: FTheme(data: FThemes.neutral.light.touch, child: FScaffold(child: child)),
    );

void main() {
  testWidgets('Tile shows title and fires ExperienceStep on tap when goTo set', (tester) async {
    Map<String, Object?>? captured;
    await tester.pumpWidget(_host(UiKitTile(
      title: 'Go', subtitle: 'sub', pack: 'p', experienceId: 'p', eventName: 'next',
      onEvent: (n, a) => captured = a,
    )));
    expect(find.text('Go'), findsOneWidget);
    await tester.tap(find.text('Go'));
    await tester.pumpAndSettle();
    final propsMap = captured!['props'] as Map<String, Object?>;
    expect(propsMap['eventName'], 'next');
  });
}
