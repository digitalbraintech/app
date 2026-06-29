import 'package:flutter/widgets.dart';

import 'ui_form_scope.dart';

class UiKitScreen extends StatefulWidget {
  final Widget child;

  const UiKitScreen({required this.child, super.key});

  @override
  State<UiKitScreen> createState() => _UiKitScreenState();
}

class _UiKitScreenState extends State<UiKitScreen> {
  final UiKitFormController _controller = UiKitFormController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      UiKitFormScope(controller: _controller, child: widget.child);
}
