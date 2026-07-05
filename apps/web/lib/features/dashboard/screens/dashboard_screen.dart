import 'dart:math' as math;
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
    final analyticsAsync = ref.watch(portfolioAnalyticsProvider);
    final holdingsAsync = ref.watch(holdingsProvider);
    final doctorAsync = ref.watch(portfolioDoctorProvider);
    final marketOverviewAsync = ref.watch(marketOverviewProvider);

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
            ref.invalidate(marketOverviewProvider);
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
                                  // Navigates or prompts setup
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
                    marketOverviewAsync,
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
    AsyncValue<MarketOverview> marketOverviewAsync,
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

      // Interactive Health Ring & Risk Gauge Meter Row
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
        sliver: SliverToBoxAdapter(
          child: analyticsAsync.when(
            data: (analytics) {
              if (analytics == null) return const SizedBox.shrink();
              return GlassCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    HealthRingWidget(score: analytics.aiHealthScore),
                    Container(
                      height: 100,
                      width: 1,
                      color: theme.colorScheme.onSurface.withAlpha(30),
                    ),
                    RiskGaugeWidget(score: analytics.riskScore),
                  ],
                ),
              ).animate().fadeIn(delay: 100.ms);
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ),
      ),

      const SliverToBoxAdapter(child: SizedBox(height: AppTheme.spacingMd)),

      // Interactive Benchmarking line chart
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
        sliver: SliverToBoxAdapter(
          child: marketOverviewAsync.when(
            data: (marketOverview) {
              return BenchmarkLineChartWidget(
                indexPerformance: marketOverview.indexPerformance,
              ).animate().fadeIn(delay: 200.ms);
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ),
      ),

      const SliverToBoxAdapter(child: SizedBox(height: AppTheme.spacingMd)),

      // Top Winners & Underperformers Widgets
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
        sliver: SliverToBoxAdapter(
          child: holdingsAsync.when(
            data: (holdings) {
              if (holdings.isEmpty) return const SizedBox.shrink();
              return WinnersLosersWidget(holdings: holdings).animate().fadeIn(delay: 250.ms);
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ),
      ),

      const SliverToBoxAdapter(child: SizedBox(height: AppTheme.spacingMd)),

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
              ).animate().fadeIn(delay: 300.ms);
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

      const SliverToBoxAdapter(child: SizedBox(height: AppTheme.spacingMd)),

      // Economic Calendar Timeline Widget
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
        sliver: SliverToBoxAdapter(
          child: marketOverviewAsync.when(
            data: (marketOverview) {
              return EconomicCalendarWidget(
                macroIndicators: marketOverview.macroIndicators,
              ).animate().fadeIn(delay: 450.ms);
            },
            loading: () => const SizedBox.shrink(),
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
              holding.symbol.length >= 2 ? holding.symbol.substring(0, 2) : holding.symbol,
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

/// Circular Health Ring Widget.
class HealthRingWidget extends StatelessWidget {
  final double score;

  const HealthRingWidget({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 90,
              height: 90,
              child: CircularProgressIndicator(
                value: score / 100.0,
                strokeWidth: 10,
                backgroundColor: theme.colorScheme.onSurface.withAlpha(20),
                valueColor: AlwaysStoppedAnimation<Color>(
                  score >= 80 ? AppTheme.profitGreen : (score >= 50 ? Colors.orange : AppTheme.lossRed),
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  score.toStringAsFixed(0),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Health',
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.colorScheme.onSurface.withAlpha(150),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          score >= 80 ? 'EXCELLENT' : (score >= 50 ? 'AVERAGE' : 'NEEDS CARE'),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 11,
            color: score >= 80 ? AppTheme.profitGreen : (score >= 50 ? Colors.orange : AppTheme.lossRed),
          ),
        ),
      ],
    );
  }
}

/// Dynamic Needle-based Risk Gauge.
class RiskGaugeWidget extends StatelessWidget {
  final double score;

  const RiskGaugeWidget({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = _getRiskLabel(score);
    final color = _getRiskColor(score);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 140,
          height: 80,
          child: CustomPaint(
            painter: _RiskGaugePainter(score: score, theme: theme),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const Text(
          'Portfolio Risk',
          style: TextStyle(color: Colors.grey, fontSize: 10),
        ),
      ],
    );
  }

  String _getRiskLabel(double score) {
    if (score < 25) return 'LOW';
    if (score < 50) return 'MODERATE';
    if (score < 75) return 'HIGH';
    return 'EXTREME';
  }

  Color _getRiskColor(double score) {
    if (score < 25) return AppTheme.profitGreen;
    if (score < 50) return AppTheme.infoBlue;
    if (score < 75) return Colors.orange;
    return AppTheme.lossRed;
  }
}

class _RiskGaugePainter extends CustomPainter {
  final double score;
  final ThemeData theme;

  _RiskGaugePainter({required this.score, required this.theme});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2 - 10;

    final rect = Rect.fromCircle(center: center, radius: radius);
    const strokeWidth = 12.0;

    final paintGreen = Paint()
      ..color = AppTheme.profitGreen.withAlpha(180)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final paintBlue = Paint()
      ..color = AppTheme.infoBlue.withAlpha(180)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final paintOrange = Paint()
      ..color = Colors.orange.withAlpha(180)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final paintRed = Paint()
      ..color = AppTheme.lossRed.withAlpha(180)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, math.pi, math.pi / 4, false, paintGreen);
    canvas.drawArc(rect, math.pi + (math.pi / 4), math.pi / 4, false, paintBlue);
    canvas.drawArc(rect, math.pi + (2 * math.pi / 4), math.pi / 4, false, paintOrange);
    canvas.drawArc(rect, math.pi + (3 * math.pi / 4), math.pi / 4, false, paintRed);

    final clamped = score.clamp(0.0, 100.0);
    final angle = math.pi + (clamped / 100.0) * math.pi;

    final needlePaint = Paint()
      ..color = theme.colorScheme.onSurface
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final endX = center.dx + radius * math.cos(angle);
    final endY = center.dy + radius * math.sin(angle);
    canvas.drawLine(center, Offset(endX, endY), needlePaint);

    final pinPaint = Paint()..color = theme.colorScheme.primary;
    canvas.drawCircle(center, 6, pinPaint);
    final pinCenterPaint = Paint()..color = Colors.white;
    canvas.drawCircle(center, 2, pinCenterPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Dual benchmarking line chart.
class BenchmarkLineChartWidget extends StatelessWidget {
  final Map<String, dynamic> indexPerformance;

  const BenchmarkLineChartWidget({super.key, required this.indexPerformance});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final niftyData = indexPerformance['NIFTY50'] ?? {};
    final sensexData = indexPerformance['SENSEX'] ?? {};

    final niftyHistory = niftyData['history'] as List<dynamic>? ?? [];
    final sensexHistory = sensexData['history'] as List<dynamic>? ?? [];

    final niftySpots = _getRelativeSpots(niftyHistory);
    final sensexSpots = _getRelativeSpots(sensexHistory);

    final niftyPct = niftyData['change_pct'] as double? ?? 0.0;
    final sensexPct = sensexData['change_pct'] as double? ?? 0.0;

    final hasData = niftySpots.isNotEmpty || sensexSpots.isNotEmpty;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Benchmark Comparison', style: theme.textTheme.titleMedium),
              const Text(
                '5-Day Relative % Performance',
                style: TextStyle(color: Colors.grey, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingSm),
          Row(
            children: [
              _legendItem('NIFTY 50 ($niftyPct%)', Colors.blue),
              const SizedBox(width: AppTheme.spacingMd),
              _legendItem('SENSEX ($sensexPct%)', Colors.purple),
            ],
          ),
          const SizedBox(height: AppTheme.spacingLg),
          if (!hasData)
            const SizedBox(
              height: 160,
              child: Center(
                child: Text('Historical index feeds initializing...'),
              ),
            )
          else
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    if (niftySpots.isNotEmpty)
                      LineChartBarData(
                        spots: niftySpots,
                        isCurved: true,
                        color: Colors.blue,
                        barWidth: 3.5,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: Colors.blue.withAlpha(20),
                        ),
                      ),
                    if (sensexSpots.isNotEmpty)
                      LineChartBarData(
                        spots: sensexSpots,
                        isCurved: true,
                        color: Colors.purple,
                        barWidth: 3.5,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: Colors.purple.withAlpha(20),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<FlSpot> _getRelativeSpots(List<dynamic> history) {
    if (history.isEmpty) return [];
    final firstVal = (history.first as num).toDouble();
    if (firstVal == 0) return [];
    final spots = <FlSpot>[];
    for (int i = 0; i < history.length; i++) {
      final val = (history[i] as num).toDouble();
      final pctChange = ((val - firstVal) / firstVal) * 100;
      spots.add(FlSpot(i.toDouble(), pctChange));
    }
    return spots;
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

/// Winners & Underperformers widget.
class WinnersLosersWidget extends StatelessWidget {
  final List<Holding> holdings;

  const WinnersLosersWidget({super.key, required this.holdings});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (holdings.isEmpty) return const SizedBox.shrink();

    final sorted = List<Holding>.from(holdings);
    sorted.sort((a, b) => b.gainLossPct.compareTo(a.gainLossPct));

    final winner = sorted.first;
    final loser = sorted.last;
    final hasMultiple = sorted.length > 1;

    return Row(
      children: [
        Expanded(
          child: GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Top Winner', style: TextStyle(color: Colors.grey, fontSize: 11)),
                    Icon(Icons.arrow_upward, color: AppTheme.profitGreen, size: 16),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  winner.symbol,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  '+${winner.gainLossPct.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    color: AppTheme.profitGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppTheme.spacingMd),
        Expanded(
          child: GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Top Underperformer', style: TextStyle(color: Colors.grey, fontSize: 11)),
                    Icon(
                      hasMultiple ? Icons.arrow_downward : Icons.arrow_upward,
                      color: hasMultiple ? AppTheme.lossRed : AppTheme.profitGreen,
                      size: 16,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  hasMultiple ? loser.symbol : '-',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  hasMultiple
                      ? '${loser.gainLossPct >= 0 ? "+" : ""}${loser.gainLossPct.toStringAsFixed(1)}%'
                      : 'N/A',
                  style: TextStyle(
                    color: hasMultiple
                        ? (loser.gainLossPct >= 0 ? AppTheme.profitGreen : AppTheme.lossRed)
                        : Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Economic & Corporate actions calendar list.
class EconomicCalendarWidget extends StatelessWidget {
  final Map<String, double> macroIndicators;

  const EconomicCalendarWidget({super.key, required this.macroIndicators});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final events = [
      _CalendarEvent(
        title: 'RBI Monetary Policy Meet',
        date: 'Upcoming Decision',
        description: 'Repo Rate projected to remain at ${macroIndicators['repo_rate']?.toStringAsFixed(2) ?? '6.50'}%',
        icon: Icons.account_balance,
        iconColor: Colors.blue,
      ),
      _CalendarEvent(
        title: 'CPI Inflation Index Release',
        date: 'Monthly Update',
        description: 'Current benchmark inflation rate reported at ${macroIndicators['inflation_rate']?.toStringAsFixed(2) ?? '4.80'}%',
        icon: Icons.trending_up,
        iconColor: Colors.redAccent,
      ),
      _CalendarEvent(
        title: 'India GDP Growth Outlook',
        date: 'Quarterly Forecast',
        description: 'World Bank economic growth projection stable at ${macroIndicators['gdp_growth']?.toStringAsFixed(2) ?? '6.20'}%',
        icon: Icons.bar_chart,
        iconColor: Colors.green,
      ),
    ];

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Economic & Corporate Calendar', style: theme.textTheme.titleMedium),
              const Icon(Icons.calendar_month, color: Colors.grey, size: 20),
            ],
          ),
          const SizedBox(height: AppTheme.spacingMd),
          ...events.asMap().entries.map((entry) {
            final ev = entry.value;
            final isLast = entry.key == events.length - 1;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: ev.iconColor.withAlpha(20),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(ev.icon, color: ev.iconColor, size: 16),
                    ),
                    if (!isLast)
                      Container(
                        width: 2,
                        height: 40,
                        color: theme.colorScheme.onSurface.withAlpha(25),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            ev.title,
                            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            ev.date,
                            style: TextStyle(
                              fontSize: 10,
                              color: theme.colorScheme.onSurface.withAlpha(140),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ev.description,
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface.withAlpha(170),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }
}

class _CalendarEvent {
  final String title;
  final String date;
  final String description;
  final IconData icon;
  final Color iconColor;

  _CalendarEvent({
    required this.title,
    required this.date,
    required this.description,
    required this.icon,
    required this.iconColor,
  });
}
