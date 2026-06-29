import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

class UiKitPanel extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget? child;

  const UiKitPanel({this.title, this.subtitle, this.child, super.key});

  @override
  Widget build(BuildContext context) => FCard(
    title: title != null ? Text(title!) : null,
    subtitle: subtitle != null ? Text(subtitle!) : null,
    child: child,
  );
}
