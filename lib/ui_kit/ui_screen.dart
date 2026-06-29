import 'package:flutter/widgets.dart';

import 'ui_form_scope.dart';

class UiKitScreen extends StatefulWidget {
  const UiKitScreen({super.key, required this.children});
  final List<Widget> children;

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
  Widget build(BuildContext context) {
    return UiKitFormScope(
      controller: _controller,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final child in widget.children)
              Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: child),
          ],
        ),
      ),
    );
  }
}
