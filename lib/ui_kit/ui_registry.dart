import 'package:flutter/widgets.dart';
import 'package:rfw/rfw.dart' show RemoteEventHandler;

import 'ui_button.dart';
import 'ui_panel.dart';
import 'ui_screen.dart';
import 'ui_text.dart';
import 'ui_text_field.dart';

// Maps a ui:* node (type already lower-cased by the tree renderer) to its ForUI cover widget.
// [buildChild] recurses back into the tree renderer for container children (ui:Screen, ui:Panel).
// Returns SizedBox.shrink() for unknown types — Task 6 expects a non-null Widget.
Widget buildUiNode(
  String type,
  Map<String, Object?> props,
  List childrenList,
  RemoteEventHandler onEvent, {
  required Widget Function(Map<String, Object?>) buildChild,
}) {
  List<Widget> kids() =>
      childrenList.cast<Map<String, Object?>>().map(buildChild).toList();
  String s(String key) => (props[key] ?? '').toString();

  switch (type.toLowerCase()) {
    case 'ui:screen':
      return UiKitScreen(children: kids());
    case 'ui:panel':
      return UiKitPanel(children: kids());
    case 'ui:text':
      return UiKitText(text: s('text'));
    case 'ui:textfield':
      return UiKitTextField(name: s('name'), placeholder: s('placeholder'));
    case 'ui:button':
      return UiKitButton(
        label: s('label'),
        pack: s('pack'),
        experienceId: s('experienceId'),
        eventName: s('eventName'),
        onEvent: onEvent,
      );
    default:
      return const SizedBox.shrink();
  }
}
