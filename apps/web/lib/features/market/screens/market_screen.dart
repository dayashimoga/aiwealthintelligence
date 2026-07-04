import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';

/// Market intelligence screen showing news, sector rankings, and market overview.
class MarketScreen extends StatelessWidget {
  const MarketScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Market Intelligence'),
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
          child: TabBarView(
            children: [
              _buildNewsTab(context),
              _buildSectorsTab(context),
              _buildCalendarTab(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNewsTab(BuildContext context) {
    final theme = Theme.of(context);
    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      itemCount: _newsItems.length,
      itemBuilder: (context, index) {
        final news = _newsItems[index];
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
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _sentimentColor(news['sentiment'] as String).withAlpha(26),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          (news['sentiment'] as String).toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _sentimentColor(news['sentiment'] as String),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(news['source'] as String, style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(128),
                      )),
                      const Spacer(),
                      Text(news['time'] as String, style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(100),
                        fontSize: 11,
                      )),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(news['title'] as String, style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  )),
                  const SizedBox(height: 6),
                  Text(news['summary'] as String, style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(153),
                    height: 1.4,
                  ), maxLines: 3, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    children: (news['sectors'] as List<String>).map((s) =>
                      Chip(
                        label: Text(s, style: const TextStyle(fontSize: 10)),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: EdgeInsets.zero,
                        labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                        visualDensity: VisualDensity.compact,
                      ),
                    ).toList(),
                  ),
                ],
              ),
            ),
          ),
        ).animate().fadeIn(delay: Duration(milliseconds: index * 100)).slideY(begin: 0.03);
      },
    );
  }

  Widget _buildSectorsTab(BuildContext context) {
    final theme = Theme.of(context);
    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      itemCount: _sectorData.length,
      itemBuilder: (context, index) {
        final sector = _sectorData[index];
        final perf = sector['perf1d'] as double;
        final isPositive = perf >= 0;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: (isPositive ? AppTheme.profitGreen : AppTheme.lossRed).withAlpha(26),
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
            title: Text(sector['name'] as String, style: theme.textTheme.titleSmall),
            subtitle: Row(
              children: [
                _perfChip('1D', sector['perf1d'] as double),
                const SizedBox(width: 8),
                _perfChip('1W', sector['perf1w'] as double),
                const SizedBox(width: 8),
                _perfChip('1M', sector['perf1m'] as double),
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

  Widget _buildCalendarTab(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      children: [
        _calendarSection(context, 'Upcoming Earnings', Icons.bar_chart, [
          {'date': 'Jul 10', 'event': 'TCS Q1 Results', 'est': 'EPS Est: ₹65'},
          {'date': 'Jul 12', 'event': 'Infosys Q1 Results', 'est': 'EPS Est: ₹42'},
          {'date': 'Jul 15', 'event': 'HDFC Bank Q1 Results', 'est': 'EPS Est: ₹22'},
          {'date': 'Jul 18', 'event': 'Reliance Q1 Results', 'est': 'EPS Est: ₹38'},
        ]),
        const SizedBox(height: AppTheme.spacingMd),
        _calendarSection(context, 'Economic Events', Icons.public, [
          {'date': 'Jul 5', 'event': 'RBI Policy Decision', 'est': 'Expected: Hold at 6.5%'},
          {'date': 'Jul 8', 'event': 'India CPI Inflation', 'est': 'Forecast: 4.8%'},
          {'date': 'Jul 12', 'event': 'US CPI Data', 'est': 'Forecast: 3.1%'},
          {'date': 'Jul 25', 'event': 'India Union Budget', 'est': 'Key event'},
        ]),
        const SizedBox(height: AppTheme.spacingMd),
        _calendarSection(context, 'Corporate Actions', Icons.business_center, [
          {'date': 'Jul 6', 'event': 'INFY: Dividend ₹18/share', 'est': 'Ex-date'},
          {'date': 'Jul 10', 'event': 'ITC: Dividend ₹6.75/share', 'est': 'Ex-date'},
          {'date': 'Jul 15', 'event': 'Nykaa: Stock Split 1:5', 'est': 'Record date'},
        ]),
      ],
    );
  }

  Widget _calendarSection(BuildContext context, String title, IconData icon, List<Map<String, String>> events) {
    final theme = Theme.of(context);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
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
                  child: Text(e['date']!, textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, fontSize: 10)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e['event']!, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                      Text(e['est']!, style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(128), fontSize: 11,
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
      case 'positive': return AppTheme.profitGreen;
      case 'negative': return AppTheme.lossRed;
      default: return AppTheme.warningAmber;
    }
  }

  static final _newsItems = [
    {'title': 'RBI Holds Rates at 6.5%, Signals Data-Dependent Approach', 'summary': 'The Reserve Bank of India maintained its repo rate at 6.5% for the eighth consecutive meeting, citing easing inflation but cautioning about food price risks.', 'sentiment': 'neutral', 'source': 'Economic Times', 'time': '2h ago', 'sectors': ['Financial Services', 'Banking']},
    {'title': 'IT Stocks Rally on Strong US Jobs Data', 'summary': 'Indian IT stocks surged 2-3% after US non-farm payrolls data beat expectations, signaling robust demand for technology services.', 'sentiment': 'positive', 'source': 'Moneycontrol', 'time': '4h ago', 'sectors': ['Information Technology']},
    {'title': 'Crude Oil Rises Above \$85, Energy Stocks Under Pressure', 'summary': 'Brent crude climbed above \$85/barrel on supply concerns from OPEC+ production cuts, putting pressure on OMC margins.', 'sentiment': 'negative', 'source': 'LiveMint', 'time': '6h ago', 'sectors': ['Energy', 'Oil & Gas']},
    {'title': 'FIIs Turn Net Buyers After 3 Months of Selling', 'summary': 'Foreign institutional investors pumped ₹5,200 crore into Indian equities this week, reversing a three-month selling trend.', 'sentiment': 'positive', 'source': 'Business Standard', 'time': '8h ago', 'sectors': ['Market Wide']},
  ];

  static final _sectorData = [
    {'name': 'Information Technology', 'perf1d': 2.1, 'perf1w': 3.5, 'perf1m': 5.8},
    {'name': 'Financial Services', 'perf1d': 1.5, 'perf1w': 2.2, 'perf1m': 4.1},
    {'name': 'Pharmaceuticals', 'perf1d': 0.8, 'perf1w': 1.9, 'perf1m': 6.2},
    {'name': 'Automobile', 'perf1d': 0.5, 'perf1w': 1.1, 'perf1m': 3.8},
    {'name': 'Consumer Goods', 'perf1d': 0.3, 'perf1w': 0.8, 'perf1m': 2.5},
    {'name': 'Infrastructure', 'perf1d': -0.2, 'perf1w': 0.5, 'perf1m': 1.9},
    {'name': 'Metals & Mining', 'perf1d': -0.8, 'perf1w': -1.2, 'perf1m': -2.1},
    {'name': 'Real Estate', 'perf1d': -1.2, 'perf1w': -2.5, 'perf1m': -3.4},
    {'name': 'Energy', 'perf1d': -1.5, 'perf1w': -3.1, 'perf1m': -5.2},
  ];
}
