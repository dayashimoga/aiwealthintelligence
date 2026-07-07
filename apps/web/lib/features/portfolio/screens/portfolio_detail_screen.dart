import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/models/models.dart';
import '../../../core/providers/portfolio_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/repositories/repositories.dart';

/// Portfolio detail screen showing holdings, analytics, and AI insights.
class PortfolioDetailScreen extends ConsumerStatefulWidget {
  const PortfolioDetailScreen({super.key, required this.portfolioId});

  final String portfolioId;

  @override
  ConsumerState<PortfolioDetailScreen> createState() =>
      _PortfolioDetailScreenState();
}

class _PortfolioDetailScreenState extends ConsumerState<PortfolioDetailScreen> {
  final _currencyFormatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    // Set active portfolio ID in state provider
    Future.microtask(() {
      ref.read(selectedPortfolioIdProvider.notifier).state = widget.portfolioId;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final portfoliosAsync = ref.watch(portfoliosProvider);
    final holdingsAsync = ref.watch(holdingsProvider);
    final analyticsAsync = ref.watch(portfolioAnalyticsProvider);

    // Find the current portfolio from list if loaded
    Portfolio? currentPortfolio;
    portfoliosAsync.whenData((list) {
      final index = list.indexWhere((p) => p.id == widget.portfolioId);
      if (index != -1) {
        currentPortfolio = list[index];
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(currentPortfolio?.name ?? 'Portfolio Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload_outlined),
            tooltip: 'Import Report',
            onPressed: () {
              context.push('/portfolios/${widget.portfolioId}/import');
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'delete') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Portfolio'),
                    content: const Text(
                        'Are you sure you want to delete this portfolio? All holdings will be permanently removed.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel')),
                      TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Delete',
                              style: TextStyle(color: Colors.red))),
                    ],
                  ),
                );
                if (confirm == true) {
                  final repo = ref.read(portfolioRepositoryProvider);
                  final res = await repo.deletePortfolio(widget.portfolioId);
                  res.when(
                    success: (_) {
                      ref.invalidate(portfoliosProvider);
                      context.pop();
                    },
                    failure: (err, _) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Delete failed: $err')));
                    },
                  );
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit Portfolio')),
              const PopupMenuItem(
                  value: 'delete', child: Text('Delete Portfolio')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            context.go('/portfolios/${widget.portfolioId}/add-holding'),
        icon: const Icon(Icons.add),
        label: const Text('Add Holding'),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppTheme.darkBgGradient : null,
        ),
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(portfoliosProvider);
            ref.invalidate(holdingsProvider);
            ref.invalidate(portfolioAnalyticsProvider);
          },
          child: CustomScrollView(
            slivers: [
              // Summary Cards
              SliverPadding(
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                sliver: SliverToBoxAdapter(
                  child: analyticsAsync.when(
                    data: (analytics) {
                      if (analytics == null) return const SizedBox.shrink();
                      final gainLossText =
                          '${analytics.totalGainLoss >= 0 ? '+' : ''}${_currencyFormatter.format(analytics.totalGainLoss)} (${analytics.totalGainLossPct.toStringAsFixed(1)}%)';
                      return ResponsiveGrid(
                        children: [
                          StatCard(
                            label: 'Total Value',
                            value: _currencyFormatter
                                .format(analytics.totalCurrentValue),
                            change: gainLossText,
                            changePositive: analytics.totalGainLoss >= 0,
                            icon: Icons.account_balance_wallet,
                          ),
                          StatCard(
                            label: 'Invested',
                            value: _currencyFormatter
                                .format(analytics.totalInvested),
                            icon: Icons.savings,
                          ),
                          StatCard(
                            label: 'Diversification',
                            value:
                                '${analytics.diversificationScore.toStringAsFixed(0)}/100',
                            change: 'Concentration Score',
                            changePositive:
                                analytics.diversificationScore >= 70,
                            icon: Icons.pie_chart,
                          ),
                          StatCard(
                            label: 'AI Health',
                            value:
                                '${analytics.aiHealthScore.toStringAsFixed(0)}/100',
                            change: 'AI Diagnostics',
                            changePositive: analytics.aiHealthScore >= 80,
                            icon: Icons.health_and_safety,
                          ),
                        ],
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (err, _) => Center(child: Text('Error: $err')),
                  ),
                ),
              ),

              // Sector Allocation Chart
              SliverPadding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
                sliver: SliverToBoxAdapter(
                  child: analyticsAsync.when(
                    data: (analytics) {
                      if (analytics == null ||
                          analytics.sectorAllocation.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Sector Allocation',
                                style: theme.textTheme.titleMedium),
                            const SizedBox(height: AppTheme.spacingMd),
                            SizedBox(
                              height: 180,
                              child: BarChart(
                                BarChartData(
                                  alignment: BarChartAlignment.spaceAround,
                                  maxY: _getMaxAllocation(
                                      analytics.sectorAllocation),
                                  barTouchData: BarTouchData(enabled: true),
                                  titlesData: FlTitlesData(
                                    leftTitles: const AxisTitles(
                                        sideTitles:
                                            SideTitles(showTitles: false)),
                                    topTitles: const AxisTitles(
                                        sideTitles:
                                            SideTitles(showTitles: false)),
                                    rightTitles: const AxisTitles(
                                        sideTitles:
                                            SideTitles(showTitles: false)),
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        getTitlesWidget: (value, meta) {
                                          final sectors = analytics
                                              .sectorAllocation.keys
                                              .toList();
                                          if (value.toInt() < sectors.length) {
                                            final label =
                                                sectors[value.toInt()];
                                            final cleanLabel = label.length > 8
                                                ? label.substring(0, 7) + '..'
                                                : label;
                                            return Padding(
                                              padding:
                                                  const EdgeInsets.only(top: 4),
                                              child: Text(cleanLabel,
                                                  style: const TextStyle(
                                                      fontSize: 9)),
                                            );
                                          }
                                          return const Text('');
                                        },
                                      ),
                                    ),
                                  ),
                                  gridData: const FlGridData(show: false),
                                  borderData: FlBorderData(show: false),
                                  barGroups: _buildBarGroups(
                                      analytics.sectorAllocation),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 200.ms);
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ),
              ),

              // Holdings List Header
              SliverPadding(
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                sliver: SliverToBoxAdapter(
                  child: holdingsAsync.when(
                    data: (list) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Holdings (${list.length})',
                              style: theme.textTheme.titleMedium),
                        ],
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ),
              ),

              // Holdings List
              holdingsAsync.when(
                data: (list) {
                  if (list.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Text(
                              'No holdings in this portfolio. Tap FAB to add.'),
                        ),
                      ),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingMd),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final holding = list[index];
                          return _holdingCard(context, holding, index)
                              .animate()
                              .fadeIn(
                                  delay:
                                      Duration(milliseconds: 300 + index * 80))
                              .slideX(begin: 0.03);
                        },
                        childCount: list.length,
                      ),
                    ),
                  );
                },
                loading: () => const SliverToBoxAdapter(
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (err, _) => SliverToBoxAdapter(
                  child: Center(child: Text('Failed to load holdings: $err')),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        ),
      ),
    );
  }

  double _getMaxAllocation(Map<String, double> allocation) {
    if (allocation.isEmpty) return 100;
    final maxVal =
        allocation.values.fold<double>(0, (max, val) => val > max ? val : max);
    return (maxVal + 10).clamp(0, 100);
  }

  List<BarChartGroupData> _buildBarGroups(Map<String, double> allocation) {
    final colors = [
      const Color(0xFF6C63FF),
      const Color(0xFF00D9A6),
      const Color(0xFFFF6B6B),
      const Color(0xFFFFAB00),
      const Color(0xFF2979FF),
      const Color(0xFF7C4DFF),
    ];
    int index = 0;
    return allocation.entries.map((entry) {
      final color = colors[index % colors.length];
      final group = _barGroup(index, entry.value, color);
      index++;
      return group;
    }).toList();
  }

  BarChartGroupData _barGroup(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 18,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(4),
          ),
        ),
      ],
    );
  }

  Widget _holdingCard(BuildContext context, Holding holding, int index) {
    final theme = Theme.of(context);
    final isPositive = holding.gainLossPct >= 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.go(
          '/portfolios/${widget.portfolioId}/recommendation/${holding.id}',
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Symbol avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    holding.symbol.substring(0, 2),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Title and Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      holding.symbol,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      holding.name,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(128),
                      ),
                    ),
                  ],
                ),
              ),

              // Price and Change
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _currencyFormatter.format(holding.currentValue),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      RecommendationChip(
                          action: holding.gainLossPct > 10 ? 'hold' : 'buy'),
                      const SizedBox(width: 6),
                      Text(
                        '${isPositive ? '+' : ''}${holding.gainLossPct.toStringAsFixed(1)}%',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isPositive
                              ? AppTheme.profitGreen
                              : AppTheme.lossRed,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
