import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:digitalbrain_flutter/grpc/digitalbrain.pbgrpc.dart';
import 'package:digitalbrain_flutter/grpc/endpoint.dart';
import 'package:digitalbrain_flutter/grpc/grpc_channel.dart';
import 'package:digitalbrain_flutter/rfw_host/rfw_runtime_host.dart';
import 'package:digitalbrain_flutter/grpc/digitalbrain.pb.dart' as gw;
import 'package:digitalbrain_flutter/grpc/uigateway.pbgrpc.dart';
import 'package:digitalbrain_flutter/grpc/uigateway.pb.dart' as ui;

/// Dynamic NeuroUI shell. Subscribes to WatchHomeFeed and renders chrome + nav + body
/// entirely from live UiSurface / widget-tree / rfw surfaces emitted by neurons.
/// This is the thin host: no static nav list in the final state.
class ForuiAppShell extends StatefulWidget {
  final Widget? child; // legacy, ignored in dynamic mode

  const ForuiAppShell({super.key, this.child});

  @override
  State<ForuiAppShell> createState() => _ForuiAppShellState();
}

class _ForuiAppShellState extends State<ForuiAppShell> {
  final RfwRuntimeHost _rfwHost = RfwRuntimeHost();
  dynamic _channel;
  UiGatewayClient? _uiClient;
  StreamController<ui.UiInputSynapse>? _uiInput;
  StreamSubscription<ui.UiStateSignal>? _uiSessionSub;
  StreamSubscription<gw.RfwCardEnvelope>? _homeFeedSub;

  // Live data from neurons (minimal state for composition; all chrome/content from neuron trees)
  Map<String, Object?>? _shellTree;
  final Map<String, gw.RfwCardEnvelope> _surfacesByKind = {};
  String? _selectedTarget; // from tree only; no hardcoded default

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void dispose() {
    _homeFeedSub?.cancel();
    _uiSessionSub?.cancel();
    _uiInput?.close();
    _channel?.shutdown();
    super.dispose();
  }

  void _connect() {
    try {
      final (host, port, secure) = resolveKernelEndpoint();
      final channel = createKernelChannel(host: host, port: port, secure: secure);
      final client = DigitalBrainGatewayClient(channel, interceptors: kernelInterceptors());

      _homeFeedSub?.cancel();
      final sub = client
          .watchHomeFeed(gw.WatchHomeFeedRequest())
          .listen(_onCard, onError: (_) {}, onDone: () {});

      setState(() {
        _channel = channel;
        _homeFeedSub = sub;
        _uiClient = UiGatewayClient(channel, interceptors: kernelInterceptors());
      });
      _openUiSession();
    } catch (_) {
      // fall back to static if no kernel (dev)
    }
  }

  void _openUiSession() {
    final c = _uiClient;
    if (c == null) return;
    final input = StreamController<ui.UiInputSynapse>();
    _uiInput = input;
    _uiSessionSub = c.engageUiSession(input.stream).listen((_) {}, onError: (_) {});
  }

  void _onCard(gw.RfwCardEnvelope envelope) {
    if (!mounted) return;
    final data = _decode(envelope.dataJson);
    final kind = (data['kind'] ?? data['surfaceKind'] ?? '').toString();

    setState(() {
      final treeNode = data['tree'] as Map?;
      final hasShellMarker = kind == 'app-shell' || kind == 'widget-tree' || kind.contains('shell') || data['activeContent'] != null;
      final treeLooksLikeShell = treeNode != null && (
        treeNode['activeContent'] != null ||
        (treeNode['Props'] as Map?)?['activeContent'] != null ||
        (treeNode['Type']?.toString().toLowerCase().contains('scaffold') ?? false) ||
        (treeNode['Type']?.toString().toLowerCase() == 'app-shell')
      );
      if (hasShellMarker || treeLooksLikeShell) {
        _shellTree = data;
        final ac = data['activeContent']
            ?? (treeNode)?['activeContent']
            ?? ((treeNode)?['Props'] as Map?)?['activeContent'];
        if (ac is String && ac.isNotEmpty) {
          _selectedTarget = ac;
        }
      } else if (kind.isNotEmpty) {
        _surfacesByKind[kind] = envelope;
      }
    });
  }

  void _handleSurfaceEvent(String name, Map<String, Object?> args) {
    // Nav from buttons/links inside dynamic surfaces
    final target = (args['targetSurfaceKind'] ?? args['target'] ?? args['path'])?.toString();
    if (target != null && target.isNotEmpty) {
      setState(() => _selectedTarget = target);
    }
    if (name == 'press' || name == 'select' || name == 'action') {
      final action = (args['action'] is Map ? (args['action'] as Map).cast<String, Object?>() : args);
      final elementId = ((action['actionId'] as String?) ?? (action['synapseType'] as String?) ?? target ?? _selectedTarget ?? name.toString()).toString();
      final payload = jsonEncode(action);
      _uiInput?.add(
        ui.UiInputSynapse()
          ..brainId = 'default'
          ..elementId = elementId
          ..interaction = ui.UiInputSynapse_InteractionType.CLICK
          ..inputPayload = payload,
      );
    }
  }

  Map<String, Object?> _decode(String json) {
    try {
      final d = jsonDecode(json);
      if (d is Map) return d.map((k, v) => MapEntry(k.toString(), v));
    } catch (_) {}
    return const {};
  }

  @override
  Widget build(BuildContext context) {
    final tree = _shellTree;
    final activeEnvelope = _surfacesByKind[_selectedTarget];

    final renderer = const UiSurfaceTreeRenderer();

    if (tree != null) {
      // All chrome (sidebar, header) strictly from neuron tree children. No fallbacks or defaults.
      // Unwrap if the data is {tree: {Type: scaffold, Children: ...}} from widget-tree rfw.
      var root = tree;
      if (tree['tree'] is Map<String, Object?>) {
        root = (tree['tree'] as Map<String, Object?>).cast<String, Object?>();
      }
      Widget sidebarWidget = const SizedBox.shrink();
      Widget headerWidget = FHeader(title: const SizedBox.shrink());
      final children = root['Children'] ?? (root['Props'] as Map?)?['Children'];
      if (children is List && children.isNotEmpty) {
        for (final c in children) {
          final childMap = c as Map;
          final cType = (childMap['Type'] ?? childMap['type'] ?? '').toString().toLowerCase();
          if (cType.contains('sidebar') || cType.contains('menu')) {
            sidebarWidget = renderer.build(
              Map<String, Object?>.from(childMap),
              _handleSurfaceEvent,
              rfwHost: _rfwHost,
              onNavSelected: (t) => setState(() => _selectedTarget = t),
              activeTarget: _selectedTarget,
            );
          } else if (cType.contains('header')) {
            headerWidget = renderer.build(
              Map<String, Object?>.from(childMap),
              _handleSurfaceEvent,
              rfwHost: _rfwHost,
              onNavSelected: (t) => setState(() => _selectedTarget = t),
              activeTarget: _selectedTarget,
            );
          }
        }
      }

      Widget body;
      if (activeEnvelope != null) {
        final data = _decode(activeEnvelope.dataJson);
        final treeNode = data['tree'] as Map<String, Object?>?;
        if (treeNode != null) {
          final rendered = renderer.build(
            treeNode,
            _handleSurfaceEvent,
            rfwHost: _rfwHost,
            onNavSelected: (t) => setState(() => _selectedTarget = t),
            activeTarget: _selectedTarget,
          );
          body = SizedBox.expand(child: rendered);
        } else {
          final source = data['source'] as String?;
          final root = (data['rootWidget'] as String? ?? data['root'] as String? ?? activeEnvelope.rootWidget).toString();
          if (source != null && source.isNotEmpty) {
            final key = activeEnvelope.correlationId.isEmpty ? 'shell-content-$_selectedTarget' : activeEnvelope.correlationId;
            _rfwHost.ensureLoaded(key, source);
            final rendered = _rfwHost.render(
              key,
              data: data,
              onEvent: _handleSurfaceEvent,
              rootWidget: root,
            );
            body = SizedBox.expand(child: rendered);
          } else {
            // No client-synthesized nodes. Pure host container when no server content.
            body = const SizedBox.shrink();
          }
        }
      } else {
        // No client synthesis. When no active surface data, empty body (server should provide via tree).
        body = const SizedBox.shrink();
      }

      return FScaffold(
        sidebar: sidebarWidget,
        header: headerWidget,
        child: body,
      );
    }

    // Pure thin host fallback (until shell neuron surface arrives via WatchHomeFeed / UiGateway).
    // Uses ForUI scaffold + buddy search so UI is never black/empty.
    return FScaffold(
      header: const FHeader(title: Text('DigitalBrain')),
      sidebar: FSidebar(
        header: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text('Workspace', style: TextStyle(fontSize: 16, color: Color(0xFFE0E0E0))),
        ),
        children: const [
          FSidebarItem(label: Text('Marketplace')),
          FSidebarItem(label: Text('Tasks')),
          FSidebarItem(label: Text('INO Chat')),
          FSidebarItem(label: Text('Timeline')),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('DigitalBrain Shell - Fallback UI (waiting for neuron tree)', style: TextStyle(fontSize: 18, color: Colors.white)),
            const SizedBox(height: 16),
            FTextField(
              label: const Text('Search buddies / packs'),
              hint: 'Type to search',
            ),
            const SizedBox(height: 8),
            ...['DigitalBrain.UIKit.ForUI', 'kernel', 'INO', 'Marketplace', 'Tasks'].map((s) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: FTappable(
                onPress: () {},
                child: FCard(title: Text(s)),
              ),
            )),
          ],
        ),
      ),
    );
  }
}

