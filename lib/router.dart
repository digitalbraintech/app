import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'features/canvas/living_canvas_screen.dart';
import 'features/chat/ino_chat_screen.dart';
import 'features/gallery/forui_ui_kit_gallery.dart';
import 'features/spike/globe_lottie_spike.dart';
import 'shell/forui_app_shell.dart';

final digitalbrainRouter = GoRouter(
  initialLocation: '/',
  routes: [
    // Main experience is the live neuron-driven shell (chrome + body from app-shell/widget-tree via UiSurfaceTreeRenderer + kit nodes).
    // All UI must come from neurons/synapses; client is thin host only.
    ShellRoute(
      builder: (context, state, child) => ForuiAppShell(child: child),
      routes: [
        GoRoute(
          path: '/',
          name: 'shell',
          builder: (context, state) => const SizedBox.shrink(), // body driven by shell tree activeContent
        ),
        GoRoute(
          path: '/chat',
          name: 'chat',
          builder: (context, state) => const InoChatScreen(),
        ),
        GoRoute(
          path: '/gallery',
          name: 'gallery',
          builder: (context, state) => const ForuiUiKitGallery(),
        ),
      ],
    ),
    // Canvas is advanced immersive (still uses some RFW surfaces but will be further thinned in future steps).
    GoRoute(
      path: '/canvas',
      name: 'canvas',
      builder: (context, state) => const LivingCanvasScreen(),
    ),
    GoRoute(
      path: '/spike',
      name: 'globe-lottie-spike',
      builder: (context, state) => const GlobeLottieSpike(),
    ),
  ],
);


