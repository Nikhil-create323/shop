import 'dart:convert';
import 'package:dummy_apps/providers/assistant_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class _ChatLine {
  const _ChatLine({required this.text, required this.isUser});

  final String text;
  final bool isUser;
}

/// FAB opens a chat panel on the right (~42% width); the [child] shrinks to the
/// remaining space instead of being covered. Messages use [AssistantNotifier.searchProducts].
class FloatingSideChat extends ConsumerStatefulWidget {
  const FloatingSideChat({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<FloatingSideChat> createState() => _FloatingSideChatState();
}

class _FloatingSideChatState extends ConsumerState<FloatingSideChat> {
  final List<_ChatLine> _lines = [];
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _open = false;
  bool _sending = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String _formatAssistantReply(Map<String, dynamic> data) {
    final count = data['count'] ?? (data['products'] as List?)?.length ?? 0;
    final filter = data['filter'];
    final buffer = StringBuffer('Found $count product(s).\n');

    if (filter != null) {
      buffer.writeln(
        '\nFilter:\n${const JsonEncoder.withIndent('  ').convert(filter)}',
      );
    }

    final products = data['products'] as List?;
    if (products != null && products.isNotEmpty) {
      buffer.writeln('\nResults:');
      for (final p in products) {
        if (p is! Map) continue;
        final title = p['title']?.toString() ?? 'Unknown';
        final price = p['price'];
        buffer.writeln('• $title — ₹$price');
      }
    }

    return buffer.toString().trim();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _lines.add(_ChatLine(text: text, isUser: true));
      _input.clear();
      _sending = true;
    });
    _scrollToEnd();

    try {
      final data = await ref
          .read(assistantProvider.notifier)
          .searchProducts(text);

      if (!mounted) return;

      setState(() {
        _lines.add(_ChatLine(text: _formatAssistantReply(data), isUser: false));
      });
    } catch (e) {
      if (!mounted) return;

      final message = e.toString().replaceFirst('Exception: ', '').trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message.isNotEmpty
                ? message
                : 'Unable to search products right now.',
          ),
        ),
      );

      setState(() {
        _lines.add(_ChatLine(text: 'Search failed: $message', isUser: false));
      });
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        _scrollToEnd();
      }
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Widget _buildPanel(BuildContext context, double panelW) {
    return Material(
      elevation: 4,
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        left: false,
        child: SizedBox(
          width: panelW,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    const Text(
                      'Assistant',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _open = false),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _lines.isEmpty
                    ? Center(
                        child: Text(
                          'Describe products to search…',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.all(12),
                        itemCount: _lines.length,
                        itemBuilder: (context, i) {
                          final m = _lines[i];
                          return Align(
                            alignment: m.isUser
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              constraints: BoxConstraints(
                                maxWidth: panelW - 40,
                              ),
                              decoration: BoxDecoration(
                                color: m.isUser
                                    ? Theme.of(
                                        context,
                                      ).colorScheme.primaryContainer
                                    : Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: SelectableText(
                                m.text,
                                style: TextStyle(
                                  color: m.isUser
                                      ? Theme.of(
                                          context,
                                        ).colorScheme.onPrimaryContainer
                                      : Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              if (_sending) const LinearProgressIndicator(minHeight: 2),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: const InputDecoration(
                          hintText: 'e.g. books under 200',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _sending ? null : _send,
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    const panelFraction = 0.42;
    final panelW = width * panelFraction;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              widget.child,
              if (!_open)
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: SafeArea(
                    child: FloatingActionButton(
                      heroTag: null,
                      onPressed: () => setState(() => _open = true),
                      tooltip: 'Open chat',
                      child: const Icon(Icons.chat_bubble_outline),
                    ),
                  ),
                ),
            ],
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          width: _open ? panelW : 0,
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            border: _open
                ? Border(
                    left: BorderSide(color: Theme.of(context).dividerColor),
                  )
                : null,
          ),
          child: _open ? _buildPanel(context, panelW) : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
