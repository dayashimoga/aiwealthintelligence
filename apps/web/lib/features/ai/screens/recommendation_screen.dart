import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/portfolio_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';

/// AI recommendation detail screen for a specific holding.
class RecommendationScreen extends ConsumerWidget {
  const RecommendationScreen({
    super.key,
    required this.portfolioId,
    required this.holdingId,
  });

  final String portfolioId;
  final String holdingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final holdingsAsync = ref.watch(holdingsProvider);
    final recommendationAsync = ref.watch(aiRecommendationProvider(holdingId));

    final holding = holdingsAsync.whenOrNull(
      data: (list) {
        final index = list.indexWhere((h) => h.id == holdingId);
        return index != -1 ? list[index] : null;
      },
    );

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
            onPressed: () {
              ref.invalidate(aiRecommendationProvider(holdingId));
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppTheme.darkBgGradient : null,
        ),
        child: recommendationAsync.when(
          data: (rec) {
            if (rec == null) {
              return const Center(child: Text('No recommendation available.'));
            }

            final isPositive = (holding?.gainLossPct ?? 0) >= 0;
            final actionColor = _getActionColor(rec.action);

            return ListView(
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
                        child: Center(
                          child: Text(
                            (holding?.symbol ?? rec.symbol).substring(0, 2).toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              holding?.symbol ?? rec.symbol,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              holding?.name ?? 'Stock Asset Details',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withAlpha(128),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (holding != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₹${holding.currentPrice.toStringAsFixed(2)}',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${isPositive ? "+" : ""}${holding.gainLossPct.toStringAsFixed(2)}%',
                              style: TextStyle(
                                color: isPositive ? AppTheme.profitGreen : AppTheme.lossRed,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
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
                    gradient: LinearGradient(
                      colors: [actionColor.withAlpha(200), actionColor],
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
                            const Text(
                              'AI Recommendation',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  rec.action.replaceAll('_', ' ').toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withAlpha(51),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '${rec.confidence.toInt()}% Confidence',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
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
                  mobileCols: 3,
                  tabletCols: 3,
                  desktopCols: 3,
                  children: [
                    _metricTile(
                      context,
                      'Expected Return',
                      '~${rec.expectedReturn.toStringAsFixed(1)}%',
                      Icons.trending_up,
                      AppTheme.profitGreen,
                    ),
                    _metricTile(
                      context,
                      'Risk Level',
                      rec.riskLevel.toUpperCase(),
                      Icons.shield,
                      _getRiskColor(rec.riskLevel),
                    ),
                    _metricTile(
                      context,
                      'Horizon',
                      rec.investmentHorizon.isEmpty ? 'N/A' : rec.investmentHorizon,
                      Icons.access_time,
                      AppTheme.infoBlue,
                    ),
                  ],
                ),

                const SizedBox(height: AppTheme.spacingLg),

                // Reasoning
                Text('Reasoning', style: theme.textTheme.titleMedium).animate().fadeIn(delay: 200.ms),
                const SizedBox(height: AppTheme.spacingSm),
                GlassCard(
                  child: Text(
                    rec.reasoning,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                  ),
                ).animate().fadeIn(delay: 300.ms),

                const SizedBox(height: AppTheme.spacingLg),

                // Risk Description Warning Box
                if (rec.riskDescription.isNotEmpty) ...[
                  Text('Downside Risk Analysis', style: theme.textTheme.titleMedium).animate().fadeIn(delay: 350.ms),
                  const SizedBox(height: AppTheme.spacingSm),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.lossRed.withAlpha(20),
                      border: Border.all(color: AppTheme.lossRed.withAlpha(80)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: AppTheme.lossRed, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Risk Assessment Details',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.lossRed,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                rec.riskDescription,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withAlpha(200),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 380.ms),
                  const SizedBox(height: AppTheme.spacingLg),
                ],

                // AI Explainability factors
                if (rec.explainability.isNotEmpty) ...[
                  Text('Explainability Factors', style: theme.textTheme.titleMedium).animate().fadeIn(delay: 400.ms),
                  const SizedBox(height: AppTheme.spacingSm),
                  ...rec.explainability.entries.map((entry) {
                    final key = entry.key;
                    final content = entry.value.toString();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _explainabilityTile(
                        context,
                        _formatKey(key),
                        content,
                        _getKeyIcon(key),
                        _getKeyColor(key),
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: AppTheme.spacingLg),
                ],

                // Evidence check list
                if (rec.evidence.isNotEmpty) ...[
                  Text('Supporting Evidence', style: theme.textTheme.titleMedium).animate().fadeIn(delay: 800.ms),
                  const SizedBox(height: AppTheme.spacingSm),
                  ...rec.evidence.map((e) => ListTile(
                        dense: true,
                        leading: const Icon(Icons.check_circle, color: AppTheme.profitGreen, size: 20),
                        title: Text(e, style: theme.textTheme.bodySmall),
                        contentPadding: EdgeInsets.zero,
                      )),
                  const SizedBox(height: AppTheme.spacingLg),
                ],

                // Alternative Suggestions chips
                if (rec.alternativeSuggestions.isNotEmpty) ...[
                  Text('Alternatives to Consider', style: theme.textTheme.titleMedium),
                  const SizedBox(height: AppTheme.spacingSm),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: rec.alternativeSuggestions
                        .map((s) => ActionChip(
                              avatar: const Icon(Icons.compare_arrows, size: 16),
                              label: Text(s),
                              onPressed: () {},
                            ))
                        .toList(),
                  ),
                ],

                const SizedBox(height: AppTheme.spacingXxl),
              ],
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),
          error: (err, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingLg),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: AppTheme.lossRed),
                  const SizedBox(height: 16),
                  Text('Failed loading AI recommendation', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(err.toString(), textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(aiRecommendationProvider(holdingId)),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
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
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(128),
            ),
          ),
        ],
      ),
    );
  }

  Widget _explainabilityTile(BuildContext context, String title, String content, IconData icon, Color color) {
    final theme = Theme.of(context);
    return ExpansionTile(
      leading: Container(
        width: 36,
        height: 36,
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

  Color _getActionColor(String action) {
    switch (action.toLowerCase()) {
      case 'strong_buy':
      case 'buy':
        return AppTheme.profitGreen;
      case 'hold':
        return AppTheme.warningAmber;
      default:
        return AppTheme.lossRed;
    }
  }

  Color _getRiskColor(String risk) {
    switch (risk.toLowerCase()) {
      case 'low':
        return AppTheme.profitGreen;
      case 'moderate':
        return AppTheme.infoBlue;
      case 'high':
        return AppTheme.warningAmber;
      default:
        return AppTheme.lossRed;
    }
  }

  String _formatKey(String key) {
    return key.replaceAll('_', ' ').split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }

  IconData _getKeyIcon(String key) {
    switch (key.toLowerCase()) {
      case 'fundamentals':
        return Icons.foundation;
      case 'technical_indicators':
        return Icons.show_chart;
      case 'news_sentiment':
        return Icons.newspaper;
      case 'macroeconomics':
        return Icons.public;
      case 'valuation':
        return Icons.calculate;
      case 'sector_outlook':
        return Icons.business;
      case 'institutional_activity':
        return Icons.groups;
      case 'insider_activity':
        return Icons.person_search;
      default:
        return Icons.analytics;
    }
  }

  Color _getKeyColor(String key) {
    switch (key.toLowerCase()) {
      case 'fundamentals':
        return const Color(0xFF6C63FF);
      case 'technical_indicators':
        return const Color(0xFF00D9A6);
      case 'news_sentiment':
        return const Color(0xFF2979FF);
      case 'macroeconomics':
        return const Color(0xFFFF6B6B);
      case 'valuation':
        return const Color(0xFFFFAB00);
      case 'sector_outlook':
        return const Color(0xFF7C4DFF);
      case 'institutional_activity':
        return const Color(0xFF00BCD4);
      case 'insider_activity':
        return const Color(0xFFE91E63);
      default:
        return Colors.blueGrey;
    }
  }
}
