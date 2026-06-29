import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

class UiKitList extends StatelessWidget {
  const UiKitList({super.key, required this.children});
  final List<FTile> children;

  @override
  Widget build(BuildContext context) => FTileGroup(children: children);
}
