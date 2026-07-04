import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../network/result.dart';
import '../repositories/repositories.dart';

/// Currently selected portfolio ID.
final selectedPortfolioIdProvider = StateProvider<String?>((ref) => null);

/// Portfolios list provider.
final portfoliosProvider = FutureProvider<List<Portfolio>>((ref) async {
  final repo = ref.watch(portfolioRepositoryProvider);
  final result = await repo.listPortfolios();
  return result.when(
    success: (data) {
      if (data.isNotEmpty && ref.read(selectedPortfolioIdProvider) == null) {
        ref.read(selectedPortfolioIdProvider.notifier).state = data.first.id;
      }
      return data;
    },
    failure: (err, _) => throw Exception(err),
  );
});

/// Currently selected portfolio object.
final selectedPortfolioProvider = Provider<Portfolio?>((ref) {
  final selectedId = ref.watch(selectedPortfolioIdProvider);
  if (selectedId == null) return null;
  final portfoliosAsync = ref.watch(portfoliosProvider);
  return portfoliosAsync.whenOrNull(
    data: (list) {
      final index = list.indexWhere((p) => p.id == selectedId);
      return index != -1 ? list[index] : (list.isNotEmpty ? list.first : null);
    },
  );
});

/// Holdings list provider for selected portfolio.
final holdingsProvider = FutureProvider<List<Holding>>((ref) async {
  final portfolioId = ref.watch(selectedPortfolioIdProvider);
  if (portfolioId == null) return [];
  final repo = ref.watch(holdingRepositoryProvider);
  final result = await repo.listHoldings(portfolioId);
  return result.when(
    success: (data) => data,
    failure: (err, _) => throw Exception(err),
  );
});

/// Analytics provider for selected portfolio.
final portfolioAnalyticsProvider = FutureProvider<PortfolioAnalytics?>((ref) async {
  final portfolioId = ref.watch(selectedPortfolioIdProvider);
  if (portfolioId == null) return null;
  final repo = ref.watch(portfolioRepositoryProvider);
  final result = await repo.getAnalytics(portfolioId);
  return result.when(
    success: (data) => data,
    failure: (err, _) => throw Exception(err),
  );
});

/// Daily AI Brief provider for selected portfolio.
final dailyBriefProvider = FutureProvider<DailyBrief?>((ref) async {
  final portfolioId = ref.watch(selectedPortfolioIdProvider);
  if (portfolioId == null) return null;
  final repo = ref.watch(aiRepositoryProvider);
  final result = await repo.getCopilotBrief(portfolioId);
  return result.when(
    success: (data) => data,
    failure: (err, _) => throw Exception(err),
  );
});

/// Portfolio Doctor provider for selected portfolio.
final portfolioDoctorProvider = FutureProvider<PortfolioDoctor?>((ref) async {
  final portfolioId = ref.watch(selectedPortfolioIdProvider);
  if (portfolioId == null) return null;
  final repo = ref.watch(aiRepositoryProvider);
  final result = await repo.getCopilotDoctor(portfolioId);
  return result.when(
    success: (data) => data,
    failure: (err, _) => throw Exception(err),
  );
});
