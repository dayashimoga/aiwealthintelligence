import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';

/// Main dashboard screen showing portfolio overview, analytics, and AI insights.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppTheme.darkBgGradient : null,
        ),
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
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () {},
                ),
                const SizedBox(width: 8),
              ],
            ),

            // Portfolio Summary Cards
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
                      label: 'Today\'s P&L',
                      value: '+₹12,450',
                      change: '+0.51%',
                      changePositive: true,
                      icon: Icons.trending_up,
                    ),
                    StatCard(
                      label: 'AI Health Score',
                      value: '78/100',
                      change: 'Good',
                      changePositive: true,
                      icon: Icons.health_and_safety,
                    ),
                    StatCard(
                      label: 'Total XIRR',
                      value: '18.5%',
                      change: 'vs 12% Nifty',
                      changePositive: true,
                      icon: Icons.show_chart,
                    ),
                  ],
                ),
              ),
            ),

            // Asset Allocation Chart
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
              sliver: SliverToBoxAdapter(
                child: GlassCard(
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
                                  sections: [
                                    PieChartSectionData(
                                      value: 45,
                                      title: '45%',
                                      color: const Color(0xFF6C63FF),
                                      radius: 60,
                                      titleStyle: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    PieChartSectionData(
                                      value: 25,
                                      title: '25%',
                                      color: const Color(0xFF00D9A6),
                                      radius: 55,
                                      titleStyle: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    PieChartSectionData(
                                      value: 15,
                                      title: '15%',
                                      color: const Color(0xFFFF6B6B),
                                      radius: 50,
                                      titleStyle: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    PieChartSectionData(
                                      value: 10,
                                      title: '10%',
                                      color: const Color(0xFFFFAB00),
                                      radius: 45,
                                      titleStyle: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    PieChartSectionData(
                                      value: 5,
                                      title: '5%',
                                      color: const Color(0xFF2979FF),
                                      radius: 40,
                                      titleStyle: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: AppTheme.spacingMd),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _legendItem('Stocks', const Color(0xFF6C63FF)),
                                _legendItem('Mutual Funds', const Color(0xFF00D9A6)),
                                _legendItem('Gold', const Color(0xFFFF6B6B)),
                                _legendItem('Bonds', const Color(0xFFFFAB00)),
                                _legendItem('Cash', const Color(0xFF2979FF)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 200.ms),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: AppTheme.spacingMd)),

            // AI Insights
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
              sliver: SliverToBoxAdapter(
                child: GlassCard(
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
                            child: const Icon(Icons.auto_awesome,
                                color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'AI Insights',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.spacingMd),
                      _insightTile(
                        context,
                        Icons.warning_amber,
                        AppTheme.warningAmber,
                        'Sector Concentration',
                        '42% of portfolio in IT sector. Consider diversifying.',
                      ),
                      const Divider(height: 24),
                      _insightTile(
                        context,
                        Icons.swap_horiz,
                        AppTheme.infoBlue,
                        'Overlap Detected',
                        '3 mutual funds have >60% common holdings.',
                      ),
                      const Divider(height: 24),
                      _insightTile(
                        context,
                        Icons.trending_up,
                        AppTheme.profitGreen,
                        'Opportunity',
                        'HDFC Bank is near 52-week low. AI rating: Strong Buy.',
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 400.ms),
              ),
            ),

            // Top Holdings
            SliverPadding(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Top Holdings',
                            style: theme.textTheme.titleMedium),
                        TextButton(
                          onPressed: () {},
                          child: const Text('View All'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingSm),
                    ..._sampleHoldings.asMap().entries.map(
                          (entry) => _holdingTile(context, entry.value)
                              .animate()
                              .fadeIn(delay: Duration(milliseconds: 500 + entry.key * 100))
                              .slideX(begin: 0.05),
                        ),
                  ],
                ),
              ),
            ),

            // Bottom padding
            const SliverToBoxAdapter(
                child: SizedBox(height: AppTheme.spacingXxl)),
          ],
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
              Text(title,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
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

  static final _sampleHoldings = [
    {
      'symbol': 'RELIANCE',
      'name': 'Reliance Industries',
      'value': '₹2,80,000',
      'change': '+12.0%',
      'positive': true,
      'action': 'hold',
    },
    {
      'symbol': 'TCS',
      'name': 'Tata Consultancy',
      'value': '₹1,90,000',
      'change': '+8.5%',
      'positive': true,
      'action': 'buy',
    },
    {
      'symbol': 'HDFCBANK',
      'name': 'HDFC Bank',
      'value': '₹1,65,000',
      'change': '-2.3%',
      'positive': false,
      'action': 'strong_buy',
    },
    {
      'symbol': 'INFY',
      'name': 'Infosys',
      'value': '₹1,40,000',
      'change': '+5.7%',
      'positive': true,
      'action': 'hold',
    },
  ];

  Widget _holdingTile(BuildContext context, Map<String, dynamic> holding) {
    final theme = Theme.of(context);
    final isPositive = holding['positive'] as bool;

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
              (holding['symbol'] as String).substring(0, 2),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ),
        title: Text(
          holding['symbol'] as String,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          holding['name'] as String,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withAlpha(128),
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              holding['value'] as String,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                RecommendationChip(action: holding['action'] as String),
                const SizedBox(width: 6),
                Text(
                  holding['change'] as String,
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
}
