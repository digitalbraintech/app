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
    _runtime.update(const LibraryName(['digitalbrain']), createDigitalBrainWidgets());
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
    final type = (node['Type'] ?? node['type'] ?? 'Container').toString().toLowerCase();
    final props = (node['Props'] ?? node['props'] ?? const <String, Object?>{}) as Map<String, Object?>;
    final childrenList = (node['Children'] ?? node['children'] ?? const []) as List;

    if (type == 'rfw' || type == 'rfw') {
      final source = (node['RfwSource'] ?? props['source'])?.toString();
      final root = (node['RfwRoot'] ?? props['root'] ?? 'root').toString();
      final data = (props['data'] ?? const <String, Object?>{}) as Map<String, Object?>;
      if (source != null && source.isNotEmpty) {
        final key = 'dyn-${source.hashCode}';
        rfwHost.ensureLoaded(key, source);
        return rfwHost.render(key, data: data, onEvent: onEvent, rootWidget: root);
      }
      return const SizedBox.shrink();
    }

    if (type == 'app-shell' || type == 'appshell') {
      Widget sidebarWidget = const SizedBox.shrink();
      Widget body = const Center(child: Text('No content surface'));

      for (final child in childrenList) {
        final c = child as Map<String, Object?>;
        final cType = (c['Type'] ?? c['type'] ?? '').toString().toLowerCase();
        if (cType.contains('sidebar')) {
          sidebarWidget = build(c, onEvent, rfwHost: rfwHost, onNavSelected: onNavSelected, activeTarget: activeTarget);
        } else {
          body = build(c, onEvent, rfwHost: rfwHost, onNavSelected: onNavSelected, activeTarget: activeTarget);
        }
      }

      if (props.containsKey('navItems')) {
        sidebarWidget = _buildDynamicSidebar(props['navItems'] as List? ?? const [], onNavSelected, activeTarget);
      }

      return FScaffold(
        sidebar: sidebarWidget,
        header: FHeader(title: Text((props['title'] ?? 'DigitalBrain').toString())),
        child: body,
      );
    }

    if (type.contains('sidebar')) {
      final items = (props['navItems'] ?? const []) as List;
      return _buildDynamicSidebar(items, onNavSelected, activeTarget);
    }

    if (type.contains('fcard') || type == 'card' || type == 'panel') {
      final title = props['title']?.toString() ?? 'Neuron Surface';
      final sub = props['subtitle']?.toString() ?? props['summary']?.toString() ?? '';
      final childWidgets = childrenList.isNotEmpty
          ? Column(children: childrenList.cast<Map<String, Object?>>().map((c) => build(c, onEvent, rfwHost: rfwHost, onNavSelected: onNavSelected, activeTarget: activeTarget)).toList())
          : null;
      return FCard(
        title: Text(title),
        subtitle: sub.isEmpty ? null : Text(sub),
        child: childWidgets,
      );
    }

    if (type == 'fbutton' || type == 'button' || type == 'action') {
      final label = (props['label'] ?? props['text'] ?? props['title'] ?? 'Action').toString();
      return FButton(
        onPress: () {
          onEvent('press', {'label': label, ...props});
          final t = (props['targetSurfaceKind'] ?? props['target'] ?? props['path'])?.toString();
          if (t != null && t.isNotEmpty) onNavSelected?.call(t);
        },
        child: Text(label),
      );
    }

    if (type == 'text' || type == 'label') {
      return Text((props['text'] ?? props['value'] ?? props['label'] ?? '').toString());
    }

    if (type == 'list' || type == 'vlist' || type.contains('list')) {
      final raw = (props['items'] ?? childrenList) as List;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: raw.map((rawItem) {
          final m = rawItem is Map<String, Object?> ? rawItem : <String, Object?>{'label': rawItem.toString()};
          final lbl = (m['label'] ?? m['text'] ?? m['title'] ?? 'Item').toString();
          final sub = (m['subtitle'] ?? m['description'] ?? m['summary'] ?? '').toString();
          return GestureDetector(
            onTap: () {
              onEvent('select', m);
              final t = (m['targetSurfaceKind'] ?? m['target'] ?? m['path'])?.toString();
              if (t != null && t.isNotEmpty) onNavSelected?.call(t);
            },
            child: FCard(
              title: Text(lbl),
              subtitle: sub.isEmpty ? null : Text(sub),
            ),
          );
        }).toList(),
      );
    }

    if (type == 'row' || type == 'hstack' || type == 'hbox') {
      return Row(
        children: childrenList.cast<Map<String, Object?>>().map((c) =>
          build(c, onEvent, rfwHost: rfwHost, onNavSelected: onNavSelected, activeTarget: activeTarget)
        ).toList(),
      );
    }

    if (type == 'column' || type == 'vstack' || type == 'vbox') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: childrenList.cast<Map<String, Object?>>().map((c) =>
          build(c, onEvent, rfwHost: rfwHost, onNavSelected: onNavSelected, activeTarget: activeTarget)
        ).toList(),
      );
    }

    // Recursive default (layout container)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: childrenList.cast<Map<String, Object?>>().map((c) =>
        build(c, onEvent, rfwHost: rfwHost, onNavSelected: onNavSelected, activeTarget: activeTarget)
      ).toList(),
    );
  }

  Widget _buildDynamicSidebar(List rawItems, void Function(String)? onNav, String? active) {
    final items = rawItems.cast<Map>();
    return FSidebar(
      header: Padding(
        padding: const EdgeInsets.all(16),
        child: Text('DigitalBrain', style: FTheme.of(navigatorKey.currentContext!).typography.lg),
      ),
      children: items.map((item) {
        final label = item['label']?.toString() ?? 'Item';
        final target = item['targetSurfaceKind']?.toString() ?? item['path']?.toString() ?? label;
        return FSidebarItem(
          label: Text(label),
          selected: active == target,
          onPress: () => onNav?.call(target),
        );
      }).toList(),
    );
  }
}

// Simple navigator key for theme access in renderer when no context.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
