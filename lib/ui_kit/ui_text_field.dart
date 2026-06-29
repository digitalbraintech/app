import 'package:flutter/material.dart';

import 'ui_form_scope.dart';

// Renders a text field that writes its value into [UiKitFormScope] on every
// keystroke.  Uses a plain [TextField] (not ForUI) so we can attach a
// [TextEditingController] listener directly.
class UiKitTextField extends StatefulWidget {
  final String name;
  final String? hint;
  final String? label;

  const UiKitTextField({
    required this.name,
    this.hint,
    this.label,
    super.key,
  });

  @override
  State<UiKitTextField> createState() => _UiKitTextFieldState();
}

class _UiKitTextFieldState extends State<UiKitTextField> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    UiKitFormScope.of(context)?.set(widget.name, _controller.text);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    decoration: InputDecoration(
      labelText: widget.label,
      hintText: widget.hint,
    ),
  );
}
