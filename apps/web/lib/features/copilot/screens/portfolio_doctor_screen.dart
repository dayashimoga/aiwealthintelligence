import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/portfolio_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';

class PortfolioDoctorScreen extends ConsumerWidget {
  const PortfolioDoctorScreen({super.key, required this.portfolioId});

  final String portfolioId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final doctorAsync = ref.watch(portfolioDoctorProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Portfolio Doctor'),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppTheme.darkBgGradient : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          child: doctorAsync.when(
            data: (doctor) {
              if (doctor == null) return const Center(child: Text('No diagnostic data.'));
              final scoreColor = doctor.healthScore >= 80
                  ? AppTheme.profitGreen
                  : (doctor.healthScore >= 50 ? AppTheme.warningAmber : AppTheme.lossRed);

              return ListView(
                children: [
                  // Health Score Circle Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppTheme.spacingLg),
                      child: Column(
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: scoreColor, width: 6),
                            ),
                            child: Center(
                              child: Text(
                                '${doctor.healthScore}',
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: scoreColor,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text('Overall Health Rating', style: theme.textTheme.titleMedium),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _metricItem('Diversification HHI', '${doctor.diversificationHhi.toStringAsFixed(0)}'),
                              _metricItem('Sector Conc.', '${doctor.sectorConcentrationPct.toStringAsFixed(0)}%'),
                              _metricItem('Cash Drag', '${doctor.cashDragPct.toStringAsFixed(0)}%'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(),

                  const SizedBox(height: AppTheme.spacingMd),

                  // Issues list header
                  Text('Diagnosis Issues (${doctor.issues.length})', style: theme.textTheme.titleMedium),
                  const SizedBox(height: AppTheme.spacingSm),

                  if (doctor.issues.isEmpty)
                    GlassCard(
                      child: Padding(
                        padding: const EdgeInsets.all(AppTheme.spacingMd),
                        child: Row(
                          children: const [
                            Icon(Icons.check_circle, color: Colors.green, size: 28),
                            SizedBox(width: 12),
                            Text('No problems found. Your portfolio is in optimal shape!'),
                          ],
                        ),
                      ),
                    )
                  else
                    ...doctor.issues.map((issue) {
                      final isHigh = issue.severity.toLowerCase() == 'high';
                      final isMedium = issue.severity.toLowerCase() == 'medium';
                      final severityColor = isHigh
                          ? AppTheme.lossRed
                          : (isMedium ? AppTheme.warningAmber : AppTheme.infoBlue);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ExpansionTile(
                          leading: Icon(
                            isHigh ? Icons.warning : Icons.info_outline,
                            color: severityColor,
                          ),
                          title: Text(
                            issue.title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          subtitle: Text(
                            'Severity: ${issue.severity.toUpperCase()}',
                            style: TextStyle(color: severityColor, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(AppTheme.spacingMd),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    'Risk description:',
                                    style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(issue.description, style: const TextStyle(height: 1.3, fontSize: 13)),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Recommendation:',
                                    style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.amber),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(issue.recommendation, style: const TextStyle(height: 1.3, fontSize: 13)),
                                ],
                              ),
                            )
                          ],
                        ),
                      ).animate().fadeIn();
                    }).toList(),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Failed to load diagnosis: $err')),
          ),
        ),
      ),
    );
  }

  Widget _metricItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ],
    );
  }
}
