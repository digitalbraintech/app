import 'package:flutter/widgets.dart';
import 'package:rfw/rfw.dart' show RemoteEventHandler;

import 'ui_button.dart';
import 'ui_panel.dart';
import 'ui_screen.dart';
import 'ui_text.dart';
import 'ui_text_field.dart';

// Maps lower-cased `ui:*` type strings to cover widgets.
// Returns null for unknown types so callers can fall back.
Widget? buildUiNode(
  String type,
  Map<String, Object?> props,
  List<Object?> childrenList,
  RemoteEventHandler onEvent, {
  required Widget Function(Map<String, Object?>) buildChild,
}) {
  final children = childrenList
      .whereType<Map<String, Object?>>()
      .map(buildChild)
      .toList();

  switch (type.toLowerCase()) {
    case 'ui:screen':
      return UiKitScreen(
        child: children.isNotEmpty
            ? children.first
            : const SizedBox.shrink(),
      );

    case 'ui:text':
      return UiKitText(text: (props['text'] as String?) ?? '');

    case 'ui:textfield':
      return UiKitTextField(
        name: (props['name'] as String?) ?? '',
        hint: props['hint'] as String?,
        label: props['label'] as String?,
      );

    case 'ui:button':
      return UiKitButton(
        label: (props['label'] as String?) ?? '',
        pack: (props['pack'] as String?) ?? '',
        experienceId: (props['experienceId'] as String?) ?? '',
        eventName: (props['eventName'] as String?) ?? '',
        onEvent: onEvent,
      );

    case 'ui:panel':
      return UiKitPanel(
        title: props['title'] as String?,
        subtitle: props['subtitle'] as String?,
        child: children.isNotEmpty ? children.first : null,
      );

    default:
      return null;
  }
}
