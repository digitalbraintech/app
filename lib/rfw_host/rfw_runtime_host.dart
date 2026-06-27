import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:rfw/formats.dart' show parseLibraryFile;
import 'package:rfw/rfw.dart';

import 'package:digitalbrain_flutter/rfw_host/digitalbrain_rfw_library.dart';

/// One process-wide RFW runtime: the host-owned `digitalbrain` dictionary plus
/// per-key parsed document libraries. Parse failures are captured per key so a
/// bad document degrades to an error string instead of taking down the host.
class RfwRuntimeHost {
  RfwRuntimeHost() {
    _runtime.update(
      const LibraryName(['digitalbrain']),
      createDigitalBrainWidgets(),
    );
  }

  final Runtime _runtime = Runtime();
  final Set<String> _loaded = <String>{};
  final Map<String, String> _parseErrors = <String, String>{};

  /// Parse `source` once under library name `['doc', key]`. Idempotent.
  void ensureLoaded(String key, String source) {
    if (_loaded.contains(key) || _parseErrors.containsKey(key)) return;
    // Normalize CRLF / CR to LF before parsing. The RFW parser rejects U+000D
    // (carriage return) — networked sources sometimes carry CRLF line endings
    // that the parser would reject at column 16 of line 1.
    final normalized = source.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    try {
      _runtime.update(LibraryName(['doc', key]), parseLibraryFile(normalized));
      _loaded.add(key);
    } catch (e) {
      _parseErrors[key] = e.toString();
    }
  }

  String? parseError(String key) => _parseErrors[key];

  /// Check if a document key has already been successfully loaded.
  bool isLoaded(String key) => _loaded.contains(key);

  Widget render(
    String key, {
    required Map<String, Object?> data,
    required RemoteEventHandler onEvent,
    String rootWidget = 'root',
    String? semanticsId,
    String? semanticsLabel,
  }) {
    final remote = RemoteWidget(
      runtime: _runtime,
      data: DynamicContent(data),
      widget: FullyQualifiedWidgetName(LibraryName(['doc', key]), rootWidget),
      onEvent: onEvent,
    );
    return Semantics(
      identifier: semanticsId ?? key,
      label: semanticsLabel,
      container: true,
      child: remote,
    );
  }
}

/// Support for UiSurface-driven widget trees. This is the mechanism that makes the entire UI (main shell chrome,
/// navigation, layouts, widgets) come from neurons via streamed UiSurfaces.
/// Neurons (or packs) emit trees; the host only renders.
class UiSurfaceTreeRenderer {
  const UiSurfaceTreeRenderer();

  /// Renders a node from a neuron-provided tree (from UiSurface props['tree'] or the surface itself).
  /// onNavSelected receives the target kind when a nav item or link is activated.
  /// onEvent receives ('press'|'select'|'action', args) for buttons, list items, and declared actions so
  /// callers can dispatch real synapses (see DigitalBrainClientScope + UiGateway).
  Widget build(
    Map<String, Object?> node,
    RemoteEventHandler onEvent, {
    required RfwRuntimeHost rfwHost,
    void Function(String targetKind)? onNavSelected,
    String? activeTarget,
  }) {
    final type = (node['Type'] ?? node['type'] ?? 'Container')
        .toString()
        .toLowerCase();
    final props =
        (node['Props'] ?? node['props'] ?? const <String, Object?>{})
            as Map<String, Object?>;
    final childrenList =
        (node['Children'] ?? node['children'] ?? const []) as List;

    // Neuron UI Kit (server-driven only; client is thin renderer). Match exact kit types (from NeuronUiKit in Core).
    const kitMenu = 'neuron:menu';
    const kitMenuItem = 'neuron:menuitem';
    const kitActionBtn = 'neuron:actionbutton';
    const kitNeuronBtn = 'neuron:neuronbutton';
    if (type == kitMenu || type == 'neuron:sidebar') {
      return _buildNeuronMenu(
        props,
        childrenList,
        onEvent,
        rfwHost,
        onNavSelected,
        activeTarget,
      );
    }
    if (type == kitMenuItem || type == 'neuron:menu-item') {
      return _buildNeuronMenuItem(props, onEvent, onNavSelected, activeTarget);
    }
    if (type == kitActionBtn ||
        type == kitNeuronBtn ||
        type == 'neuron:button') {
      final label = (props['label'] ?? props['text'] ?? '').toString();
      return FButton(
        onPress: () {
          onEvent('press', {'label': label, ...props});
          final t = (props['targetSurfaceKind'] ?? props['target'])?.toString();
          if (t != null && t.isNotEmpty) onNavSelected?.call(t);
        },
        child: Text(label),
      );
    }

    if (type == 'neuron:header' || type == 'header') {
      final t = (props['title'] ?? props['text'] ?? props['label'] ?? '')
          .toString();
      return FHeader(title: Text(t));
    }

    if (type == 'neuron:divider' || type == 'divider') {
      return const FDivider();
    }

    // ForUI scaffold and autocomplete from NeuronUiKit (shell neuron trees, marketplace buddy search etc).
    if (type == 'forui:fscaffold' ||
        type == 'forui:scaffold' ||
        type == 'scaffold') {
      return _buildForuiScaffold(
        props,
        childrenList,
        onEvent,
        rfwHost,
        onNavSelected,
        activeTarget,
      );
    }
    if (type == 'forui:fautocomplete' ||
        type == 'forui:autocomplete' ||
        type.contains('autocomplete')) {
      return _buildForuiAutocomplete(props, onEvent);
    }

    if (type == 'forui:ftextfield' ||
        type == 'forui:textfield' ||
        type.contains('textfield')) {
      final label = (props['label'] ?? props['hint'] ?? '').toString();
      final hint = (props['hint'] ?? props['placeholder'] ?? label).toString();
      return FTextField(label: Text(label), hint: hint);
    }

    if (type == 'neuron:form' || type == 'form' || type == 'forui:fform') {
      return _NeuronForm(props: props, onEvent: onEvent);
    }

    if (type == 'forui:fselect' ||
        type == 'forui:select' ||
        type.contains('select')) {
      final itemsRaw = props['items'] ?? const <Object>[];
      final items = itemsRaw is List
          ? itemsRaw.map((e) => e.toString()).toList()
          : <String>[];
      final label = (props['label'] ?? 'Select').toString();
      return FSelect(label: Text(label), items: {for (final i in items) i: i});
    }

    if (type == 'forui:fbutton' || type == 'forui:button' || type == 'button') {
      final label = (props['label'] ?? props['text'] ?? '').toString();
      final variantStr = (props['variant'] ?? 'primary')
          .toString()
          .toLowerCase();
      var variant = FButtonVariant.primary;
      if (variantStr.contains('outline')) {
        variant = FButtonVariant.outline;
      }
      if (variantStr.contains('destructive')) {
        variant = FButtonVariant.destructive;
      }
      return FButton(
        variant: variant,
        onPress: () {
          onEvent('press', {'label': label, ...props});
          final t = (props['targetSurfaceKind'] ?? props['target'])?.toString();
          if (t != null && t.isNotEmpty) onNavSelected?.call(t);
        },
        child: Text(label),
      );
    }

    if (type == 'rfw') {
      final source = (node['RfwSource'] ?? props['source'])?.toString();
      final root = (node['RfwRoot'] ?? props['root'] ?? 'root').toString();
      final data =
          (props['data'] ?? const <String, Object?>{}) as Map<String, Object?>;
      if (source != null && source.isNotEmpty) {
        final key = 'dyn-${source.hashCode}';
        rfwHost.ensureLoaded(key, source);
        return rfwHost.render(
          key,
          data: data,
          onEvent: onEvent,
          rootWidget: root,
        );
      }
      return const SizedBox.shrink();
    }

    if (type == 'app-shell' || type == 'appshell') {
      Widget sidebarWidget = const SizedBox.shrink();
      Widget headerWidget = FHeader(
        title: Text((props['title'] ?? '').toString()),
      );
      Widget body = Center(child: const SizedBox.shrink());

      for (final child in childrenList) {
        final c = child as Map<String, Object?>;
        final cType = (c['Type'] ?? c['type'] ?? '').toString().toLowerCase();
        if (cType.contains('sidebar') || cType.contains('menu')) {
          sidebarWidget = build(
            c,
            onEvent,
            rfwHost: rfwHost,
            onNavSelected: onNavSelected,
            activeTarget: activeTarget,
          );
        } else if (cType.contains('header')) {
          headerWidget = build(
            c,
            onEvent,
            rfwHost: rfwHost,
            onNavSelected: onNavSelected,
            activeTarget: activeTarget,
          );
        } else {
          body = build(
            c,
            onEvent,
            rfwHost: rfwHost,
            onNavSelected: onNavSelected,
            activeTarget: activeTarget,
          );
        }
      }

      if (sidebarWidget is SizedBox && props.containsKey('navItems')) {
        sidebarWidget = _buildDynamicSidebar(
          props['navItems'] as List? ?? const [],
          onNavSelected,
          activeTarget,
        );
      }

      return FScaffold(
        sidebar: sidebarWidget,
        header: headerWidget,
        child: body,
      );
    }

    if (type.contains('sidebar')) {
      // Prefer children (Neuron UI Kit MenuItems or forui items) for full server-driven shell.
      if (childrenList.isNotEmpty) {
        return _buildSidebarFromChildren(
          childrenList,
          onEvent,
          onNavSelected,
          activeTarget,
          props,
        );
      }
      final items = (props['navItems'] ?? const []) as List;
      return _buildDynamicSidebar(items, onNavSelected, activeTarget);
    }

    if (type.contains('fcard') || type == 'card' || type == 'panel') {
      final title = props['title']?.toString() ?? '';
      final sub =
          props['subtitle']?.toString() ?? props['summary']?.toString() ?? '';
      final childWidgets = childrenList.isNotEmpty
          ? Column(
              children: childrenList
                  .cast<Map<String, Object?>>()
                  .map(
                    (c) => build(
                      c,
                      onEvent,
                      rfwHost: rfwHost,
                      onNavSelected: onNavSelected,
                      activeTarget: activeTarget,
                    ),
                  )
                  .toList(),
            )
          : null;
      return FCard(
        title: Text(title),
        subtitle: sub.isEmpty ? null : Text(sub),
        child: childWidgets,
      );
    }

    if (type == 'fbutton' || type == 'button' || type == 'action') {
      final label = (props['label'] ?? props['text'] ?? props['title'] ?? '')
          .toString();
      return FButton(
        onPress: () {
          onEvent('press', {'label': label, ...props});
          final t =
              (props['targetSurfaceKind'] ?? props['target'] ?? props['path'])
                  ?.toString();
          if (t != null && t.isNotEmpty) onNavSelected?.call(t);
        },
        child: Text(label),
      );
    }

    if (type == 'text' || type == 'label') {
      return Text(
        (props['text'] ?? props['value'] ?? props['label'] ?? '').toString(),
      );
    }

    if (type == 'list' || type == 'vlist' || type.contains('list')) {
      final raw = (props['items'] ?? childrenList) as List;
      final cards = raw.map((rawItem) {
        final m = rawItem is Map<String, Object?>
            ? rawItem
            : <String, Object?>{'label': rawItem.toString()};
        final lbl = (m['label'] ?? m['text'] ?? m['title'] ?? '').toString();
        final sub = (m['subtitle'] ?? m['description'] ?? m['summary'] ?? '')
            .toString();
        return FTappable(
          onPress: () {
            onEvent('select', m);
            final t = (m['targetSurfaceKind'] ?? m['target'] ?? m['path'])
                ?.toString();
            if (t != null && t.isNotEmpty) onNavSelected?.call(t);
          },
          child: FCard(
            title: Text(lbl),
            subtitle: sub.isEmpty ? null : Text(sub),
          ),
        );
      }).toList();
      return cards.isEmpty
          ? const SizedBox.shrink()
          : ListView(children: cards);
    }

    if (type == 'row' || type == 'hstack' || type == 'hbox') {
      return Row(
        children: childrenList
            .cast<Map<String, Object?>>()
            .map(
              (c) => build(
                c,
                onEvent,
                rfwHost: rfwHost,
                onNavSelected: onNavSelected,
                activeTarget: activeTarget,
              ),
            )
            .toList(),
      );
    }

    if (type == 'column' || type == 'vstack' || type == 'vbox') {
      final kids = childrenList
          .cast<Map<String, Object?>>()
          .map(
            (c) => build(
              c,
              onEvent,
              rfwHost: rfwHost,
              onNavSelected: onNavSelected,
              activeTarget: activeTarget,
            ),
          )
          .toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: List.generate(kids.length, (i) {
          final w = kids[i];
          if (i == kids.length - 1) {
            return Expanded(child: w);
          }
          return w;
        }),
      );
    }

    // Recursive default (layout container)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: childrenList
          .cast<Map<String, Object?>>()
          .map(
            (c) => build(
              c,
              onEvent,
              rfwHost: rfwHost,
              onNavSelected: onNavSelected,
              activeTarget: activeTarget,
            ),
          )
          .toList(),
    );
  }

  Widget _buildDynamicSidebar(
    List rawItems,
    void Function(String)? onNav,
    String? active,
  ) {
    final items = rawItems.cast<Map>();
    final title = (items.isNotEmpty
        ? (items.first['title']?.toString() ??
              items.first['headerTitle']?.toString() ??
              '')
        : '');
    return FSidebar(
      header: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
              child: Text(title, style: _sidebarTitleStyle()),
            ),
            const FDivider(),
          ],
        ),
      ),
      children: items.map((item) {
        final label = item['label']?.toString() ?? '';
        final target =
            item['targetSurfaceKind']?.toString() ??
            item['path']?.toString() ??
            label;
        return FSidebarItem(
          label: Text(label),
          selected: active == target,
          onPress: () => onNav?.call(target),
        );
      }).toList(),
    );
  }

  Widget _buildNeuronMenu(
    Map<String, Object?> props,
    List childrenList,
    RemoteEventHandler onEvent,
    RfwRuntimeHost rfwHost,
    void Function(String targetKind)? onNavSelected,
    String? activeTarget,
  ) {
    final title = (props['title'] ?? props['headerTitle'] ?? '').toString();
    final menuChildren = childrenList.isNotEmpty
        ? childrenList
              .cast<Map<String, Object?>>()
              .map(
                (c) => build(
                  c,
                  onEvent,
                  rfwHost: rfwHost,
                  onNavSelected: onNavSelected,
                  activeTarget: activeTarget,
                ),
              )
              .toList()
        : const <Widget>[];
    return FSidebar(
      header: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
              child: Text(title, style: _sidebarTitleStyle()),
            ),
            const FDivider(),
          ],
        ),
      ),
      children: menuChildren.cast<Widget>(),
    );
  }

  Widget _buildNeuronMenuItem(
    Map<String, Object?> props,
    RemoteEventHandler onEvent,
    void Function(String)? onNav,
    String? active,
  ) {
    final label = (props['label'] ?? props['text'] ?? '').toString();
    final target =
        (props['targetSurfaceKind'] ??
                props['target'] ??
                props['path'] ??
                label)
            .toString();
    final isSel = active == target;
    return FSidebarItem(
      label: Text(label),
      selected: isSel,
      onPress: () {
        onEvent('press', {
          'label': label,
          'targetSurfaceKind': target,
          ...props,
        });
        onNav?.call(target);
      },
    );
  }

  Widget _buildSidebarFromChildren(
    List childrenList,
    RemoteEventHandler onEvent,
    void Function(String)? onNav,
    String? active,
    Map<String, Object?> sidebarProps,
  ) {
    final items = childrenList
        .cast<Map<String, Object?>>()
        .map(
          (c) => _buildNeuronMenuItem(
            (c['Props'] ?? c['props'] ?? c) as Map<String, Object?>,
            onEvent,
            onNav,
            active,
          ),
        )
        .toList();
    final title =
        (sidebarProps['title']?.toString() ??
        sidebarProps['headerTitle']?.toString() ??
        (childrenList.isNotEmpty
            ? ((childrenList.first as Map)['title']?.toString() ??
                  (childrenList.first as Map)['headerTitle']?.toString() ??
                  '')
            : ''));
    return FSidebar(
      header: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
              child: Text(title, style: _sidebarTitleStyle()),
            ),
            const FDivider(),
          ],
        ),
      ),
      children: items,
    );
  }

  Widget _buildForuiScaffold(
    Map<String, Object?> props,
    List childrenList,
    RemoteEventHandler onEvent,
    RfwRuntimeHost rfwHost,
    void Function(String targetKind)? onNavSelected,
    String? activeTarget,
  ) {
    Widget header = const SizedBox.shrink();
    Widget sidebar = const SizedBox.shrink();
    Widget child = const SizedBox.shrink();
    Widget? footer;

    for (final c in childrenList) {
      final cm = c as Map<String, Object?>;
      final cType = (cm['Type'] ?? cm['type'] ?? '').toString().toLowerCase();
      if (cType.contains('header')) {
        header = build(
          cm,
          onEvent,
          rfwHost: rfwHost,
          onNavSelected: onNavSelected,
          activeTarget: activeTarget,
        );
      } else if (cType.contains('sidebar')) {
        sidebar = build(
          cm,
          onEvent,
          rfwHost: rfwHost,
          onNavSelected: onNavSelected,
          activeTarget: activeTarget,
        );
      } else if (cType.contains('footer') || cType.contains('bottomnav')) {
        footer = build(
          cm,
          onEvent,
          rfwHost: rfwHost,
          onNavSelected: onNavSelected,
          activeTarget: activeTarget,
        );
      } else {
        child = build(
          cm,
          onEvent,
          rfwHost: rfwHost,
          onNavSelected: onNavSelected,
          activeTarget: activeTarget,
        );
      }
    }

    return FScaffold(
      header: header is SizedBox
          ? FHeader(title: Text((props['title'] ?? '').toString()))
          : header,
      sidebar: sidebar is SizedBox ? null : sidebar,
      footer: footer,
      child: child,
    );
  }

  Widget _buildForuiAutocomplete(
    Map<String, Object?> props,
    RemoteEventHandler onEvent,
  ) {
    final itemsRaw = props['items'] ?? props['suggestions'] ?? const <Object>[];
    final suggestions = itemsRaw is List
        ? itemsRaw.map((e) => e.toString()).toList()
        : <String>[];
    final hint = (props['hint'] ?? props['placeholder'] ?? 'Search buddies')
        .toString();

    // ForUI based buddy/pack search (using FTextField + FTappable results from kit tree).
    // Typing not fully live (tree driven); selection fires synapse event.
    return _ForuiBuddySearch(
      hint: hint,
      suggestions: suggestions,
      onSelect: (value) => onEvent('select', {'value': value, ...props}),
    );
  }
}

// Simple navigator key for theme access in renderer when no context.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Local ForUI search widget for buddy/pack autocomplete in dynamic trees (marketplace etc).
/// Uses FTextField + results as FTappable FCard. Query select sends event for neuron/synapse handling.
class _ForuiBuddySearch extends StatefulWidget {
  const _ForuiBuddySearch({
    required this.hint,
    required this.suggestions,
    required this.onSelect,
  });

  final String hint;
  final List<String> suggestions;
  final void Function(String value) onSelect;

  @override
  State<_ForuiBuddySearch> createState() => _ForuiBuddySearchState();
}

class _ForuiBuddySearchState extends State<_ForuiBuddySearch> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FTextField(label: Text(widget.hint), hint: widget.hint),
        const SizedBox(height: 8),
        ...widget.suggestions
            .take(5)
            .map(
              (s) => FTappable(
                onPress: () => widget.onSelect(s),
                child: FCard(title: Text(s)),
              ),
            ),
      ],
    );
  }
}

TextStyle _sidebarTitleStyle() {
  final ctx = navigatorKey.currentContext;
  if (ctx != null) {
    return FTheme.of(ctx).typography.lg;
  }
  return const TextStyle(fontSize: 16, color: Color(0xFFE0E0E0));
}

class _NeuronForm extends StatefulWidget {
  const _NeuronForm({required this.props, required this.onEvent});

  final Map<String, Object?> props;
  final RemoteEventHandler onEvent;

  @override
  State<_NeuronForm> createState() => _NeuronFormState();
}

class _NeuronFormState extends State<_NeuronForm> {
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _syncControllers();
  }

  @override
  void didUpdateWidget(covariant _NeuronForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncControllers();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _syncControllers() {
    final names = _fields()
        .map((field) => (field['name'] ?? '').toString())
        .where((name) => name.isNotEmpty)
        .toSet();

    for (final name in names) {
      _controllers.putIfAbsent(name, () => TextEditingController());
    }

    final stale = _controllers.keys
        .where((key) => !names.contains(key))
        .toList();
    for (final key in stale) {
      _controllers.remove(key)?.dispose();
    }
  }

  List<Map<String, Object?>> _fields() {
    final raw = widget.props['fields'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map(
          (field) => field.map((key, value) => MapEntry(key.toString(), value)),
        )
        .toList();
  }

  void _submit() {
    final submitAction = widget.props['submitAction'];
    final action = submitAction is Map
        ? submitAction.map((key, value) => MapEntry(key.toString(), value))
        : <String, Object?>{};
    final actionProps = action['props'];
    final props = actionProps is Map
        ? actionProps.map((key, value) => MapEntry(key.toString(), value))
        : <String, Object?>{};

    final clientId = widget.props['clientId'];
    if (clientId != null) {
      props['clientId'] = clientId;
    }

    for (final entry in _controllers.entries) {
      props[entry.key] = entry.value.text;
    }

    final synapseType = (action['synapseType'] ?? widget.props['synapseType'])
        ?.toString();
    if (synapseType == null || synapseType.isEmpty) return;

    widget.onEvent('action', {
      'actionId': action['actionId'] ?? synapseType,
      'label': action['label'] ?? widget.props['submitLabel'] ?? 'Submit',
      'synapseType': synapseType,
      'props': props,
    });
  }

  @override
  Widget build(BuildContext context) {
    final fields = _fields();
    final title = widget.props['title']?.toString() ?? '';
    final error = widget.props['error']?.toString();
    final submitLabel = widget.props['submitLabel']?.toString() ?? 'Submit';

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: FCard(
          title: Text(title.isEmpty ? 'Form' : title),
          subtitle: error == null || error.isEmpty
              ? null
              : Text(error, style: const TextStyle(color: Colors.redAccent)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < fields.length; i++) ...[
                _field(fields[i], i == fields.length - 1),
                if (i != fields.length - 1) const SizedBox(height: 12),
              ],
              const SizedBox(height: 16),
              FButton(onPress: _submit, child: Text(submitLabel)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(Map<String, Object?> field, bool last) {
    final name = (field['name'] ?? '').toString();
    final label = (field['label'] ?? name).toString();
    final kind = (field['kind'] ?? 'text').toString().toLowerCase();
    final required = field['required'] == true;
    final controller = _controllers[name] ??= TextEditingController();

    return Material(
      type: MaterialType.transparency,
      child: TextField(
        controller: controller,
        obscureText: kind == 'password',
        textInputAction: last ? TextInputAction.done : TextInputAction.next,
        onSubmitted: (_) {
          if (last) _submit();
        },
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
