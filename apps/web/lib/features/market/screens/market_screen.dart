import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/portfolio_providers.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';

/// Market intelligence screen showing live news, sector rankings, and macro calendars.
/// Auto-refreshes every 30 seconds.
class MarketScreen extends ConsumerStatefulWidget {
  const MarketScreen({super.key});

  @override
  ConsumerState<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends ConsumerState<MarketScreen> {
  Timer? _refreshTimer;
  DateTime _lastRefreshed = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Auto-refresh market data every 30 seconds.
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        ref.invalidate(marketOverviewProvider);
        setState(() => _lastRefreshed = DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  String get _lastRefreshedLabel {
    final fmt = DateFormat('HH:mm:ss');
    return 'Updated ${fmt.format(_lastRefreshed)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final marketAsync = ref.watch(marketOverviewProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Market Intelligence'),
              Text(
                _lastRefreshedLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh now',
              onPressed: () {
                ref.invalidate(marketOverviewProvider);
                setState(() => _lastRefreshed = DateTime.now());
              },
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'News', icon: Icon(Icons.newspaper, size: 18)),
              Tab(text: 'Sectors', icon: Icon(Icons.category, size: 18)),
              Tab(text: 'Calendar', icon: Icon(Icons.calendar_month, size: 18)),
            ],
          ),
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: isDark ? AppTheme.darkBgGradient : null,
          ),
          child: marketAsync.when(
            data: (overview) {
              return TabBarView(
                children: [
                  _buildNewsTab(context, overview),
                  _buildSectorsTab(context, overview),
                  _buildCalendarTab(context, overview),
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
                    const Icon(Icons.error_outline,
                        size: 64, color: AppTheme.lossRed),
                    const SizedBox(height: 16),
                    Text('Failed loading market feeds',
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(err.toString(),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        ref.invalidate(marketOverviewProvider);
                        setState(() => _lastRefreshed = DateTime.now());
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNewsTab(BuildContext context, MarketOverview overview) {
    final theme = Theme.of(context);
    final newsList = overview.news;

    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      itemCount: newsList.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          // Render Live Index Bar at the top of the news feed
          return _buildIndexHeader(context, overview);
        }

        final news = newsList[index - 1];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {},
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _sentimentColor(news.sentiment).withAlpha(26),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          news.sentiment.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _sentimentColor(news.sentiment),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        news.source,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withAlpha(128),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        news.publishedAt != null
                            ? '${DateTime.now().difference(news.publishedAt!).inHours}h ago'
                            : 'Just now',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withAlpha(100),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    news.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    news.summary,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(153),
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (news.sectors.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      children: news.sectors
                          .map((s) => Chip(
                                label: Text(s,
                                    style: const TextStyle(fontSize: 10)),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                padding: EdgeInsets.zero,
                                labelPadding:
                                    const EdgeInsets.symmetric(horizontal: 6),
                                visualDensity: VisualDensity.compact,
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        )
            .animate()
            .fadeIn(delay: Duration(milliseconds: index * 100))
            .slideY(begin: 0.03);
      },
    );
  }

  Widget _buildIndexHeader(BuildContext context, MarketOverview overview) {
    final indices = overview.indexPerformance;

    return Container(
      height: 90,
      margin: const EdgeInsets.only(bottom: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // Nifty 50 widget
          if (indices.containsKey('NIFTY50'))
            _indexCard(
              context,
              'NIFTY 50',
              indices['NIFTY50']['price']?.toString() ?? '0.0',
              (indices['NIFTY50']['change_pct'] as num?)?.toDouble() ?? 0.0,
            ),
          // Sensex widget
          if (indices.containsKey('SENSEX'))
            _indexCard(
              context,
              'SENSEX',
              indices['SENSEX']['price']?.toString() ?? '0.0',
              (indices['SENSEX']['change_pct'] as num?)?.toDouble() ?? 0.0,
            ),
          // CPI Inflation
          _macroCard(
            context,
            'Inflation (CPI)',
            '${overview.macroIndicators['inflation_rate']?.toStringAsFixed(1) ?? '4.8'}%',
            Icons.trending_down,
            Colors.blueAccent,
          ),
          // GDP Growth
          _macroCard(
            context,
            'GDP Growth',
            '+${overview.macroIndicators['gdp_growth']?.toStringAsFixed(1) ?? '6.2'}%',
            Icons.bolt,
            Colors.amber,
          ),
          // Repo Rate
          _macroCard(
            context,
            'RBI Repo Rate',
            '${overview.macroIndicators['repo_rate']?.toStringAsFixed(2) ?? '6.50'}%',
            Icons.account_balance,
            Colors.teal,
          ),
        ],
      ),
    );
  }

  Widget _indexCard(
      BuildContext context, String name, String price, double changePct) {
    final theme = Theme.of(context);
    final isPositive = changePct >= 0;
    final color = isPositive ? AppTheme.profitGreen : AppTheme.lossRed;

    return Card(
      margin: const EdgeInsets.only(right: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(name,
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(price,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(width: 8),
                Text(
                  '${isPositive ? "+" : ""}${changePct.toStringAsFixed(2)}%',
                  style: TextStyle(
                      color: color, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _macroCard(BuildContext context, String title, String value,
      IconData icon, Color color) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(right: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withAlpha(26),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.grey, fontSize: 10)),
                Text(value,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectorsTab(BuildContext context, MarketOverview overview) {
    final theme = Theme.of(context);
    final sectorRankings = overview.sectorRankings;

    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      itemCount: sectorRankings.length,
      itemBuilder: (context, index) {
        final sector = sectorRankings[index];
        final perf = sector.performance1d;
        final isPositive = perf >= 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: (isPositive ? AppTheme.profitGreen : AppTheme.lossRed)
                    .withAlpha(26),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: isPositive ? AppTheme.profitGreen : AppTheme.lossRed,
                  ),
                ),
              ),
            ),
            title: Text(sector.sector, style: theme.textTheme.titleSmall),
            subtitle: Row(
              children: [
                _perfChip('1D', sector.performance1d),
                const SizedBox(width: 8),
                _perfChip('1W', sector.performance1w),
                const SizedBox(width: 8),
                _perfChip('1M', sector.performance1m),
              ],
            ),
            trailing: Icon(
              isPositive ? Icons.trending_up : Icons.trending_down,
              color: isPositive ? AppTheme.profitGreen : AppTheme.lossRed,
            ),
          ),
        ).animate().fadeIn(delay: Duration(milliseconds: index * 80));
      },
    );
  }

  Widget _buildCalendarTab(BuildContext context, MarketOverview overview) {
    final repoRateStr =
        '${overview.macroIndicators['repo_rate']?.toStringAsFixed(2) ?? '6.50'}%';
    final inflationStr =
        '${overview.macroIndicators['inflation_rate']?.toStringAsFixed(2) ?? '4.80'}%';

    return ListView(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      children: [
        _calendarSection(context, 'Upcoming Earnings', Icons.bar_chart, [
          {'date': 'Jul 10', 'event': 'TCS Q1 Results', 'est': 'EPS Est: ₹65'},
          {
            'date': 'Jul 12',
            'event': 'Infosys Q1 Results',
            'est': 'EPS Est: ₹42'
          },
          {
            'date': 'Jul 15',
            'event': 'HDFC Bank Q1 Results',
            'est': 'EPS Est: ₹22'
          },
          {
            'date': 'Jul 18',
            'event': 'Reliance Q1 Results',
            'est': 'EPS Est: ₹38'
          },
        ]),
        const SizedBox(height: AppTheme.spacingMd),
        _calendarSection(
            context, 'Economic Events (Live Indicators)', Icons.public, [
          {
            'date': 'Jul 5',
            'event': 'RBI Policy Rate Update',
            'est': 'Current Repo Rate: $repoRateStr'
          },
          {
            'date': 'Jul 8',
            'event': 'India CPI Inflation (WB)',
            'est': 'World Bank Stats: $inflationStr'
          },
          {
            'date': 'Jul 12',
            'event': 'US Federal Funds Rate',
            'est': 'Fed Target: 5.25% - 5.50%'
          },
          {
            'date': 'Jul 25',
            'event': 'India Union Budget',
            'est': 'Key budget event allocation details'
          },
        ]),
        const SizedBox(height: AppTheme.spacingMd),
        _calendarSection(context, 'Corporate Actions', Icons.business_center, [
          {
            'date': 'Jul 6',
            'event': 'INFY: Dividend ₹18/share',
            'est': 'Ex-date payout schedule'
          },
          {
            'date': 'Jul 10',
            'event': 'ITC: Dividend ₹6.75/share',
            'est': 'Ex-date payout schedule'
          },
          {
            'date': 'Jul 15',
            'event': 'Nykaa: Stock Split 1:5',
            'est': 'Record allocation date'
          },
        ]),
      ],
    );
  }

  Widget _calendarSection(BuildContext context, String title, IconData icon,
      List<Map<String, String>> events) {
    final theme = Theme.of(context);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(title,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          ...events.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withAlpha(77),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(e['date']!,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600, fontSize: 10)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e['event']!,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(fontWeight: FontWeight.w600)),
                          Text(e['est']!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color:
                                    theme.colorScheme.onSurface.withAlpha(128),
                                fontSize: 11,
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _perfChip(String label, double value) {
    final isPositive = value >= 0;
    return Text(
      '$label: ${isPositive ? "+" : ""}${value.toStringAsFixed(1)}%',
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: isPositive ? AppTheme.profitGreen : AppTheme.lossRed,
      ),
    );
  }

  Color _sentimentColor(String sentiment) {
    switch (sentiment) {
      case 'positive':
        return AppTheme.profitGreen;
      case 'negative':
        return AppTheme.lossRed;
      default:
        return AppTheme.warningAmber;
    }
  }
}
