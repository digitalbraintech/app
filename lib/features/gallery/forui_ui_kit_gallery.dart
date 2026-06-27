import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

// MIGRATED to UI kit: Gallery content emitted as "ui-kit-rich" neuron tree (forui components via renderer).
// This file deprecated (no longer used in main paths).
class ForuiUiKitGallery extends StatelessWidget {
  const ForuiUiKitGallery({super.key});

  @override
  Widget build(BuildContext context) {
    // ForUI native inside the global shell FTheme.
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FCard(
            title: const Text('ForUI Primitives'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FButton(
                  onPress: () {},
                  child: const Text('ForUI Button (Primary)'),
                ),
                const SizedBox(height: 12),
                FButton(
                  variant: FButtonVariant.outline,
                  onPress: () {},
                  child: const Text('Outline Button'),
                ),
                const SizedBox(height: 16),
                FCard(
                  title: const Text('ForUI Card'),
                  subtitle: const Text('Great for panels and content surfaces'),
                  child: const Text(
                      'ForUI provides modern components for native shell, gallery, and chat UIs. Dynamic content like charts stays in RFW surfaces emitted by neurons.'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FCard(
            title: const Text('Charts with graphic + conversational AI'),
            subtitle: const Text('Server-driven via ChartNeuron'),
            child: const Text(
              '• Use the Chart Lab in main workspace for CSV data source\n'
              '• Chat prompts ("filter last 7 days", "switch to area", "highlight outliers") send ChartCommand\n'
              '• Live updates in floating panels without leaving the chart\n'
              '• Powered by entronad/graphic in the RFW custom widget'),
          ),
          const SizedBox(height: 24),
          FCard(
            title: const Text('More ForUI building blocks (used in shell + chat)'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FButton(onPress: () {}, child: const Text('Primary Action')),
                const SizedBox(height: 8),
                Row(children: [
                  FBadge(child: const Text('3/3 kernels')),
                  const SizedBox(width: 8),
                  FBadge(child: const Text('INO ready')),
                ]),
                const SizedBox(height: 12),
                const FDivider(),
                const SizedBox(height: 8),
                const Text('FSidebar + FScaffold for navigation. FResizable + FCard for surfaces. Chat uses FTextField + action FButtons.'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FCard(
            title: const Text('Scaffold + Buddy Search (ForUI in Neuron UI Kit)'),
            subtitle: const Text('Shell from neuron tree; marketplace autocomplete'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('FScaffold + FHeader/FSidebar from forui:FScaffold tree (shell neuron emitted).'),
                const SizedBox(height: 8),
                FTextField(label: const Text('Buddy search demo'), hint: 'Type for packs/neurons'),
                const SizedBox(height: 8),
                const Text('Autocomplete items + select fire UiInputSynapse (roundtrip to neurons).'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'The main living canvas and floating panels continue to use the custom digital_brain_ui + RFW for full server-driven flexibility. ForUI now owns all shell, nav, forms and the INO chat.',
            style: TextStyle(fontSize: 13, color: FTheme.of(context).colors.mutedForeground),
          ),
          const SizedBox(height: 16),
          FButton(
            onPress: () => context.go('/'),
            child: const Text('Back to Brain Canvas'),
          ),
        ],
      ),
    );
  }
}