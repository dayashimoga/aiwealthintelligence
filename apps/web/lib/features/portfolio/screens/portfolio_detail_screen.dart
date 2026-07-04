import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';

/// Portfolio detail screen showing holdings, analytics, and AI insights.
class PortfolioDetailScreen extends StatelessWidget {
  const PortfolioDetailScreen({super.key, required this.portfolioId});

  final String portfolioId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Growth Portfolio'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload_outlined),
            tooltip: 'Import CSV',
            onPressed: () {},
          ),
          PopupMenuButton<String>(
            onSelected: (value) {},
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit Portfolio')),
              const PopupMenuItem(value: 'export', child: Text('Export CSV')),
              const PopupMenuItem(value: 'analyze', child: Text('AI Analysis')),
              const PopupMenuItem(value: 'stress', child: Text('Stress Test')),
              const PopupMenuItem(value: 'delete', child: Text('Delete Portfolio')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/portfolios/$portfolioId/add-holding'),
        icon: const Icon(Icons.add),
        label: const Text('Add Holding'),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppTheme.darkBgGradient : null,
        ),
        child: CustomScrollView(
          slivers: [
            // Summary Cards
            SliverPadding(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              sliver: SliverToBoxAdapter(
                child: ResponsiveGrid(
                  children: [
                    StatCard(
                      label: 'Total Value',
                      value: '₹24,50,000',
                      change: '+₹3,20,000 (15.0%)',
                      changePositive: true,
                      icon: Icons.account_balance_wallet,
                    ),
                    StatCard(
                      label: 'Invested',
                      value: '₹21,30,000',
                      icon: Icons.savings,
                    ),
                    StatCard(
                      label: 'XIRR',
                      value: '18.5%',
                      change: 'vs 12% benchmark',
                      changePositive: true,
                      icon: Icons.analytics,
                    ),
                    StatCard(
                      label: 'AI Health',
                      value: '78/100',
                      change: '3 improvements suggested',
                      changePositive: true,
                      icon: Icons.health_and_safety,
                    ),
                  ],
                ),
              ),
            ),

            // Sector Allocation Chart
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
              sliver: SliverToBoxAdapter(
                child: GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sector Allocation', style: theme.textTheme.titleMedium),
                      const SizedBox(height: AppTheme.spacingMd),
                      SizedBox(
                        height: 180,
                        child: BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: 50,
                            barTouchData: BarTouchData(enabled: true),
                            titlesData: FlTitlesData(
                              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    final labels = ['IT', 'Finance', 'Energy', 'Pharma', 'Auto', 'FMCG'];
                                    if (value.toInt() < labels.length) {
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(labels[value.toInt()],
                                            style: const TextStyle(fontSize: 10)),
                                      );
                                    }
                                    return const Text('');
                                  },
                                ),
                              ),
                            ),
                            gridData: const FlGridData(show: false),
                            borderData: FlBorderData(show: false),
                            barGroups: [
                              _barGroup(0, 42, const Color(0xFF6C63FF)),
                              _barGroup(1, 25, const Color(0xFF00D9A6)),
                              _barGroup(2, 15, const Color(0xFFFF6B6B)),
                              _barGroup(3, 8, const Color(0xFFFFAB00)),
                              _barGroup(4, 6, const Color(0xFF2979FF)),
                              _barGroup(5, 4, const Color(0xFF7C4DFF)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 200.ms),
              ),
            ),

            // Holdings List Header
            SliverPadding(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              sliver: SliverToBoxAdapter(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Holdings (12)', style: theme.textTheme.titleMedium),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'all', label: Text('All')),
                        ButtonSegment(value: 'stocks', label: Text('Stocks')),
                        ButtonSegment(value: 'mf', label: Text('MF')),
                      ],
                      selected: const {'all'},
                      onSelectionChanged: (v) {},
                      style: ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        textStyle: WidgetStatePropertyAll(
                          theme.textTheme.bodySmall,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Holdings List
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final holding = _holdings[index];
                    return _holdingCard(context, holding, index)
                        .animate()
                        .fadeIn(delay: Duration(milliseconds: 300 + index * 80))
                        .slideX(begin: 0.03);
                  },
                  childCount: _holdings.length,
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }

  BarChartGroupData _barGroup(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 20,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(4),
          ),
        ),
      ],
    );
  }

  Widget _holdingCard(BuildContext context, Map<String, dynamic> holding, int index) {
    final theme = Theme.of(context);
    final isPositive = (holding['gainPct'] as double) >= 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.go(
          '/portfolios/$portfolioId/recommendation/${holding['id']}',
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
                    (holding['symbol'] as String).substring(0, 2),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(holding['symbol'] as String,
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        Text(
                          '₹${_formatNumber(holding['value'] as double)}',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${holding['qty']} @ ₹${holding['avgPrice']}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withAlpha(128),
                          ),
                        ),
                        Row(
                          children: [
                            RecommendationChip(
                              action: holding['action'] as String,
                              confidence: holding['confidence'] as double,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${isPositive ? "+" : ""}${(holding['gainPct'] as double).toStringAsFixed(1)}%',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isPositive
                                    ? AppTheme.profitGreen
                                    : AppTheme.lossRed,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
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

  String _formatNumber(double num) {
    if (num >= 100000) {
      return '${(num / 100000).toStringAsFixed(2)}L';
    } else if (num >= 1000) {
      return '${(num / 1000).toStringAsFixed(1)}K';
    }
    return num.toStringAsFixed(0);
  }

  static final _holdings = [
    {'id': 'h1', 'symbol': 'RELIANCE', 'qty': 10, 'avgPrice': '2500', 'value': 28000.0, 'gainPct': 12.0, 'action': 'hold', 'confidence': 72.0},
    {'id': 'h2', 'symbol': 'TCS', 'qty': 50, 'avgPrice': '3500', 'value': 190000.0, 'gainPct': 8.5, 'action': 'buy', 'confidence': 81.0},
    {'id': 'h3', 'symbol': 'HDFCBANK', 'qty': 100, 'avgPrice': '1600', 'value': 165000.0, 'gainPct': -2.3, 'action': 'strong_buy', 'confidence': 88.0},
    {'id': 'h4', 'symbol': 'INFY', 'qty': 80, 'avgPrice': '1500', 'value': 140000.0, 'gainPct': 5.7, 'action': 'hold', 'confidence': 65.0},
    {'id': 'h5', 'symbol': 'ICICIBANK', 'qty': 60, 'avgPrice': '900', 'value': 66000.0, 'gainPct': 18.2, 'action': 'buy', 'confidence': 77.0},
    {'id': 'h6', 'symbol': 'BHARTIARTL', 'qty': 30, 'avgPrice': '800', 'value': 30000.0, 'gainPct': 25.0, 'action': 'hold', 'confidence': 70.0},
    {'id': 'h7', 'symbol': 'SBIN', 'qty': 150, 'avgPrice': '550', 'value': 90000.0, 'gainPct': 9.1, 'action': 'reduce', 'confidence': 62.0},
    {'id': 'h8', 'symbol': 'WIPRO', 'qty': 200, 'avgPrice': '400', 'value': 80000.0, 'gainPct': -5.0, 'action': 'sell', 'confidence': 74.0},
  ];
}
