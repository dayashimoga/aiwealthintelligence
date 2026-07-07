import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../network/hive_cache.dart';
import '../repositories/repositories.dart';

/// Active user profile provider.
final userProfileProvider = StreamProvider<User>((ref) async* {
  const cacheKey = 'user_profile_raw';
  final cached = HiveCacheManager.get(cacheKey);
  User? cachedUser;
  if (cached != null) {
    try {
      cachedUser = User.fromJson(Map<String, dynamic>.from(cached as Map));
      yield cachedUser;
    } catch (_) {}
  }

  final timestamp = HiveCacheManager.get('${cacheKey}_time') as int?;
  final isFresh = timestamp != null && (DateTime.now().millisecondsSinceEpoch - timestamp) < 120000;

  if (isFresh && cachedUser != null) return;

  final repo = ref.watch(authRepositoryProvider);
  final result = await repo.getProfile();
  yield* result.when(
    success: (data) async* {
      yield data;
    },
    failure: (err, _) => throw Exception(err),
  );
});

/// Currently selected portfolio ID.
final selectedPortfolioIdProvider = StateProvider<String?>((ref) => null);

/// Portfolios list provider.
final portfoliosProvider = StreamProvider<List<Portfolio>>((ref) async* {
  const cacheKey = 'portfolios_list_raw';
  final cached = HiveCacheManager.get(cacheKey);
  List<Portfolio>? cachedList;
  if (cached != null) {
    try {
      final rawList = cached as Map<dynamic, dynamic>;
      final listPortfolios = rawList['portfolios'] as List;
      cachedList = listPortfolios
          .map((p) => Portfolio.fromJson(Map<String, dynamic>.from(p as Map)))
          .toList();
      yield cachedList;
      if (cachedList.isNotEmpty && ref.read(selectedPortfolioIdProvider) == null) {
        ref.read(selectedPortfolioIdProvider.notifier).state = cachedList.first.id;
      }
    } catch (_) {}
  }

  final timestamp = HiveCacheManager.get('${cacheKey}_time') as int?;
  final isFresh = timestamp != null && (DateTime.now().millisecondsSinceEpoch - timestamp) < 120000;

  if (isFresh && cachedList != null) return;

  final repo = ref.watch(portfolioRepositoryProvider);
  final result = await repo.listPortfolios();
  yield* result.when(
    success: (data) async* {
      if (data.isNotEmpty && ref.read(selectedPortfolioIdProvider) == null) {
        ref.read(selectedPortfolioIdProvider.notifier).state = data.first.id;
      }
      yield data;
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
final holdingsProvider = StreamProvider<List<Holding>>((ref) async* {
  final portfolioId = ref.watch(selectedPortfolioIdProvider);
  if (portfolioId == null) {
    yield [];
    return;
  }

  final cacheKey = 'holdings_list_${portfolioId}_raw';
  final cached = HiveCacheManager.get(cacheKey);
  List<Holding>? cachedList;
  if (cached != null) {
    try {
      final rawList = cached as Map<dynamic, dynamic>;
      final listHoldings = rawList['holdings'] as List;
      cachedList =
          listHoldings.map((h) => Holding.fromJson(Map<String, dynamic>.from(h as Map))).toList();
      yield cachedList;
    } catch (_) {}
  }

  final timestamp = HiveCacheManager.get('${cacheKey}_time') as int?;
  final isFresh = timestamp != null && (DateTime.now().millisecondsSinceEpoch - timestamp) < 120000;

  if (isFresh && cachedList != null) return;

  final repo = ref.watch(holdingRepositoryProvider);
  final result = await repo.listHoldings(portfolioId);
  yield* result.when(
    success: (data) async* {
      yield data;
    },
    failure: (err, _) => throw Exception(err),
  );
});

/// Analytics provider for selected portfolio.
final portfolioAnalyticsProvider = StreamProvider<PortfolioAnalytics?>((ref) async* {
  final portfolioId = ref.watch(selectedPortfolioIdProvider);
  if (portfolioId == null) {
    yield null;
    return;
  }

  final cacheKey = 'portfolio_analytics_${portfolioId}_raw';
  final cached = HiveCacheManager.get(cacheKey);
  PortfolioAnalytics? cachedAnalytics;
  if (cached != null) {
    try {
      cachedAnalytics = PortfolioAnalytics.fromJson(Map<String, dynamic>.from(cached as Map));
      yield cachedAnalytics;
    } catch (_) {}
  }

  final timestamp = HiveCacheManager.get('${cacheKey}_time') as int?;
  final isFresh = timestamp != null && (DateTime.now().millisecondsSinceEpoch - timestamp) < 120000;

  if (isFresh && cachedAnalytics != null) return;

  final repo = ref.watch(portfolioRepositoryProvider);
  final result = await repo.getAnalytics(portfolioId);
  yield* result.when(
    success: (data) async* {
      yield data;
    },
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

/// Advanced Wealth Analysis provider for selected portfolio.
final advancedAnalysisProvider = FutureProvider<AdvancedAnalysis?>((ref) async {
  final portfolioId = ref.watch(selectedPortfolioIdProvider);
  if (portfolioId == null) return null;
  final repo = ref.watch(aiRepositoryProvider);
  final result = await repo.getCopilotAdvanced(portfolioId);
  return result.when(
    success: (data) => data,
    failure: (err, _) => throw Exception(err),
  );
});

/// Market Overview provider.
final marketOverviewProvider = StreamProvider<MarketOverview>((ref) async* {
  const cacheKey = 'market_overview_raw';
  final cached = HiveCacheManager.get(cacheKey);
  MarketOverview? cachedOverview;
  if (cached != null) {
    try {
      cachedOverview = MarketOverview.fromJson(Map<String, dynamic>.from(cached as Map));
      yield cachedOverview;
    } catch (_) {}
  }

  final timestamp = HiveCacheManager.get('${cacheKey}_time') as int?;
  final isFresh = timestamp != null && (DateTime.now().millisecondsSinceEpoch - timestamp) < 120000;

  if (isFresh && cachedOverview != null) return;

  final repo = ref.watch(marketRepositoryProvider);
  final result = await repo.getMarketOverview();
  yield* result.when(
    success: (data) async* {
      yield data;
    },
    failure: (err, _) => throw Exception(err),
  );
});

/// AI recommendation provider for a specific holding.
final aiRecommendationProvider =
    FutureProvider.family<AIRecommendation?, String>((ref, holdingId) async {
  final portfolioId = ref.watch(selectedPortfolioIdProvider);
  if (portfolioId == null) return null;
  final repo = ref.watch(aiRepositoryProvider);
  final result = await repo.getRecommendation(portfolioId, holdingId);
  return result.when(
    success: (data) => data,
    failure: (err, _) => throw Exception(err),
  );
});

/// Notifications provider.
final notificationsProvider = FutureProvider<List<AppNotification>>((ref) async {
  final repo = ref.watch(notificationRepositoryProvider);
  final result = await repo.listNotifications();
  return result.when(
    success: (data) => data,
    failure: (err, _) => throw Exception(err),
  );
});

/// Unread notification count provider.
final unreadNotificationCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(notificationRepositoryProvider);
  final result = await repo.getUnreadCount();
  return result.when(
    success: (data) => data,
    failure: (err, _) => 0,
  );
});

/// Financial goals provider.
final goalsProvider = FutureProvider<List<FinancialGoal>>((ref) async {
  final repo = ref.watch(goalRepositoryProvider);
  final result = await repo.listGoals();
  return result.when(
    success: (data) => data,
    failure: (err, _) => throw Exception(err),
  );
});

/// Watchlists provider.
final watchlistsProvider = FutureProvider<List<WatchlistItem>>((ref) async {
  final repo = ref.watch(watchlistRepositoryProvider);
  final result = await repo.listWatchlists();
  return result.when(
    success: (data) => data,
    failure: (err, _) => throw Exception(err),
  );
});
