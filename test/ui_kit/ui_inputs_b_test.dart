import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:digitalbrain_flutter/ui_kit/ui_registry.dart';
import 'package:digitalbrain_flutter/ui_kit/ui_select.dart';
import 'package:digitalbrain_flutter/ui_kit/ui_slider.dart';

void main() {
  test('registry maps inputs-b nodes to their covers', () {
    expect(
      buildUiNode('ui:select', {'name': 'c', 'options': const ['Red'], 'label': ''},
          const [], (_, __) {}, buildChild: (_) => const SizedBox()),
      isA<UiKitSelect>(),
    );
    expect(
      buildUiNode('ui:slider', {'name': 'l', 'min': 0.0, 'max': 10.0, 'label': ''},
          const [], (_, __) {}, buildChild: (_) => const SizedBox()),
      isA<UiKitSlider>(),
    );
  });

  testWidgets('Slider renders an FSlider', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: FTheme(
        data: FThemes.neutral.light.touch,
        child: FScaffold(
          child: UiKitSlider(name: 'level', min: 0, max: 10),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(FSlider), findsOneWidget);
  });
}
