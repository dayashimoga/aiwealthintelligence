import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/providers/portfolio_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';

class CopilotScreen extends ConsumerWidget {
  const CopilotScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final selectedId = ref.watch(selectedPortfolioIdProvider);
    final briefAsync = ref.watch(dailyBriefProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Copilot Hub'),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppTheme.darkBgGradient : null,
        ),
        child: selectedId == null
            ? const Center(child: Text('Select or create a portfolio to view AI insights.'))
            : RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(dailyBriefProvider);
                },
                child: ListView(
                  padding: const EdgeInsets.all(AppTheme.spacingMd),
                  children: [
                    // Daily Brief Card
                    Text('Daily AI Brief', style: theme.textTheme.titleMedium),
                    const SizedBox(height: AppTheme.spacingSm),
                    briefAsync.when(
                      data: (brief) {
                        if (brief == null) return const SizedBox.shrink();
                        final isPositive = brief.marketSentiment.toLowerCase() == 'positive';
                        final isNegative = brief.marketSentiment.toLowerCase() == 'negative';
                        final sentimentColor = isPositive
                            ? AppTheme.profitGreen
                            : (isNegative ? AppTheme.lossRed : AppTheme.infoBlue);
                        return GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: sentimentColor.withAlpha(30),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: sentimentColor.withAlpha(100)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.circle, size: 8, color: sentimentColor),
                                        const SizedBox(width: 6),
                                        Text(
                                          brief.marketSentiment.toUpperCase(),
                                          style: TextStyle(
                                            color: sentimentColor,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Spacer(),
                                  const Icon(Icons.auto_awesome, color: Colors.amber, size: 16),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                brief.summary,
                                style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                              ),
                              if (brief.actionableInsights.isNotEmpty) ...[
                                const Divider(height: 24),
                                Text('Actionable Insights', style: theme.textTheme.titleSmall),
                                const SizedBox(height: 8),
                                ...brief.actionableInsights.map((insight) => Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                                          Expanded(
                                            child: Text(
                                              insight,
                                              style: theme.textTheme.bodySmall?.copyWith(
                                                color: theme.colorScheme.onSurface.withAlpha(180),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )),
                              ]
                            ],
                          ),
                        ).animate().fadeIn();
                      },
                      loading: () => _buildShimmerBrief(),
                      error: (err, _) => Center(child: Text('Failed to load brief: $err')),
                    ),

                    const SizedBox(height: AppTheme.spacingLg),

                    // Quick Diagnostic Tools
                    Text('Copilot Diagnostic Tools', style: theme.textTheme.titleMedium),
                    const SizedBox(height: AppTheme.spacingSm),

                    // Portfolio Doctor Card
                    Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(AppTheme.spacingMd),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.withAlpha(20),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.health_and_safety, color: Colors.redAccent, size: 28),
                        ),
                        title: const Text('Portfolio Doctor', style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text('Diagnose structural risks, overlap issues, and concentration metrics.'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          context.push('/portfolios/$selectedId/doctor');
                        },
                      ),
                    ).animate().fadeIn(delay: 100.ms),

                    const SizedBox(height: AppTheme.spacingSm),

                    // Scenario Simulator Card
                    Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(AppTheme.spacingMd),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue.withAlpha(20),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.psychology, color: Colors.blueAccent, size: 28),
                        ),
                        title: const Text('Scenario Simulator', style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text('Simulate "what if" buy/sell transactions and observe analytics impact.'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          context.push('/portfolios/$selectedId/scenario');
                        },
                      ),
                    ).animate().fadeIn(delay: 200.ms),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildShimmerBrief() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade800,
      highlightColor: Colors.grey.shade700,
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
