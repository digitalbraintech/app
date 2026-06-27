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

  // Live data from neurons
  Map<String, Object?>? _shellTree; // from app-shell or widget-tree surface
  final Map<String, gw.RfwCardEnvelope> _surfacesByKind = {}; // e.g. "marketplace-list" -> envelope
  String _selectedTarget = 'marketplace-list'; // default content surface kind

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
      if (kind == 'app-shell' || kind == 'widget-tree' || data['tree'] != null) {
        _shellTree = data;
        // Default active content from server-emitted shell tree (top or nested in tree/Props).
        final ac = data['activeContent']
            ?? (data['tree'] as Map?)?['activeContent']
            ?? ((data['tree'] as Map?)?['Props'] as Map?)?['activeContent'];
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
      // Sidebar + header from neuron tree (neuron:Menu / neuron:Header / forui children). No navItems fallback.
      Widget sidebarWidget = const SizedBox.shrink();
      Widget headerWidget = FHeader(title: Text((tree['title'] ?? (tree['Props'] as Map?)?['title'] ?? 'DigitalBrain').toString()));
      if (tree['Children'] is List && (tree['Children'] as List).isNotEmpty) {
        for (final c in (tree['Children'] as List)) {
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
          body = renderer.build(
            treeNode,
            _handleSurfaceEvent,
            rfwHost: _rfwHost,
            onNavSelected: (t) => setState(() => _selectedTarget = t),
            activeTarget: _selectedTarget,
          );
        } else {
          final source = data['source'] as String?;
          final root = (data['rootWidget'] as String? ?? data['root'] as String? ?? activeEnvelope.rootWidget).toString();
          if (source != null && source.isNotEmpty) {
            final key = activeEnvelope.correlationId.isEmpty ? 'shell-content-$_selectedTarget' : activeEnvelope.correlationId;
            _rfwHost.ensureLoaded(key, source);
            body = _rfwHost.render(
              key,
              data: data,
              onEvent: _handleSurfaceEvent,
              rootWidget: root,
            );
          } else {
            // Delegate to renderer machinery for live surface (no direct FCard or text dumps in shell).
            final node = <String, Object?>{
              'type': 'fcard',
              'props': {
                'title': data['title']?.toString() ?? _selectedTarget,
                'subtitle': (data['summary'] ?? data['body'] ?? 'Live surface from neuron').toString(),
              },
            };
            body = renderer.build(
              node,
              _handleSurfaceEvent,
              rfwHost: _rfwHost,
              onNavSelected: (t) => setState(() => _selectedTarget = t),
              activeTarget: _selectedTarget,
            );
          }
        }
      } else {
        // No text dump: use renderer for a minimal content-area surface while waiting for live neuron emission.
        body = renderer.build(
          <String, Object?>{'type': 'content-area', 'props': <String, Object?>{}},
          _handleSurfaceEvent,
          rfwHost: _rfwHost,
          onNavSelected: (t) => setState(() => _selectedTarget = t),
          activeTarget: _selectedTarget,
        );
      }

      return FScaffold(
        sidebar: sidebarWidget,
        header: headerWidget,
        child: body,
      );
    }

    // No legacy hardcoded nav (priority 4). Thin host only. If no live app-shell tree, show waiting via renderer.
    return FScaffold(
      sidebar: const SizedBox.shrink(),
      header: FHeader(title: const Text('DigitalBrain')),
      child: renderer.build(
        <String, Object?>{'type': 'content-area', 'props': <String, Object?>{'message': 'Waiting for live app-shell from neuron'}},
        _handleSurfaceEvent,
        rfwHost: _rfwHost,
        onNavSelected: (t) => setState(() => _selectedTarget = t),
        activeTarget: _selectedTarget,
      ),
    );
  }

}

