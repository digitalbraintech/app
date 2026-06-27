import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
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
      final channel = createKernelChannel(
        host: host,
        port: port,
        secure: secure,
      );
      final client = DigitalBrainGatewayClient(
        channel,
        interceptors: kernelInterceptors(),
      );

      _homeFeedSub?.cancel();
      final sub = client
          .watchHomeFeed(gw.WatchHomeFeedRequest())
          .listen(_onCard, onError: (_) {}, onDone: () {});

      setState(() {
        _channel = channel;
        _homeFeedSub = sub;
        _uiClient = UiGatewayClient(
          channel,
          interceptors: kernelInterceptors(),
        );
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
    _uiSessionSub = c
        .engageUiSession(input.stream)
        .listen((_) {}, onError: (_) {});
  }

  void _onCard(gw.RfwCardEnvelope envelope) {
    if (!mounted) return;
    final data = _decode(envelope.dataJson);
    final kind = (data['kind'] ?? data['surfaceKind'] ?? '').toString();

    // Runtime-only ForUI notification from neuron/synapse (no static Flutter view).
    // Neuron emits UiSurface(kind: "toast" | "notification") with title/description.
    if (kind == 'toast' || kind == 'notification' || kind.contains('toast')) {
      final titleText = (data['title'] ?? data['message'] ?? 'Hello World!')
          .toString();
      final descText = data['description']?.toString();
      Future.microtask(() {
        if (mounted) {
          showFToast(
            context: context,
            title: Text(titleText),
            description: descText != null ? Text(descText) : null,
            duration: const Duration(seconds: 4),
          );
        }
      });
    }

    setState(() {
      final treeNode = data['tree'] as Map?;
      final hasShellMarker =
          kind == 'app-shell' ||
          kind == 'widget-tree' ||
          kind.contains('shell') ||
          data['activeContent'] != null;
      final treeLooksLikeShell =
          treeNode != null &&
          (treeNode['activeContent'] != null ||
              (treeNode['Props'] as Map?)?['activeContent'] != null ||
              (treeNode['Type']?.toString().toLowerCase().contains(
                    'scaffold',
                  ) ??
                  false) ||
              (treeNode['Type']?.toString().toLowerCase() == 'app-shell'));
      if (hasShellMarker || treeLooksLikeShell) {
        _shellTree = data;
        final ac =
            data['activeContent'] ??
            (treeNode)?['activeContent'] ??
            ((treeNode)?['Props'] as Map?)?['activeContent'];
        if (ac is String && ac.isNotEmpty) {
          _selectedTarget = ac;
        }
      } else if (kind.isNotEmpty) {
        _surfacesByKind[kind] = envelope;
      }
    });
  }

  void _handleSurfaceEvent(String name, Map<String, Object?> args) {
    final target = (args['targetSurfaceKind'] ?? args['target'] ?? args['path'])
        ?.toString();
    if (target != null && target.isNotEmpty) {
      _goTo(target);
    }
    if (name == 'press' || name == 'select' || name == 'action') {
      final action = (args['action'] is Map
          ? (args['action'] as Map).cast<String, Object?>()
          : args);
      final elementId =
          ((action['actionId'] as String?) ??
                  (action['synapseType'] as String?) ??
                  target ??
                  _selectedTarget ??
                  name.toString())
              .toString();
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

  Widget? _renderEnvelope(
    gw.RfwCardEnvelope? env,
    UiSurfaceTreeRenderer renderer,
    String emptyKey,
  ) {
    if (env == null) return null;

    final data = _decode(env.dataJson);
    final treeNode = data['tree'] as Map<String, Object?>?;
    if (treeNode != null) {
      return SizedBox.expand(
        child: renderer.build(
          treeNode,
          _handleSurfaceEvent,
          rfwHost: _rfwHost,
          onNavSelected: _goTo,
          activeTarget: _selectedTarget,
        ),
      );
    }

    final source = data['source'] as String?;
    final root =
        (data['rootWidget'] as String? ??
                data['root'] as String? ??
                env.rootWidget)
            .toString();
    if (source != null && source.isNotEmpty) {
      final key = env.correlationId.isEmpty ? emptyKey : env.correlationId;
      _rfwHost.ensureLoaded(key, source);
      return SizedBox.expand(
        child: _rfwHost.render(
          key,
          data: data,
          onEvent: _handleSurfaceEvent,
          rootWidget: root,
        ),
      );
    }

    return null;
  }

  void _goTo(String target) {
    final t = target.trim().toLowerCase();
    if (t.isEmpty) return;
    if (t.contains('market') || t == 'marketplace' || t == '/marketplace') {
      setState(() => _selectedTarget = 'marketplace');
      // Also update location for deep links / history, but body driven by target
      if (GoRouterState.of(context).uri.path != '/marketplace') {
        context.go('/marketplace');
      }
      return;
    }
    if (t.contains('gallery') || t == '/gallery') {
      context.go('/gallery');
      return;
    }
    if (t.contains('chat') || t.contains('ino') || t == '/chat') {
      context.go('/chat');
      return;
    }
    if (t.startsWith('/')) {
      context.go(t);
      return;
    }
    setState(() => _selectedTarget = target);
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
          final cType = (childMap['Type'] ?? childMap['type'] ?? '')
              .toString()
              .toLowerCase();
          if (cType.contains('sidebar') || cType.contains('menu')) {
            sidebarWidget = renderer.build(
              Map<String, Object?>.from(childMap),
              _handleSurfaceEvent,
              rfwHost: _rfwHost,
              onNavSelected: _goTo,
              activeTarget: _selectedTarget,
            );
          } else if (cType.contains('header')) {
            headerWidget = renderer.build(
              Map<String, Object?>.from(childMap),
              _handleSurfaceEvent,
              rfwHost: _rfwHost,
              onNavSelected: _goTo,
              activeTarget: _selectedTarget,
            );
          }
        }
      }

      Widget body;
      if (activeEnvelope != null) {
        body =
            _renderEnvelope(
              activeEnvelope,
              renderer,
              'shell-content-$_selectedTarget',
            ) ??
            const SizedBox.shrink();
      } else {
        body = const SizedBox.shrink();
      }

      final loc = GoRouterState.of(context).uri.path;

      // All UI is 100% from neuron trees / kit. No more .dart screens.
      final effectiveTarget = (_selectedTarget ?? '').toLowerCase();
      if (effectiveTarget.contains('market') || loc == '/marketplace') {
        final env =
            _surfacesByKind['marketplace'] ??
            _surfacesByKind[_selectedTarget ?? ''];
        body =
            _renderEnvelope(env, renderer, 'marketplace-surface') ??
            const Center(child: Text('Marketplace (neuron kit tree)'));
      }

      return FScaffold(
        sidebar: sidebarWidget,
        header: headerWidget,
        child: body,
      );
    }

    final loc = GoRouterState.of(context).uri.path;

    // Pure minimal fallback. Real UI (nav, content, all screens) comes exclusively from neuron-emitted UiWidgetTree / kit.
    Widget fallbackBody =
        _renderEnvelope(_surfacesByKind['login'], renderer, 'login-surface') ??
        _renderEnvelope(
          _surfacesByKind['installed-bundles'],
          renderer,
          'installed-fallback',
        ) ??
        _renderEnvelope(
          _surfacesByKind['marketplace-list'] ?? _surfacesByKind['marketplace'],
          renderer,
          'marketplace-fallback',
        ) ??
        const Center(
          child: Text('Waiting for full neuron tree (UI kit from synapses)'),
        );

    // Marketplace migration to backend UI also applies in pure fallback.
    // If a marketplace surface arrived (possible even before full shell tree), render it.
    // Marketplace is now fully from neuron-emitted UiWidgetTree using rich forui kit (no static screen).
    final effectiveTarget = (_selectedTarget ?? '').toLowerCase();
    if (effectiveTarget.contains('market') || loc == '/marketplace') {
      final env =
          _surfacesByKind['marketplace'] ??
          _surfacesByKind[_selectedTarget ?? ''];
      fallbackBody =
          _renderEnvelope(env, renderer, 'marketplace-fallback') ??
          const Center(
            child: Text(
              'Marketplace (neuron kit tree - use dev authoring via dispatch or MCP)',
            ),
          );
    }
    if (effectiveTarget.contains('install') ||
        effectiveTarget.contains('bundle') ||
        loc == '/installed') {
      gw.RfwCardEnvelope? env =
          _surfacesByKind['installed-bundles'] ??
          _surfacesByKind[_selectedTarget ?? ''];
      if (env == null) {
        for (final e in _surfacesByKind.values) {
          final dk = _decode(e.dataJson)['kind']?.toString() ?? '';
          if (dk.contains('install') || dk.contains('bundle')) {
            env = e;
            break;
          }
        }
      }
      fallbackBody =
          _renderEnvelope(env, renderer, 'installed-fallback') ?? fallbackBody;
    }

    return FScaffold(
      header: const FHeader(title: Text('DigitalBrain')),
      sidebar:
          const SizedBox.shrink(), // sidebar + nav fully from emitted shell tree (neuron kit)
      child: fallbackBody,
    );
  }
}
