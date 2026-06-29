import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:rfw/rfw.dart' show RemoteEventHandler;
import 'ui_form_scope.dart';

class UiKitTile extends StatelessWidget {
  const UiKitTile({
    super.key,
    required this.title,
    this.subtitle = '',
    this.pack = '',
    this.experienceId = '',
    this.eventName = '',
    this.onEvent,
  });
  final String title;
  final String subtitle;
  final String pack;
  final String experienceId;
  final String eventName;
  final RemoteEventHandler? onEvent;

  FTile _tile(UiKitFormController? controller) => FTile(
        title: Text(title),
        subtitle: subtitle.isEmpty ? null : Text(subtitle),
        onPress: eventName.isEmpty || onEvent == null
            ? null
            : () => onEvent!('press', {
                  'synapseType': 'ExperienceStep',
                  'props': {
                    'pack': pack,
                    'experienceId': experienceId,
                    'eventName': eventName,
                    ...(controller?.values ?? const {}),
                  },
                }),
      );

  @override
  Widget build(BuildContext context) {
    // FTile requires a group context for layout constraints; wrap standalone tiles in FTileGroup.
    return FTileGroup(children: [_tile(UiKitFormScope.of(context))]);
  }
}
