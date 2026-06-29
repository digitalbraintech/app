import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'ui_form_scope.dart';

class UiKitDateField extends StatelessWidget {
  const UiKitDateField({super.key, required this.name, this.label = ''});
  final String name;
  final String label;

  String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) => FDateField(
        label: label.isEmpty ? null : Text(label),
        onSubmit: (DateTime d) => UiKitFormScope.of(context)?.set(name, _iso(d)),
      );
}
