import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';

/// AI Chat screen for natural language portfolio interaction.
class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [
    _ChatMessage(
      text: 'Hello! I\'m your AI Financial Copilot. Ask me anything about your '
          'portfolio, market trends, or investment decisions. Here are some things I can help with:\n\n'
          '• Analyze your portfolio health\n'
          '• Explain why a stock is recommended\n'
          '• Simulate "what if" scenarios\n'
          '• Find tax optimization opportunities\n'
          '• Detect hidden risks in your portfolio',
      isUser: false,
      timestamp: DateTime.now(),
    ),
  ];
  bool _isTyping = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true, timestamp: DateTime.now()));
      _isTyping = true;
    });
    _messageController.clear();
    _scrollToBottom();

    // Simulate AI response
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add(_ChatMessage(
            text: _getAIResponse(text),
            isUser: false,
            timestamp: DateTime.now(),
          ));
        });
        _scrollToBottom();
      }
    });
  }

  String _getAIResponse(String query) {
    final lower = query.toLowerCase();
    if (lower.contains('portfolio') && lower.contains('health')) {
      return 'Your portfolio health score is **78/100** (Good). Here\'s the breakdown:\n\n'
          '✅ **Diversification**: 72/100 — Good spread across 12 holdings\n'
          '⚠️ **Concentration Risk**: 42% in IT sector — Consider reducing\n'
          '✅ **Quality**: 85/100 — Mostly large-cap blue chips\n'
          '⚠️ **Overlap**: 3 mutual funds share >60% common stocks\n\n'
          'Would you like me to suggest specific changes?';
    }
    if (lower.contains('sell') || lower.contains('what if')) {
      return 'Let me simulate that scenario for you.\n\n'
          '**If you sell WIPRO (200 shares @ ₹400):**\n'
          '• Realized loss: -₹10,000 (-5.0%)\n'
          '• Short-term capital loss: Can offset against STCG\n'
          '• Tax saving: ~₹1,500\n'
          '• Portfolio concentration in IT drops from 42% to 35%\n\n'
          '**Recommendation**: Consider tax-loss harvesting. Sell WIPRO and reinvest in HDFCBANK (AI rating: Strong Buy).';
    }
    if (lower.contains('risk') || lower.contains('overlap')) {
      return '🔍 **Portfolio Intelligence Report**\n\n'
          '**Risks Detected:**\n'
          '1. **Sector Concentration**: 42% in IT — above 30% threshold\n'
          '2. **Hidden Overlap**: Axis Bluechip, Mirae Large Cap, and Parag Parikh Flexi share 67% common holdings\n'
          '3. **Geographic Risk**: 95% India exposure — consider international diversification\n'
          '4. **Interest Rate Risk**: SBIN and ICICIBANK sensitive to rate cuts\n\n'
          'Want me to create a rebalancing plan?';
    }
    return 'I analyzed your query. Based on your portfolio of 12 holdings worth ₹24.5L:\n\n'
        '• Your top performer is BHARTIARTL (+25%)\n'
        '• WIPRO needs attention (-5.0%, AI rating: Sell)\n'
        '• Overall XIRR is 18.5%, beating Nifty 50 (12%)\n\n'
        'What specific aspect would you like me to dive deeper into?';
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
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
              width: 32, height: 32,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Text('AI Copilot'),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppTheme.darkBgGradient : null,
        ),
        child: Column(
          children: [
            // Quick Actions
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd, vertical: AppTheme.spacingSm),
              child: Row(
                children: [
                  _quickAction(context, '📊 Portfolio Health', 'How is my portfolio health?'),
                  _quickAction(context, '🔍 Find Risks', 'Find hidden risks and overlap in my portfolio'),
                  _quickAction(context, '💰 Tax Optimize', 'How can I optimize taxes on my portfolio?'),
                  _quickAction(context, '📈 What if', 'What if I sell WIPRO and buy HDFCBANK?'),
                  _quickAction(context, '🎯 Rebalance', 'Suggest a rebalancing plan'),
                ],
              ),
            ).animate().fadeIn(),

            const Divider(height: 1),

            // Messages
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                itemCount: _messages.length + (_isTyping ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length && _isTyping) {
                    return _typingIndicator(context);
                  }
                  return _messageBubble(context, _messages[index], index);
                },
              ),
            ),

            // Input
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  top: BorderSide(color: theme.dividerColor),
                ),
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Ask about your portfolio...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                        maxLines: 3,
                        minLines: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    FloatingActionButton.small(
                      onPressed: _sendMessage,
                      child: const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickAction(BuildContext context, String label, String message) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        onPressed: () {
          _messageController.text = message;
          _sendMessage();
        },
      ),
    );
  }

  Widget _messageBubble(BuildContext context, _ChatMessage msg, int index) {
    final theme = Theme.of(context);

    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.8,
        ),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: msg.isUser
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: msg.isUser ? const Radius.circular(4) : null,
            bottomLeft: !msg.isUser ? const Radius.circular(4) : null,
          ),
        ),
        child: SelectableText(
          msg.text,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: msg.isUser ? Colors.white : theme.colorScheme.onSurface,
            height: 1.5,
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05);
  }

  Widget _typingIndicator(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomLeft: const Radius.circular(4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dot(0), const SizedBox(width: 4),
            _dot(200), const SizedBox(width: 4),
            _dot(400),
          ],
        ),
      ),
    );
  }

  Widget _dot(int delayMs) {
    return Container(
      width: 8, height: 8,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withAlpha(77),
        shape: BoxShape.circle,
      ),
    ).animate(onPlay: (c) => c.repeat(reverse: true))
        .fadeIn(delay: Duration(milliseconds: delayMs))
        .scale(begin: const Offset(0.5, 0.5), end: const Offset(1, 1), duration: 600.ms);
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  _ChatMessage({required this.text, required this.isUser, required this.timestamp});
}
