import 'package:flutter/widgets.dart';
import 'package:rfw/rfw.dart' show RemoteEventHandler;

import 'ui_button.dart';
import 'ui_checkbox.dart';
import 'ui_column.dart';
import 'ui_date_field.dart';
import 'ui_divider.dart';
import 'ui_gap.dart';
import 'ui_header.dart';
import 'ui_panel.dart';
import 'ui_radio_group.dart';
import 'ui_row.dart';
import 'ui_screen.dart';
import 'ui_select.dart';
import 'ui_slider.dart';
import 'ui_switch.dart';
import 'ui_text.dart';
import 'ui_text_area.dart';
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
  List<String> optList(String key) =>
      (props[key] as List?)?.map((e) => e.toString()).toList() ?? const [];
  double d(String key) => (props[key] as num?)?.toDouble() ?? 0;

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
    case 'ui:checkbox':
      return UiKitCheckbox(name: s('name'), label: s('label'));
    case 'ui:switch':
      return UiKitSwitch(name: s('name'), label: s('label'));
    case 'ui:textarea':
      return UiKitTextArea(name: s('name'), placeholder: s('placeholder'));
    case 'ui:select':
      return UiKitSelect(name: s('name'), options: optList('options'), label: s('label'));
    case 'ui:radiogroup':
      return UiKitRadioGroup(name: s('name'), options: optList('options'), label: s('label'));
    case 'ui:slider':
      return UiKitSlider(name: s('name'), min: d('min'), max: d('max'), label: s('label'));
    case 'ui:datefield':
      return UiKitDateField(name: s('name'), label: s('label'));
    case 'ui:row':
      return UiKitRow(children: kids());
    case 'ui:column':
      return UiKitColumn(children: kids());
    case 'ui:divider':
      return const UiKitDivider();
    case 'ui:header':
      return UiKitHeader(title: s('title'));
    case 'ui:gap':
      return UiKitGap(size: d('size') == 0 ? 16 : d('size'));
    default:
      return const SizedBox.shrink();
  }
}
