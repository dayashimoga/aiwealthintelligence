import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';

/// Portfolio list screen showing all user portfolios.
class PortfolioListScreen extends StatelessWidget {
  const PortfolioListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Portfolios'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload_outlined),
            tooltip: 'Import CSV',
            onPressed: () {},
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        icon: const Icon(Icons.add),
        label: const Text('New Portfolio'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        children: [
          _portfolioCard(context, 'Growth Portfolio', '₹24,50,000', '+15.0%',
              true, 12, 'portfolio-1'),
          _portfolioCard(context, 'Dividend Portfolio', '₹8,20,000', '+8.2%',
              true, 8, 'portfolio-2'),
          _portfolioCard(context, 'SIP Portfolio', '₹5,60,000', '+22.5%', true,
              5, 'portfolio-3'),
        ]
            .asMap()
            .entries
            .map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.spacingMd),
                child: e.value
                    .animate()
                    .fadeIn(delay: Duration(milliseconds: e.key * 150))
                    .slideY(begin: 0.05),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _portfolioCard(BuildContext context, String name, String value,
      String change, bool positive, int holdings, String id) {
    final theme = Theme.of(context);

    return GlassCard(
      onTap: () => context.go('/portfolios/$id'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('$holdings holdings',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(128),
                      )),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(value,
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(change,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            positive ? AppTheme.profitGreen : AppTheme.lossRed,
                        fontWeight: FontWeight.w600,
                      )),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingMd),
          // Mini progress bar showing allocation
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 6,
              child: Row(
                children: [
                  Expanded(
                      flex: 45,
                      child: Container(color: const Color(0xFF6C63FF))),
                  Expanded(
                      flex: 25,
                      child: Container(color: const Color(0xFF00D9A6))),
                  Expanded(
                      flex: 15,
                      child: Container(color: const Color(0xFFFF6B6B))),
                  Expanded(
                      flex: 15,
                      child: Container(color: const Color(0xFFFFAB00))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
