import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'ui_form_scope.dart';

class UiKitRadioGroup extends StatelessWidget {
  const UiKitRadioGroup({super.key, required this.name, required this.options, this.label = ''});
  final String name;
  final List<String> options;
  final String label;

  @override
  Widget build(BuildContext context) => FSelectGroup<String>(
        control: const FMultiValueControl.managedRadio(),
        label: label.isEmpty ? null : Text(label),
        onSaved: (selected) {
          final v = selected?.firstOrNull;
          if (v != null) UiKitFormScope.of(context)?.set(name, v);
        },
        children: [
          for (final o in options)
            FSelectGroupItemMixin.radio(value: o, label: Text(o)),
        ],
      );
}
