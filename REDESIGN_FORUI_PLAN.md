# DigitalBrain Flutter UI — Complete Redesign + ForUI Migration Plan

**Date:** 2026-06-27  
**Status:** Approved for implementation  
**Owner:** Grok + team  
**Goal:** Migrate *all* UI components from ad-hoc Flutter Material + custom glass/glow to https://forui.dev (v0.23+). Completely redesign for premium, consistent, usable NeuroOS experience. Full app must support `aspire run` delivering kernels + gateway + rich client.

## 1. Vision & Principles (UI/UX Designer Lens)

- **Everything is a Neuron or Synapse** reflected in visuals: nodes, firing pulses, living surfaces, context-aware assistant (INO).
- **ForUI as the single source of truth** for all chrome, controls, navigation, forms, cards, dialogs, sidebars. 40+ beautiful minimalistic widgets (shadcn/ui-inspired, platform-agnostic, desktop + touch).
- **Cinematic dark NeuroOS aesthetic** (from existing DigitalBrainColors): pure pitch black, obsidian surfaces, platinum/silver ink, subtle indigo/gold/teal accents, hairline borders. Generous breathing room, excellent alignment (8/12/16/24 rhythm), high scannability, calm motion.
- **Alive but calm**: Subtle synapse pulses, status breathing, auto-layout. No clutter.
- **Usability first**: Persistent sidebar (FSidebar), global command/search (⌘K), context awareness, keyboard everywhere, resizable panels, voice, action surfacing.
- **Server-driven + native hybrid**: RFW surfaces (dynamic from neurons/packs) stay powerful inside beautifully themed ForUI panels/chrome. Native views (Dashboard, Chat/INO, Tasks, Marketplace, Gallery) use ForUI directly.
- **10 primary views + ~20+ reusable widgets** (ForUI primitives + high-value composed DigitalBrain widgets).
- **Gallery as living spec**: /ui-kit-gallery is production-grade showcase + dev tool (also updates widgetbook).
- **aspire run complete experience**: Kernels (3x HA) + Ollama + gateway + flutter client (desktop/web) wired together. Chat, marketplace, canvas all live against real backend.

Delete more than we add. Self-explanatory names. No vacuous comments. Use latest ForUI.

## 2. Current State Audit

- `pubspec.yaml`: forui ^0.21.3 (update to ^0.23.0), heavy custom `digital_brain_ui/` (glass, glow, adaptive), RFW for surfaces, go_router, custom floating PanelManager + CanvasPanel (draggable/resizable), VisualConstructorCanvas (particles, nodes), ino_editor (RFW + prompts + voice), LivingCanvasScreen (hard-coded tabs + overlays).
- No first-class chat: ino_editor + chart-lab mini-chat + VoiceInput are fragments. Backend **INO** (InoNeuron) is the real personal assistant.
- Backend strong: InoRequest/InoResponse, rich journal context (tasks, MemorySummary, packs, editor), AskAsync, MCP `ask_ino`, FilterChanged, Task orchestration.
- Theme: custom buildDigitalBrainTheme (Material3 dark + Inter + JetBrainsMono + glass).
- Router minimal: / (canvas), /ui-kit-gallery, /spike.
- Aspire: AddFlutterClient (windows target), AppHost wires it when path exists.

Gaps: inconsistent components, no unified shell, chat is missing as polished view, gallery is stub.

## 3. ForUI Integration Strategy

- Update to latest `forui: ^0.23.0` (and forui_assets if needed).
- `MaterialApp.router` + `builder: (_, child) => FTheme(data: dbTheme, child: FToaster(child: FTooltipGroup(child: child!)))`.
- Use `FScaffold` (with `sidebar`, `header`, `child`) for shell views.
- `FThemeData` generated/customized with:
  - Colors: background #000000 / #070708, foreground #F5F5F7 platinum, primary silver, accents gold/amber, teal, rose for alerts.
  - Extend with `AppColors` (neuralPulse, synapseGold, taskActive, etc.).
  - Desktop variant preferred for main shell; touch for mobile.
- Chrome (top bar, side nav, panels, cards) → pure ForUI.
- Canvas viz area: keep custom painters inside a ForUI-framed container or full-bleed with overlay ForUI controls.
- Panels: keep custom drag/resize logic (or migrate to FResizable where fits), but **theme titlebars, borders, actions with ForUI tokens**.
- RFW: unchanged core renderer; surfaces live inside ForUI `FCard` / panel chrome. Update fallback templates for visual harmony.
- Icons: FLucideIcons + any custom via FIcons.
- Responsive: keep WindowSizeScope + InputModeScope; ForUI styles adapt.

## 4. 10 Views (Primary Navigation via FSidebar)

1. **Dashboard (Home)** — At-a-glance: cluster status, active tasks, recent activity, mini 3D viz, time/session clock, marketplace highlights. Grid of FCard.
2. **Brain Canvas** — Immersive full-bleed visual constructor + live graph + floating ForUI panels (RFW surfaces). Overlay ForUI command bar / view controls / auto-layout.
3. **Tasks** — List / Kanban of KernelTasks. Progress (ForUI progress + custom ring), actions. Right inspector.
4. **Marketplace** — Tabs (Local/Global/Installed/Categories). Grid of PackCards (FCard + install primary action + trust). Search + detail sheet.
5. **Timeline** — Virtualized synapse/event feed. Filters, search. Correlated with panels.
6. **Neurons** — Registry explorer. Searchable list of grains, IHandle capabilities, state. Click → inspector or fire test synapse.
7. **INO – Personal AI Assistant Chat** (priority) — Dedicated conversational UI to InoNeuron. Context bar ("Seeing: Canvas + 3 tasks"), message bubbles (ForUI styled), input + voice, suggestion chips, inline action chips that trigger real tasks/panels. History from InoResponse journal. Context-aware via FilterChanged.
8. **Memory / Context** — Semantic recall, recent MemorySummary, document search. Recall results as cards.
9. **UI Kit Gallery** — First-class. Sections for ForUI primitives, DB composed widgets (20+), RFW palette live render, layout examples, theme switcher. Interactive.
10. **Settings & System** — Endpoints, LLM config, replicas, appearance (theme variants), shortcuts, telemetry, licenses.

Nav: Collapsible FSidebar (groups: Workspace, Intelligence, System). Top global bar (logo, search/command, cluster status replicas, live time, avatar, notifications). Right contextual panel where useful. Bottom dock for minimized surfaces.

## 5. ~20–25 Widgets (ForUI + Composed)

**Direct ForUI (heavy use):**
- FButton (variants, sizes), FCard (raw + titled), FScaffold + FSidebar + FSidebarGroup/Item, FInput / FTextField, FAvatar, FBadge, FDivider, FResizable, showFSheet / FDialog patterns, FToaster, FTooltip, FTabs, FSelect, FBreadcrumb, FProgress, etc.

**DigitalBrain Composed (styled to FTheme + AppColors extension):**
1. NeuralGraph3D / BrainCanvas3D (framed)
2. SynapseTimeline / EventFeedList
3. TaskProgressCard (ring + bar + status)
4. PackCard (market tile)
5. NeuronChip / Node
6. ClusterStatusBar / ReplicasIndicator
7. CommandPaletteOverlay (⌘K)
8. MiniBrainViz
9. SurfacePanelChrome (ForUI titlebar + controls for RFW)
10. SessionClock / LiveTime
11. SynapsePulse / LiveDot
12. GlobalSearchBar
13. ContextRecallCard
14. ChartSurfaceHost (graphic + ForUI chrome)
15. INOActionChip (dynamic from response)
16. ChatMessageBubble (INO vs user)
17. ChatInputBar (voice + text + send)
18. INOContextBar (pills)
19. EmptyState / LoadingSkeleton
20. AutoLayoutButton + DockStrip
21. InspectorPanel (right)
22. StatusBadge family (with DB tones)
23. FilterChips / SuggestionRow
24. VoiceMicButton (polished VoiceInput)
25. (Stretch) ResizablePanelHost

All live in `lib/widgets/` or feature folders. Catalogued in Gallery.

## 6. INO Chat Experience Details (the highlighted missing piece)

- View 7 is the polished personal assistant.
- Send: `InoRequest` (via gateway send or dedicated method). Receive `InoResponse`.
- On open/message: emit `FilterChanged(currentView, ...)` + current canvas/panel state so INO context is live.
- UI: Bubbles using FCard + avatars (brain icon for INO). Responses can contain action proposals rendered as chips.
- When INO emits TASK: create real RunTask, auto surface panel or navigate to Tasks.
- History: pull recent InoResponse + MemorySummary.
- Voice: integrate existing recorder → transcript as user message → send.
- Context bar at top shows what INO sees (updated live).
- ino_editor preserved as "specialist" mode (chat offers "Edit code with INO" button that seeds editor or opens specialized pane).
- Since .ino behavior deprecated: assistant helps with typed C# packs, marketplace, neurons, tasks, recall, closed loops.

## 7. Layouts (Selected Examples — see prior responses for full tables)

**Global Shell**
```
TopBar (search | status 3/3 | time | avatar)
+ Sidebar (FSidebar) | Main (FScaffold child) | [Inspector]
```

**INO Chat** — detailed table in conversation history (bubbles + context bar + input + suggestions).

**Canvas** — full-bleed custom + positioned ForUI overlays (top controls, floating panels with ForUI chrome).

Similar grids for Dashboard (cards), Tasks (table/list + progress), Marketplace (responsive grid).

## 8. Migration & Implementation Phases

**Phase 0 (now)**: Write this plan (done). Update pubspec to ^0.23.0. Research complete (Context7 + pub).

**Phase 1**: Foundation
- Update theme/digitalbrain_theme.dart → produce `buildDigitalBrainForuiTheme()` returning FThemeData + extension.
- app.dart: wrap with FTheme + Toaster.
- New `lib/shell/app_shell.dart` (FScaffold + sidebar + router outlet + top bar).
- Router updates: named routes for all 10 views. Initial /dashboard or keep / for canvas with mode.
- Update existing LivingCanvasScreen to be hosted inside shell or as immersive mode.

**Phase 2**: INO Chat (high value vertical)
- New `features/chat/ino_chat_screen.dart` + supporting widgets (ChatMessageBubble, etc.).
- Wire gRPC / synapse send for InoRequest. Listen for responses (via existing watch or new).
- Integrate VoiceInput.
- Context broadcasting.

**Phase 3**: Gallery first-class + 15+ widgets
- Overhaul forui_ui_kit_gallery.dart into rich multi-section page.
- Implement core composed widgets.
- Update widgetbook to include ForUI + new DB widgets.

**Phase 4**: Other views + chrome
- Dashboard, Tasks (list + progress), Marketplace (cards + sheets).
- Wrap/refine Panel chrome, top overlays in canvas with ForUI.
- Timeline, Neurons, Memory stubs or full.

**Phase 5**: Polish + integration
- Command palette.
- Responsive, shortcuts (escape, / search, etc.).
- RFW template visual alignment.
- Error/loading states.

**Phase 6**: Aspire & verification
- Review/update NeuroOSPrototype.AppHost/AppHost.cs for flutter (add web dev note or separate target).
- `aspire doctor`, full run, E2E surfaces appear beautiful.
- flutter analyze/build/test + high-severity.

## Implementation Status (2026-06-27)

- Detailed plan written to app/REDESIGN_FORUI_PLAN.md
- pubspec stabilized (forui kept at compatible 0.21.x for Dart 3.11)
- FTheme wrapper added in app.dart (using neutral dark desktop base)
- New ForuiAppShell with FSidebar nav, FScaffold, global header, 10 routes
- Full INO Personal AI Assistant Chat implemented (ForUI bubbles, context bar, suggestion actions, mic stub, simulated but realistic replies that demonstrate task/market/canvas flows)
- Router updated with ShellRoute + named views; gallery and chat wired
- Gallery enhanced with more ForUI examples
- All new code compiles cleanly (pre-existing issues only in tools/)
- Next: real InoRequest wiring (via existing SynapseEnvelope), more views, canvas polish, full aspire validation, widget inventory expansion in gallery.

See todos in session for remaining slices. Ready for continued implementation or review.

**Cross-cutting**
- Keep backward: old canvas still works during transition.
- Delete old Material chrome as migrated.
- All new code: self-explanatory names, minimal comments.
- Tests: expand widget tests, semantics where possible.

## 9. Aspire / Full-Stack Considerations

- `AddFlutterClient` already present. For web dev during aspire: document `flutter run -d chrome` (endpoint injected) or add a web-server executable resource.
- When running `aspire run`: kernels (3), ollama (LLM for INO + others), gateway, flutter, mcp visible.
- Ensure env for kernel endpoint flows to Flutter gRPC.
- Marketplace surfaces + INO responses visible immediately in new UI.

## 10. Widgets Inventory (initial 20+)

See section 5. Gallery will be the single source of visual + code examples.

## 11. Verification Ritual (after every slice + final)

- `cd app && flutter pub get && flutter analyze`
- `flutter test`
- From brain/: `aspire doctor`
- dotnet build + relevant tests (if any cross)
- `aspire run` (or targeted) — verify:
  - Shell renders beautifully
  - INO chat talks, creates tasks, shows context
  - Floating panels use ForUI chrome
  - Gallery shows everything
  - Canvas + RFW still functional
- Manual UX: alignment, contrast, keyboard, resize, voice, dark mode.
- Commit only when green.

## 12. Risks & Mitigations

- Canvas perf: keep painters pure; measure.
- RFW + ForUI coexistence: theme tokens passed down or CSS-like via palette updates.
- gRPC for INO: may need small gateway extension or use existing SynapseEnvelope.
- Breaking changes: feature flag / gradual (shell behind route or env first).
- Latest ForUI: pin ^0.23.0, test on web + windows.

## 13. Next After This Doc

1. Update pubspec.
2. Theme + shell foundation.
3. INO Chat vertical (end-to-end with real InoNeuron).
4. Gallery.
5. Remaining views.
6. Full aspire validation.

This plan is complete, actionable, and respects all project laws (typed C# backend, RFW surfaces, aspire, no .ino for new behavior, Context7 research, tests, aspire run).

---

*Plan written from exploration of app/, brain/, core-requirements/projects-survey-comparison.md, ForUI docs via Context7 + web, existing InoNeuron/ChatNeuron code, and user feedback.*
