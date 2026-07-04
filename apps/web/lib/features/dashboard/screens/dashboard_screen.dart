import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/models/models.dart';
import '../../../core/providers/portfolio_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';

/// Main dashboard screen showing portfolio overview, analytics, and AI insights.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final _currencyFormatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final portfoliosAsync = ref.watch(portfoliosProvider);
    final selectedId = ref.watch(selectedPortfolioIdProvider);
    final selectedPortfolio = ref.watch(selectedPortfolioProvider);
    final analyticsAsync = ref.watch(portfolioAnalyticsProvider);
    final holdingsAsync = ref.watch(holdingsProvider);
    final doctorAsync = ref.watch(portfolioDoctorProvider);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppTheme.darkBgGradient : null,
        ),
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(portfoliosProvider);
            ref.invalidate(portfolioAnalyticsProvider);
            ref.invalidate(holdingsProvider);
            ref.invalidate(portfolioDoctorProvider);
          },
          child: CustomScrollView(
            slivers: [
              // App Bar
              SliverAppBar(
                floating: true,
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Good ${_getGreeting()}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(153),
                      ),
                    ),
                    const Text('Dashboard'),
                  ],
                ),
                actions: [
                  portfoliosAsync.when(
                    data: (list) {
                      if (list.isEmpty) return const SizedBox.shrink();
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedId,
                            icon: const Icon(Icons.keyboard_arrow_down),
                            items: list.map((p) {
                              return DropdownMenuItem<String>(
                                value: p.id,
                                child: Text(p.name),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                ref.read(selectedPortfolioIdProvider.notifier).state = val;
                              }
                            },
                          ),
                        ),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: () {},
                  ),
                  const SizedBox(width: 8),
                ],
              ),

              // Empty State Handling
              ...portfoliosAsync.when(
                data: (list) {
                  if (list.isEmpty) {
                    return [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Padding(
                          padding: const EdgeInsets.all(AppTheme.spacingLg),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.account_balance_wallet_outlined,
                                size: 80,
                                color: theme.colorScheme.primary.withAlpha(128),
                              ),
                              const SizedBox(height: AppTheme.spacingMd),
                              Text(
                                'No Portfolios Found',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: AppTheme.spacingSm),
                              Text(
                                'Create a portfolio or upload a CAS statement to get started.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface.withAlpha(153),
                                ),
                              ),
                              const SizedBox(height: AppTheme.spacingLg),
                              ElevatedButton.icon(
                                onPressed: () {
                                  // Prompt or navigate to import screen
                                },
                                icon: const Icon(Icons.add),
                                label: const Text('Create Portfolio'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ];
                  }
                  return _buildDashboardContent(
                    theme,
                    isDark,
                    analyticsAsync,
                    holdingsAsync,
                    doctorAsync,
                  );
                },
                loading: () => [_buildLoadingSliver(theme)],
                error: (err, _) => [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppTheme.spacingLg),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 60, color: Colors.red),
                            const SizedBox(height: AppTheme.spacingMd),
                            Text('Failed to load dashboard', style: theme.textTheme.titleMedium),
                            const SizedBox(height: AppTheme.spacingSm),
                            Text(err.toString(), textAlign: TextAlign.center),
                            const SizedBox(height: AppTheme.spacingMd),
                            ElevatedButton(
                              onPressed: () => ref.invalidate(portfoliosProvider),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildDashboardContent(
    ThemeData theme,
    bool isDark,
    AsyncValue<PortfolioAnalytics?> analyticsAsync,
    AsyncValue<List<Holding>> holdingsAsync,
    AsyncValue<PortfolioDoctor?> doctorAsync,
  ) {
    return [
      // Portfolio Summary Cards
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
                    value: _currencyFormatter.format(analytics.totalCurrentValue),
                    change: gainLossText,
                    changePositive: analytics.totalGainLoss >= 0,
                    icon: Icons.account_balance_wallet,
                  ),
                  StatCard(
                    label: 'Invested Value',
                    value: _currencyFormatter.format(analytics.totalInvested),
                    change: 'Total Invested',
                    changePositive: true,
                    icon: Icons.monetization_on,
                  ),
                  StatCard(
                    label: 'AI Health Score',
                    value: '${analytics.aiHealthScore.toStringAsFixed(0)}/100',
                    change: analytics.aiHealthScore >= 80 ? 'Good' : 'Needs Review',
                    changePositive: analytics.aiHealthScore >= 80,
                    icon: Icons.health_and_safety,
                  ),
                  StatCard(
                    label: 'Holdings count',
                    value: '${analytics.holdingCount}',
                    change: 'Active Positions',
                    changePositive: true,
                    icon: Icons.show_chart,
                  ),
                ],
              );
            },
            loading: () => _buildShimmerGrid(),
            error: (err, _) => Center(child: Text('Error: $err')),
          ),
        ),
      ),

      // Asset Allocation Chart
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
        sliver: SliverToBoxAdapter(
          child: analyticsAsync.when(
            data: (analytics) {
              if (analytics == null || analytics.assetAllocation.isEmpty) {
                return const SizedBox.shrink();
              }
              return GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Asset Allocation',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppTheme.spacingMd),
                    SizedBox(
                      height: 200,
                      child: Row(
                        children: [
                          Expanded(
                            child: PieChart(
                              PieChartData(
                                sectionsSpace: 2,
                                centerSpaceRadius: 40,
                                sections: _buildChartSections(analytics.assetAllocation),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppTheme.spacingMd),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: _buildChartLegend(analytics.assetAllocation),
                          ),
                        ],
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

      const SliverToBoxAdapter(child: SizedBox(height: AppTheme.spacingMd)),

      // AI Insights from Portfolio Doctor
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
        sliver: SliverToBoxAdapter(
          child: doctorAsync.when(
            data: (doctor) {
              if (doctor == null || doctor.issues.isEmpty) {
                return GlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spacingMd),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline, color: Colors.green, size: 28),
                        const SizedBox(width: 12),
                        Text(
                          'No portfolio issues detected! Healthy asset structure.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                );
              }
              return GlassCard(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF1A1040), const Color(0xFF0D0D1A)]
                      : [const Color(0xFFF3E5F5), const Color(0xFFE8EAF6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'AI Copilot Diagnostics',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingMd),
                    ...doctor.issues.take(3).map((issue) {
                      final isHigh = issue.severity.toLowerCase() == 'high';
                      return Column(
                        children: [
                          _insightTile(
                            context,
                            isHigh ? Icons.warning_amber : Icons.info_outline,
                            isHigh ? AppTheme.warningAmber : AppTheme.infoBlue,
                            issue.title,
                            issue.description,
                          ),
                          const Divider(height: 24),
                        ],
                      );
                    }),
                  ],
                ),
              ).animate().fadeIn(delay: 400.ms);
            },
            loading: () => _buildShimmerInsights(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ),
      ),

      // Top Holdings
      SliverPadding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        sliver: SliverToBoxAdapter(
          child: holdingsAsync.when(
            data: (holdings) {
              if (holdings.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Holdings Positions', style: theme.textTheme.titleMedium),
                      TextButton(
                        onPressed: () {},
                        child: const Text('View All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingSm),
                  ...holdings.take(5).toList().asMap().entries.map(
                        (entry) => _holdingTile(context, entry.value)
                            .animate()
                            .fadeIn(delay: Duration(milliseconds: 500 + entry.key * 100))
                            .slideX(begin: 0.05),
                      ),
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ),
      ),

      // Bottom padding
      const SliverToBoxAdapter(child: SizedBox(height: AppTheme.spacingXxl)),
    ];
  }

  List<PieChartSectionData> _buildChartSections(Map<String, double> allocation) {
    final colors = [
      const Color(0xFF6C63FF),
      const Color(0xFF00D9A6),
      const Color(0xFFFF6B6B),
      const Color(0xFFFFAB00),
      const Color(0xFF2979FF),
    ];
    int index = 0;
    return allocation.entries.map((entry) {
      final color = colors[index % colors.length];
      index++;
      return PieChartSectionData(
        value: entry.value,
        title: '${entry.value.toStringAsFixed(0)}%',
        color: color,
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  List<Widget> _buildChartLegend(Map<String, double> allocation) {
    final colors = [
      const Color(0xFF6C63FF),
      const Color(0xFF00D9A6),
      const Color(0xFFFF6B6B),
      const Color(0xFFFFAB00),
      const Color(0xFF2979FF),
    ];
    int index = 0;
    return allocation.entries.map((entry) {
      final color = colors[index % colors.length];
      index++;
      final formattedLabel = entry.key.toUpperCase();
      return _legendItem(formattedLabel, color);
    }).toList();
  }

  Widget _legendItem(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _insightTile(
    BuildContext context,
    IconData icon,
    Color color,
    String title,
    String description,
  ) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withAlpha(26),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(153),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _holdingTile(BuildContext context, Holding holding) {
    final theme = Theme.of(context);
    final isPositive = holding.gainLossPct >= 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withAlpha(77),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              holding.symbol.substring(0, 2),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ),
        title: Text(
          holding.symbol,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          holding.name,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withAlpha(128),
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _currencyFormatter.format(holding.currentValue),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                RecommendationChip(action: holding.gainLossPct > 10 ? 'hold' : 'buy'),
                const SizedBox(width: 6),
                Text(
                  '${isPositive ? '+' : ''}${holding.gainLossPct.toStringAsFixed(1)}%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isPositive ? AppTheme.profitGreen : AppTheme.lossRed,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingSliver(ThemeData theme) {
    return SliverFillRemaining(
      child: Center(
        child: CircularProgressIndicator(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildShimmerGrid() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade800,
      highlightColor: Colors.grey.shade700,
      child: ResponsiveGrid(
        children: List.generate(
          4,
          (index) => Container(
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerInsights() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade800,
      highlightColor: Colors.grey.shade700,
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning ☀️';
    if (hour < 17) return 'Afternoon 🌤️';
    return 'Evening 🌙';
  }
}
