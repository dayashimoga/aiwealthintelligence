import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';

/// AI recommendation detail screen for a specific holding.
class RecommendationScreen extends StatelessWidget {
  const RecommendationScreen({
    super.key,
    required this.portfolioId,
    required this.holdingId,
  });

  final String portfolioId;
  final String holdingId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Recommendation'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {},
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppTheme.darkBgGradient : null,
        ),
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          children: [
            // Holding Header
            GlassCard(
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(
                      child: Text('RE', style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20,
                      )),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('RELIANCE', style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        )),
                        Text('Reliance Industries Ltd', style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withAlpha(128),
                        )),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('₹2,800', style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      )),
                      Text('+12.0%', style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.profitGreen, fontWeight: FontWeight.w600,
                      )),
                    ],
                  ),
                ],
              ),
            ).animate().fadeIn(),

            const SizedBox(height: AppTheme.spacingMd),

            // AI Action Banner
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.white, size: 32),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('AI Recommendation', style: TextStyle(
                          color: Colors.white70, fontSize: 12,
                        )),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Text('HOLD', style: TextStyle(
                              color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900,
                            )),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(51),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text('72% Confidence', style: TextStyle(
                                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600,
                              )),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 100.ms).scale(begin: const Offset(0.97, 0.97)),

            const SizedBox(height: AppTheme.spacingMd),

            // Key Metrics
            ResponsiveGrid(
              mobileCols: 2,
              tabletCols: 3,
              desktopCols: 3,
              children: [
                _metricTile(context, 'Expected Return', '10-15%', Icons.trending_up, AppTheme.profitGreen),
                _metricTile(context, 'Risk Level', 'Moderate', Icons.shield, AppTheme.warningAmber),
                _metricTile(context, 'Horizon', '12-18 months', Icons.access_time, AppTheme.infoBlue),
              ],
            ),

            const SizedBox(height: AppTheme.spacingLg),

            // Reasoning
            Text('Reasoning', style: theme.textTheme.titleMedium).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: AppTheme.spacingSm),
            GlassCard(
              child: Text(
                'Reliance Industries remains a strong conglomerate play with diversified revenue streams. '
                'The Jio platform continues to drive subscriber growth, while retail expansion adds value. '
                'Current valuation is fair at 25x forward PE. The stock is trading near its 200-DMA, '
                'suggesting consolidation before the next move. Given the portfolio\'s existing 11% weight '
                'in this stock, holding the current position is recommended rather than adding more.',
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
              ),
            ).animate().fadeIn(delay: 300.ms),

            const SizedBox(height: AppTheme.spacingLg),

            // AI Explainability
            Text('AI Explainability', style: theme.textTheme.titleMedium).animate().fadeIn(delay: 400.ms),
            const SizedBox(height: AppTheme.spacingSm),

            ..._explainabilityItems.asMap().entries.map((entry) {
              final item = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _explainabilityTile(context, item['title'] as String,
                    item['content'] as String, item['icon'] as IconData, item['color'] as Color),
              ).animate().fadeIn(delay: Duration(milliseconds: 500 + entry.key * 80));
            }),

            const SizedBox(height: AppTheme.spacingLg),

            // Evidence
            Text('Evidence', style: theme.textTheme.titleMedium).animate().fadeIn(delay: 800.ms),
            const SizedBox(height: AppTheme.spacingSm),
            ..._evidence.map((e) => ListTile(
              dense: true,
              leading: const Icon(Icons.check_circle, color: AppTheme.profitGreen, size: 20),
              title: Text(e, style: theme.textTheme.bodySmall),
              contentPadding: EdgeInsets.zero,
            )),

            const SizedBox(height: AppTheme.spacingLg),

            // Alternative Suggestions
            Text('Alternatives to Consider', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppTheme.spacingSm),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['HDFCBANK', 'ICICIBANK', 'BAJFINANCE', 'SBIN'].map((s) =>
                ActionChip(
                  avatar: const Icon(Icons.compare_arrows, size: 16),
                  label: Text(s),
                  onPressed: () {},
                ),
              ).toList(),
            ),

            const SizedBox(height: AppTheme.spacingXxl),
          ],
        ),
      ),
    );
  }

  Widget _metricTile(BuildContext context, String label, String value, IconData icon, Color color) {
    final theme = Theme.of(context);
    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(value, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label, style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withAlpha(128),
          )),
        ],
      ),
    );
  }

  Widget _explainabilityTile(BuildContext context, String title, String content, IconData icon, Color color) {
    final theme = Theme.of(context);
    return ExpansionTile(
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: color.withAlpha(26),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
      title: Text(title, style: theme.textTheme.titleSmall),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Text(content, style: theme.textTheme.bodySmall?.copyWith(height: 1.5)),
        ),
      ],
    );
  }

  static final _explainabilityItems = [
    {'title': 'Fundamentals', 'content': 'Revenue growth: 12% YoY. EBITDA margin: 16.2%. Debt-to-equity: 0.42. Strong cash flow generation from Jio and Retail segments.', 'icon': Icons.foundation, 'color': const Color(0xFF6C63FF)},
    {'title': 'Technical Indicators', 'content': 'Trading above 50-DMA (₹2,720) and near 200-DMA (₹2,650). RSI: 55 (neutral). MACD showing bullish crossover. Support at ₹2,600.', 'icon': Icons.show_chart, 'color': const Color(0xFF00D9A6)},
    {'title': 'News Sentiment', 'content': 'Positive sentiment from Jio tariff hikes and new energy investments. Minor concern about telecom ARPU growth slowing.', 'icon': Icons.newspaper, 'color': const Color(0xFF2979FF)},
    {'title': 'Macroeconomics', 'content': 'Favorable Indian GDP growth outlook (6.5%). Rising crude oil prices could impact margins for O2C segment.', 'icon': Icons.public, 'color': const Color(0xFFFF6B6B)},
    {'title': 'Valuation', 'content': 'P/E: 25x (sector avg: 22x). EV/EBITDA: 12x. PEG ratio: 1.8. Fair value estimate: ₹2,900-3,100.', 'icon': Icons.calculate, 'color': const Color(0xFFFFAB00)},
    {'title': 'Sector Outlook', 'content': 'Conglomerate sector showing strength. Digital services and green energy are key growth drivers for the next decade.', 'icon': Icons.business, 'color': const Color(0xFF7C4DFF)},
    {'title': 'Institutional Activity', 'content': 'FIIs reduced stake by 0.3% last quarter. DIIs increased by 0.5%. Mutual fund holdings stable.', 'icon': Icons.groups, 'color': const Color(0xFF00BCD4)},
    {'title': 'Insider Activity', 'content': 'Promoter holding stable at 50.3%. No significant insider transactions in last 6 months.', 'icon': Icons.person_search, 'color': const Color(0xFFE91E63)},
    {'title': 'Market Sentiment', 'content': 'Overall market bullish with Nifty near all-time highs. Broad-based participation from midcaps and smallcaps.', 'icon': Icons.sentiment_satisfied, 'color': const Color(0xFF4CAF50)},
  ];

  static const _evidence = [
    'Jio subscriber base crossed 490 million with rising ARPU',
    'Retail revenue grew 18% YoY in last quarter',
    'New energy business received ₹75,000 Cr investment commitment',
    'Strong free cash flow of ₹12,000 Cr in last quarter',
    'Consistent dividend track record over 10 years',
  ];
}
