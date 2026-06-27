import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

class InoChatScreen extends StatefulWidget {
  const InoChatScreen({super.key});

  @override
  State<InoChatScreen> createState() => _InoChatScreenState();
}

class _InoChatScreenState extends State<InoChatScreen> {
  final List<_Message> _messages = [];
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _messages.add(const _Message(
      isUser: false,
      text: 'Hello. I am INO, your personal DigitalBrain assistant. I have full context from journals, tasks, packs and the current view. How can I help the brain today?',
    ));
  }

  void _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _messages.add(_Message(isUser: true, text: text));
      _sending = true;
      _input.clear();
    });
    _scrollToEnd();

    // TODO: real wire - send InoRequest via gateway / synapse and await InoResponse
    // For now simulate rich assistant response (context aware)
    await Future.delayed(const Duration(milliseconds: 650));

    final reply = _fakeInoReply(text);

    if (!mounted) return;
    setState(() {
      _messages.add(_Message(isUser: false, text: reply.text, actions: reply.actions));
      _sending = false;
    });
    _scrollToEnd();
  }

  _Reply _fakeInoReply(String prompt) {
    final lower = prompt.toLowerCase();
    if (lower.contains('task')) {
      return const _Reply(
        'TASK: summarize recent activity into a new MemorySummary. I will also surface the active tasks.',
        actions: ['Run Task', 'Show Tasks'],
      );
    }
    if (lower.contains('market') || lower.contains('pack')) {
      return const _Reply('I see 4 packs available. Want me to install the latest "reviewer" pack into this brain?', actions: ['Install', 'Browse Marketplace']);
    }
    if (lower.contains('canvas') || lower.contains('brain')) {
      return const _Reply('Currently seeing the living canvas with 12 nodes and 7 recent synapses. The visual constructor is active.', actions: ['Auto layout', 'Fire test synapse']);
    }
    return const _Reply('Understood. I have updated my context from your current view and recent journals. What would you like to explore or execute next?', actions: ['Recall context', 'Create checkpoint']);
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent + 80, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  void _handleAction(String action) {
    setState(() {
      _messages.add(_Message(isUser: false, text: 'Action triggered: $action (wired to real kernel task/panel in full impl)'));
    });
    _scrollToEnd();
  }

  @override
  Widget build(BuildContext context) {
    final t = FTheme.of(context);

    return Column(
      children: [
        // Context bar
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: t.colors.muted.withValues(alpha: 0.3),
          child: Text(
            'Context: Brain Canvas • 3 active tasks • 2 packs • last memory: "review flow"',
            style: t.typography.xs.copyWith(color: t.colors.mutedForeground),
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length,
            itemBuilder: (c, i) {
              final m = _messages[i];
              return _ChatBubble(message: m, onAction: _handleAction);
            },
          ),
        ),
        _ChatInput(
          controller: _input,
          sending: _sending,
          onSend: _send,
        ),
      ],
    );
  }
}

class _Message {
  final bool isUser;
  final String text;
  final List<String> actions;

  const _Message({required this.isUser, required this.text, this.actions = const []});
}

class _Reply {
  final String text;
  final List<String> actions;
  const _Reply(this.text, {this.actions = const []});
}

class _ChatBubble extends StatelessWidget {
  final _Message message;
  final ValueChanged<String> onAction;

  const _ChatBubble({required this.message, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final t = FTheme.of(context);
    final isUser = message.isUser;

    return Padding(
      padding: EdgeInsets.only(bottom: 12, left: isUser ? 48 : 0, right: isUser ? 0 : 48),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isUser ? t.colors.primary : t.colors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: t.colors.border, width: 0.5),
            ),
            child: Text(
              message.text,
              style: t.typography.md.copyWith(color: isUser ? t.colors.primaryForeground : t.colors.foreground),
            ),
          ),
          if (message.actions.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: message.actions.map((a) => FButton(
                variant: FButtonVariant.outline,
                onPress: () => onAction(a),
                child: Text(a),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChatInput extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  const _ChatInput({required this.controller, required this.sending, required this.onSend});

  @override
  Widget build(BuildContext context) {
    final t = FTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: t.colors.border, width: 0.5)),
        color: t.colors.background,
      ),
      child: Row(
        children: [
          FButton(
            variant: FButtonVariant.ghost,
            onPress: () {}, // TODO integrate real VoiceInput
            child: const Icon(Icons.mic),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'Ask INO anything about the brain, tasks, packs...',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              style: TextStyle(color: t.colors.foreground),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 8),
          FButton(
            onPress: sending ? null : onSend,
            child: sending ? const Icon(Icons.refresh) : const Text('Send'),
          ),
        ],
      ),
    );
  }
}