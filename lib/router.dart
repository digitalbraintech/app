import 'package:go_router/go_router.dart';

import 'features/canvas/living_canvas_screen.dart';
import 'features/chat/ino_chat_screen.dart';
import 'features/gallery/forui_ui_kit_gallery.dart';
import 'features/spike/globe_lottie_spike.dart';
import 'shell/forui_app_shell.dart';

final digitalbrainRouter = GoRouter(
  initialLocation: '/',
  routes: [
    // Canvas remains the advanced immersive RFW surface host.
    GoRoute(
      path: '/',
      name: 'canvas',
      builder: (context, state) => const LivingCanvasScreen(),
    ),
    // Live neuron-driven shell owns chrome + body for surface-driven views (navItems + activeContent from app-shell tree).
    // Surface routes (marketplace, tasks, etc.) are now internal to ForuiAppShell body (no placeholders).
    // GoRouter kept minimal for canvas, chat, gallery, spikes and deep links.
    ShellRoute(
      builder: (context, state, child) => ForuiAppShell(child: child),
      routes: [
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
    GoRoute(
      path: '/spike',
      name: 'globe-lottie-spike',
      builder: (context, state) => const GlobeLottieSpike(),
    ),
  ],
);


