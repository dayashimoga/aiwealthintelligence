import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/portfolio_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';

/// Screen presenting Advanced Wealth Diagnostics including Stress Tests, Tax Offsets, Biases, and Goals.
class AdvancedAnalysisScreen extends ConsumerWidget {
  const AdvancedAnalysisScreen({super.key, required this.portfolioId});

  final String portfolioId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final analysisAsync = ref.watch(advancedAnalysisProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Advanced Wealth Analysis'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(advancedAnalysisProvider);
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppTheme.darkBgGradient : null,
        ),
        child: analysisAsync.when(
          data: (analysis) {
            if (analysis == null) {
              return const Center(child: Text('No advanced analytics data compiled.'));
            }

            return DefaultTabController(
              length: 4,
              child: Column(
                children: [
                  Material(
                    color: theme.colorScheme.surface.withAlpha(200),
                    child: TabBar(
                      isScrollable: true,
                      labelColor: theme.colorScheme.primary,
                      unselectedLabelColor: theme.colorScheme.onSurface.withAlpha(150),
                      indicatorColor: theme.colorScheme.primary,
                      tabs: const [
                        Tab(icon: Icon(Icons.flash_on), text: 'Stress Tests'),
                        Tab(icon: Icon(Icons.percent), text: 'Tax Harvest'),
                        Tab(icon: Icon(Icons.psychology), text: 'Biases'),
                        Tab(icon: Icon(Icons.track_changes), text: 'Goals'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildStressTab(context, analysis),
                        _buildTaxTab(context, analysis),
                        _buildBiasesTab(context, analysis),
                        _buildGoalsTab(context, analysis),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingLg),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: AppTheme.lossRed),
                  const SizedBox(height: 16),
                  Text('Failed to compile advanced metrics', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(err.toString(), textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(advancedAnalysisProvider),
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

  Widget _buildStressTab(BuildContext context, dynamic analysis) {
    final theme = Theme.of(context);
    final stressList = analysis.stressTest;

    if (stressList == null || stressList.isEmpty) {
      return const Center(child: Text('Add holdings to run stress scenario models.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      itemCount: stressList.length,
      itemBuilder: (context, index) {
        final scenario = stressList[index];
        final changeColor = scenario.changeValue < 0 ? AppTheme.lossRed : AppTheme.profitGreen;

        return Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.spacingMd),
          child: GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        scenario.scenarioName,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    _buildImpactBadge(scenario.impactLevel),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  scenario.scenarioDescription,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withAlpha(160)),
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Stress Valuation', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        const SizedBox(height: 4),
                        Text(
                          '₹${scenario.estimatedNewValue.toStringAsFixed(2)}',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Modelled Return', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        const SizedBox(height: 4),
                        Text(
                          '${scenario.changeValue >= 0 ? "+" : ""}₹${scenario.changeValue.toStringAsFixed(2)} (${scenario.changePercentage.toStringAsFixed(2)}%)',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: changeColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ).animate().fadeIn(delay: (index * 100).ms).slideX(begin: 0.05);
      },
    );
  }

  Widget _buildImpactBadge(String impact) {
    Color bg;
    Color text;
    String label;

    switch (impact.toLowerCase()) {
      case 'high_negative':
        bg = AppTheme.lossRed.withAlpha(30);
        text = AppTheme.lossRed;
        label = 'CRITICAL DROP';
        break;
      case 'negative':
        bg = Colors.orange.withAlpha(30);
        text = Colors.orange;
        label = 'MODERATE DROP';
        break;
      case 'positive':
      case 'high_positive':
        bg = AppTheme.profitGreen.withAlpha(30);
        text = AppTheme.profitGreen;
        label = 'APPRECIATES';
        break;
      default:
        bg = Colors.grey.withAlpha(30);
        text = Colors.grey;
        label = 'NEUTRAL';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: text.withAlpha(100)),
      ),
      child: Text(
        label,
        style: TextStyle(color: text, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildTaxTab(BuildContext context, dynamic analysis) {
    final theme = Theme.of(context);
    final taxSavings = analysis.totalPotentialTaxSavings;
    final opportunities = analysis.taxHarvesting;

    return ListView(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      children: [
        // Top Savings banner
        Container(
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF00B0FF), Color(0xFF00E5FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.savings, color: Colors.white, size: 40),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Potential Tax Savings',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${taxSavings.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ).animate().fadeIn().scale(begin: const Offset(0.97, 0.97)),

        const SizedBox(height: AppTheme.spacingLg),

        Text(
          'Tax Loss Harvesting Opportunities',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Offset taxable capital gains by selling underperforming assets and immediately repurchasing corresponding index replacements.',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withAlpha(140)),
        ),
        const SizedBox(height: AppTheme.spacingMd),

        if (opportunities == null || opportunities.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(AppTheme.spacingLg),
              child: Center(
                child: Text('No tax harvesting opportunities detected (no holdings with unrealized losses).'),
              ),
            ),
          )
        else
          ...opportunities.map((opp) {
            final periodText = opp.holdingPeriodDays > 365 ? 'Long Term' : 'Short Term';
            final periodColor = opp.holdingPeriodDays > 365 ? Colors.blue : Colors.orange;

            return Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.spacingMd),
              child: GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          opp.symbol,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: periodColor.withAlpha(30),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: periodColor.withAlpha(100)),
                          ),
                          child: Text(
                            periodText,
                            style: TextStyle(color: periodColor, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Tax Save: ₹${opp.potentialTaxSavings.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: AppTheme.profitGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Quantity', style: TextStyle(fontSize: 10, color: Colors.grey)),
                            const SizedBox(height: 2),
                            Text(opp.quantity.toStringAsFixed(0)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Avg Cost', style: TextStyle(fontSize: 10, color: Colors.grey)),
                            const SizedBox(height: 2),
                            Text('₹${opp.averageBuyPrice.toStringAsFixed(2)}'),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Unrealized Loss', style: TextStyle(fontSize: 10, color: Colors.grey)),
                            const SizedBox(height: 2),
                            Text(
                              '-₹${opp.unrealizedLoss.toStringAsFixed(2)}',
                              style: const TextStyle(color: AppTheme.lossRed, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
      ],
    );
  }

  Widget _buildBiasesTab(BuildContext context, dynamic analysis) {
    final theme = Theme.of(context);
    final biases = analysis.behavioralBiases;

    if (biases == null || biases.isEmpty) {
      return const Center(child: Text('No behavioral biases analyzed.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      itemCount: biases.length,
      itemBuilder: (context, index) {
        final bias = biases[index];
        final isLow = bias.severity.toLowerCase() == 'low';
        final color = bias.severity.toLowerCase() == 'high'
            ? AppTheme.lossRed
            : (bias.severity.toLowerCase() == 'medium' ? Colors.orange : AppTheme.profitGreen);

        return Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.spacingMd),
          child: GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isLow ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                      color: color,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        bias.biasName,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withAlpha(20),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: color.withAlpha(80)),
                      ),
                      child: Text(
                        bias.severity.toUpperCase(),
                        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  bias.description,
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                ),
                const Divider(height: 24),
                Text(
                  'Remedy Suggestion:',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: color),
                ),
                const SizedBox(height: 6),
                Text(
                  bias.remedy,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: theme.colorScheme.onSurface.withAlpha(180),
                  ),
                ),
              ],
            ),
          ),
        ).animate().fadeIn(delay: (index * 100).ms);
      },
    );
  }

  Widget _buildGoalsTab(BuildContext context, dynamic analysis) {
    final theme = Theme.of(context);
    final goals = analysis.goals;

    if (goals == null || goals.isEmpty) {
      return const Center(child: Text('Configure goals in settings to start tracking milestones.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      itemCount: goals.length,
      itemBuilder: (context, index) {
        final goal = goals[index];
        final progress = goal.progressPercentage / 100.0;
        final progressColor = goal.status == 'ahead'
            ? AppTheme.profitGreen
            : (goal.status == 'behind' ? Colors.orange : AppTheme.infoBlue);

        return Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.spacingMd),
          child: GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      goal.goalName,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${goal.progressPercentage.toStringAsFixed(1)}% Completed',
                      style: TextStyle(
                        color: progressColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 12,
                    backgroundColor: theme.colorScheme.onSurface.withAlpha(30),
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Current: ₹${goal.currentAmount.toStringAsFixed(0)}',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                    ),
                    Text(
                      'Target: ₹${goal.targetAmount.toStringAsFixed(0)}',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ).animate().fadeIn(delay: (index * 100).ms);
      },
    );
  }
}
