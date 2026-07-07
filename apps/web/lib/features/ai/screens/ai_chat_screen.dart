import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/models.dart';
import '../../../core/providers/portfolio_providers.dart';
import '../../../core/repositories/repositories.dart';
import '../../../core/theme/app_theme.dart';

/// AI Chat screen — real API-backed, no mocks.
///
/// Sends messages to `POST /api/v1/ai/chat` with the selected portfolio context.
/// Renders AI responses including suggestion chips and referenced holdings.
class AIChatScreen extends ConsumerStatefulWidget {
  const AIChatScreen({super.key});

  @override
  ConsumerState<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends ConsumerState<AIChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<_Bubble> _bubbles = [];
  bool _isLoading = false;

  static const _welcomeText =
      'Hello! I\'m your AI Financial Copilot powered by real market intelligence.\n\n'
      'Ask me anything about your portfolio:\n'
      '• "What is my portfolio health score?"\n'
      '• "Should I sell any of my holdings?"\n'
      '• "How can I reduce my tax liability?"\n'
      '• "What are the risks in my current allocation?"';

  @override
  void initState() {
    super.initState();
    _bubbles.add(_Bubble(
      text: _welcomeText,
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isLoading) return;
    final portfolioId = ref.read(selectedPortfolioIdProvider);

    setState(() {
      _bubbles.add(_Bubble(text: text, isUser: true, timestamp: DateTime.now()));
      _isLoading = true;
    });
    _msgCtrl.clear();
    _scrollToBottom();

    final res = await ref.read(aiRepositoryProvider).chat(
          message: text,
          portfolioId: portfolioId,
        );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      res.when(
        success: (msg) => _bubbles.add(_Bubble(
          text: msg.message,
          isUser: false,
          timestamp: DateTime.now(),
          suggestions: msg.suggestions,
          referencedHoldings: msg.referencedHoldings,
          confidence: msg.confidence,
        )),
        failure: (err, _) => _bubbles.add(_Bubble(
          text: 'Sorry, I encountered an error: $err',
          isUser: false,
          timestamp: DateTime.now(),
          isError: true,
        )),
      );
    });
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.secondary,
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.auto_awesome, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 10),
            const Text('AI Copilot Chat'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear chat',
            onPressed: () => setState(() {
              _bubbles
                ..clear()
                ..add(_Bubble(
                  text: _welcomeText,
                  isUser: false,
                  timestamp: DateTime.now(),
                ));
            }),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppTheme.darkBgGradient : null,
        ),
        child: Column(
          children: [
            // Message list
            Expanded(
              child: ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                itemCount: _bubbles.length + (_isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _bubbles.length) {
                    // Typing indicator
                    return _TypingBubble(theme: theme);
                  }
                  final bubble = _bubbles[index];
                  return _ChatBubble(bubble: bubble, theme: theme)
                      .animate()
                      .fadeIn(duration: 200.ms)
                      .slideY(begin: 0.05);
                },
              ),
            ),

            // Input bar
            _InputBar(
              controller: _msgCtrl,
              isLoading: _isLoading,
              onSend: _sendMessage,
              theme: theme,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Data model for a chat bubble
// ─────────────────────────────────────────────

class _Bubble {
  _Bubble({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.suggestions = const [],
    this.referencedHoldings = const [],
    this.confidence = 0,
    this.isError = false,
  });

  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<String> suggestions;
  final List<String> referencedHoldings;
  final double confidence;
  final bool isError;
}

// ─────────────────────────────────────────────
// Chat bubble widget
// ─────────────────────────────────────────────

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.bubble, required this.theme});

  final _Bubble bubble;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final isUser = bubble.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            _AvatarBubble(theme: theme),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isUser
                        ? theme.colorScheme.primary
                        : (bubble.isError
                            ? AppTheme.lossRed.withOpacity(0.12)
                            : theme.colorScheme.surfaceContainerHighest),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isUser ? 16 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 16),
                    ),
                    border: bubble.isError
                        ? Border.all(
                            color: AppTheme.lossRed.withOpacity(0.3))
                        : null,
                  ),
                  child: Text(
                    bubble.text,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isUser
                          ? Colors.white
                          : (bubble.isError ? AppTheme.lossRed : null),
                      height: 1.45,
                    ),
                  ),
                ),

                // Confidence indicator (AI only)
                if (!isUser && bubble.confidence > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Confidence: ${(bubble.confidence * 100).toStringAsFixed(0)}%',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                    ),
                  ),
                ],

                // Referenced holdings
                if (bubble.referencedHoldings.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: bubble.referencedHoldings
                        .map((h) => Chip(
                              label: Text(h,
                                  style: const TextStyle(fontSize: 10)),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                            ))
                        .toList(),
                  ),
                ],

                // Suggestion chips
                if (bubble.suggestions.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: bubble.suggestions
                        .map((s) => ActionChip(
                              label: Text(s,
                                  style: theme.textTheme.labelSmall),
                              onPressed: () {},
                              side: BorderSide(
                                color: theme.colorScheme.primary
                                    .withOpacity(0.35),
                              ),
                            ))
                        .toList(),
                  ),
                ],

                const SizedBox(height: 2),
                Text(
                  _fmtTime(bubble.timestamp),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.35),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          if (isUser) const SizedBox(width: 10),
        ],
      ),
    );
  }

  String _fmtTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _AvatarBubble extends StatelessWidget {
  const _AvatarBubble({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.secondary,
          ],
        ),
      ),
      child: const Icon(Icons.auto_awesome, size: 16, color: Colors.white),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AvatarBubble(theme: theme),
          const SizedBox(width: 10),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DotPulse(delay: 0),
                const SizedBox(width: 4),
                _DotPulse(delay: 150),
                const SizedBox(width: 4),
                _DotPulse(delay: 300),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DotPulse extends StatelessWidget {
  const _DotPulse({required this.delay});
  final int delay;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
      ),
    )
        .animate(onPlay: (c) => c.repeat())
        .scaleXY(
          begin: 0.6,
          end: 1.0,
          duration: 600.ms,
          delay: Duration(milliseconds: delay),
          curve: Curves.easeInOut,
        )
        .then()
        .scaleXY(begin: 1.0, end: 0.6, duration: 600.ms);
  }
}

// ─────────────────────────────────────────────
// Input bar
// ─────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.isLoading,
    required this.onSend,
    required this.theme,
  });

  final TextEditingController controller;
  final bool isLoading;
  final void Function(String) onSend;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: theme.colorScheme.outline.withOpacity(0.15),
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: isLoading ? null : onSend,
                decoration: InputDecoration(
                  hintText: 'Ask your AI copilot…',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor:
                      theme.colorScheme.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isLoading
                    ? null
                    : LinearGradient(
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.secondary,
                        ],
                      ),
                color: isLoading
                    ? theme.colorScheme.outline.withOpacity(0.3)
                    : null,
              ),
              child: IconButton(
                icon: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded,
                        color: Colors.white, size: 20),
                onPressed: isLoading
                    ? null
                    : () => onSend(controller.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
