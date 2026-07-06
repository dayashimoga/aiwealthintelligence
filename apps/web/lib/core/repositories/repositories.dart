import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../network/api_client.dart';
import '../network/hive_cache.dart';
import '../network/api_constants.dart';
import '../network/result.dart';

// ============================================================
// Auth Repository
// ============================================================

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.read(dioProvider), ref);
});

class AuthRepository {
  AuthRepository(this._dio, this._ref);

  final Dio _dio;
  final Ref _ref;

  Future<Result<AuthTokens>> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final response = await _dio.post(ApiConstants.register, data: {
        'email': email,
        'password': password,
        'full_name': fullName,
      });
      final tokens = AuthTokens.fromJson(response.data as Map<String, dynamic>);
      await _saveTokens(tokens);
      return Result.success(tokens);
    } on DioException catch (e) {
      return Result.failure(
        _extractError(e),
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<Result<AuthTokens>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post(ApiConstants.login, data: {
        'email': email,
        'password': password,
      });
      final tokens = AuthTokens.fromJson(response.data as Map<String, dynamic>);
      await _saveTokens(tokens);
      return Result.success(tokens);
    } on DioException catch (e) {
      return Result.failure(
        _extractError(e),
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<Result<User>> getProfile() async {
    try {
      final response = await _dio.get(ApiConstants.profile);
      await HiveCacheManager.set('user_profile_raw', response.data);
      await HiveCacheManager.set('user_profile_raw_time', DateTime.now().millisecondsSinceEpoch);
      return Result.success(
          User.fromJson(response.data as Map<String, dynamic>));
    } on DioException catch (e) {
      return Result.failure(_extractError(e),
          statusCode: e.response?.statusCode);
    }
  }

  Future<Result<AuthTokens>> oauthLogin({
    required String email,
    required String token,
    required String provider,
    String? fullName,
  }) async {
    try {
      final response = await _dio.post(ApiConstants.oauthLogin, data: {
        'email': email,
        'token': token,
        'provider': provider,
        'full_name': fullName,
      });
      final tokens = AuthTokens.fromJson(response.data as Map<String, dynamic>);
      await _saveTokens(tokens);
      return Result.success(tokens);
    } on DioException catch (e) {
      return Result.failure(_extractError(e), statusCode: e.response?.statusCode);
    }
  }

  Future<Result<String>> sendOtp({required String email}) async {
    try {
      final response = await _dio.post(ApiConstants.otpSend, data: {'email': email});
      return Result.success((response.data as Map<String, dynamic>)['message'] as String);
    } on DioException catch (e) {
      return Result.failure(_extractError(e), statusCode: e.response?.statusCode);
    }
  }

  Future<Result<AuthTokens>> verifyOtp({
    required String email,
    required String code,
  }) async {
    try {
      final response = await _dio.post(ApiConstants.otpVerify, data: {
        'email': email,
        'code': code,
      });
      final tokens = AuthTokens.fromJson(response.data as Map<String, dynamic>);
      await _saveTokens(tokens);
      return Result.success(tokens);
    } on DioException catch (e) {
      return Result.failure(_extractError(e), statusCode: e.response?.statusCode);
    }
  }

  Future<Result<Map<String, dynamic>>> setupTotp() async {
    try {
      final response = await _dio.post(ApiConstants.totpSetup);
      return Result.success(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      return Result.failure(_extractError(e), statusCode: e.response?.statusCode);
    }
  }

  Future<Result<List<String>>> enableTotp({required String code}) async {
    try {
      final response = await _dio.post(ApiConstants.totpEnable, data: {'code': code});
      final backupCodes = ((response.data as Map<String, dynamic>)['backup_codes'] as List<dynamic>)
          .map((e) => e as String)
          .toList();
      return Result.success(backupCodes);
    } on DioException catch (e) {
      return Result.failure(_extractError(e), statusCode: e.response?.statusCode);
    }
  }

  Future<Result<String>> disableTotp() async {
    try {
      final response = await _dio.post(ApiConstants.totpDisable);
      return Result.success((response.data as Map<String, dynamic>)['message'] as String);
    } on DioException catch (e) {
      return Result.failure(_extractError(e), statusCode: e.response?.statusCode);
    }
  }

  Future<Result<List<Device>>> listDevices() async {
    try {
      final response = await _dio.get(ApiConstants.devices);
      final devices = (response.data as List<dynamic>)
          .map((e) => Device.fromJson(e as Map<String, dynamic>))
          .toList();
      return Result.success(devices);
    } on DioException catch (e) {
      return Result.failure(_extractError(e), statusCode: e.response?.statusCode);
    }
  }

  Future<Result<String>> revokeDevice({required String deviceId}) async {
    try {
      final response = await _dio.delete(ApiConstants.device(deviceId));
      return Result.success((response.data as Map<String, dynamic>)['message'] as String);
    } on DioException catch (e) {
      return Result.failure(_extractError(e), statusCode: e.response?.statusCode);
    }
  }

  Future<Result<String>> completeOnboarding() async {
    try {
      final response = await _dio.post(ApiConstants.onboardingComplete);
      return Result.success((response.data as Map<String, dynamic>)['message'] as String);
    } on DioException catch (e) {
      return Result.failure(_extractError(e), statusCode: e.response?.statusCode);
    }
  }

  Future<Result<Map<String, dynamic>>> passkeyRegisterOptions() async {
    try {
      final response = await _dio.post(ApiConstants.passkeyRegisterOptions);
      return Result.success(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      return Result.failure(_extractError(e), statusCode: e.response?.statusCode);
    }
  }

  Future<Result<String>> passkeyRegisterVerify({
    required String credentialId,
    required String clientDataJson,
    required String authenticatorData,
    required String signature,
  }) async {
    try {
      final response = await _dio.post(ApiConstants.passkeyRegisterVerify, data: {
        'credential_id': credentialId,
        'client_data_json': clientDataJson,
        'authenticator_data': authenticatorData,
        'signature': signature,
      });
      return Result.success((response.data as Map<String, dynamic>)['message'] as String);
    } on DioException catch (e) {
      return Result.failure(_extractError(e), statusCode: e.response?.statusCode);
    }
  }

  Future<Result<Map<String, dynamic>>> passkeyLoginOptions({required String email}) async {
    try {
      final response = await _dio.post(ApiConstants.passkeyLoginOptions, data: {'email': email});
      return Result.success(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      return Result.failure(_extractError(e), statusCode: e.response?.statusCode);
    }
  }

  Future<Result<AuthTokens>> passkeyLoginVerify({
    required String credentialId,
    required String clientDataJson,
    required String authenticatorData,
    required String signature,
  }) async {
    try {
      final response = await _dio.post(ApiConstants.passkeyLoginVerify, data: {
        'credential_id': credentialId,
        'client_data_json': clientDataJson,
        'authenticator_data': authenticatorData,
        'signature': signature,
      });
      final tokens = AuthTokens.fromJson(response.data as Map<String, dynamic>);
      await _saveTokens(tokens);
      return Result.success(tokens);
    } on DioException catch (e) {
      return Result.failure(_extractError(e), statusCode: e.response?.statusCode);
    }
  }

  Future<void> logout() async {
    final storage = _ref.read(secureStorageProvider);
    await storage.delete(key: TokenKeys.accessToken);
    await storage.delete(key: TokenKeys.refreshToken);
  }

  Future<Result<String>> deleteAccount() async {
    try {
      final response = await _dio.delete(ApiConstants.deleteAccount);
      await logout();
      return Result.success((response.data as Map<String, dynamic>)['message'] as String);
    } on DioException catch (e) {
      return Result.failure(_extractError(e), statusCode: e.response?.statusCode);
    }
  }

  Future<void> _saveTokens(AuthTokens tokens) async {
    final storage = _ref.read(secureStorageProvider);
    await storage.write(
        key: TokenKeys.accessToken, value: tokens.accessToken);
    await storage.write(
        key: TokenKeys.refreshToken, value: tokens.refreshToken);
  }
}

// ============================================================
// Portfolio Repository
// ============================================================

final portfolioRepositoryProvider = Provider<PortfolioRepository>((ref) {
  return PortfolioRepository(ref.read(dioProvider));
});

class PortfolioRepository {
  PortfolioRepository(this._dio);

  final Dio _dio;

  Future<Result<List<Portfolio>>> listPortfolios() async {
    try {
      final response = await _dio.get(ApiConstants.portfolios);
      await HiveCacheManager.set('portfolios_list_raw', response.data);
      await HiveCacheManager.set('portfolios_list_raw_time', DateTime.now().millisecondsSinceEpoch);
      final data = response.data as Map<String, dynamic>;
      final portfolios = (data['portfolios'] as List)
          .map((p) => Portfolio.fromJson(p as Map<String, dynamic>))
          .toList();
      return Result.success(portfolios);
    } on DioException catch (e) {
      return Result.failure(_extractError(e));
    }
  }

  Future<Result<Portfolio>> getPortfolio(String id) async {
    try {
      final response = await _dio.get(ApiConstants.portfolio(id));
      return Result.success(
          Portfolio.fromJson(response.data as Map<String, dynamic>));
    } on DioException catch (e) {
      return Result.failure(_extractError(e));
    }
  }

  Future<Result<Portfolio>> createPortfolio({
    required String name,
    String description = '',
    String currency = 'INR',
  }) async {
    try {
      final response = await _dio.post(ApiConstants.portfolios, data: {
        'name': name,
        'description': description,
        'currency': currency,
      });
      return Result.success(
          Portfolio.fromJson(response.data as Map<String, dynamic>));
    } on DioException catch (e) {
      return Result.failure(_extractError(e));
    }
  }

  Future<Result<Portfolio>> updatePortfolio(
      String id, Map<String, dynamic> updates) async {
    try {
      final response =
          await _dio.patch(ApiConstants.portfolio(id), data: updates);
      return Result.success(
          Portfolio.fromJson(response.data as Map<String, dynamic>));
    } on DioException catch (e) {
      return Result.failure(_extractError(e));
    }
  }

  Future<Result<void>> deletePortfolio(String id) async {
    try {
      await _dio.delete(ApiConstants.portfolio(id));
      return const Result.success(null);
    } on DioException catch (e) {
      return Result.failure(_extractError(e));
    }
  }

  Future<Result<PortfolioAnalytics>> getAnalytics(String portfolioId) async {
    try {
      final response =
          await _dio.get(ApiConstants.portfolioAnalytics(portfolioId));
      await HiveCacheManager.set('portfolio_analytics_${portfolioId}_raw', response.data);
      await HiveCacheManager.set('portfolio_analytics_${portfolioId}_raw_time', DateTime.now().millisecondsSinceEpoch);
      return Result.success(PortfolioAnalytics.fromJson(
          response.data as Map<String, dynamic>));
    } on DioException catch (e) {
      return Result.failure(_extractError(e));
    }
  }

  Future<Result<ImportResult>> importCasPdf(
    String portfolioId,
    List<int> fileBytes,
    String filename, {
    String? password,
  }) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(fileBytes, filename: filename),
        if (password != null) 'password': password,
      });
      final response = await _dio.post(
        ApiConstants.importCasPdf(portfolioId),
        data: formData,
      );
      return Result.success(ImportResult.fromJson(response.data as Map<String, dynamic>));
    } on DioException catch (e) {
      return Result.failure(_extractError(e));
    }
  }

  Future<Result<ImportResult>> importBrokerReport(
    String portfolioId,
    List<int> fileBytes,
    String filename,
  ) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(fileBytes, filename: filename),
      });
      final response = await _dio.post(
        ApiConstants.importBrokerReport(portfolioId),
        data: formData,
      );
      return Result.success(ImportResult.fromJson(response.data as Map<String, dynamic>));
    } on DioException catch (e) {
      return Result.failure(_extractError(e));
    }
  }

  Future<Result<Map<String, dynamic>>> initiateConsent({
    required String portfolioId,
    required String phoneNumber,
    required String aggregatorId,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.initiateConsent(portfolioId),
        data: {
          'phone_number': phoneNumber,
          'aggregator_id': aggregatorId,
        },
      );
      return Result.success(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      return Result.failure(_extractError(e));
    }
  }

  Future<Result<Map<String, dynamic>>> getConsentStatus({
    required String portfolioId,
    required String consentHandle,
  }) async {
    try {
      final response = await _dio.get(
        ApiConstants.getConsentStatus(portfolioId, consentHandle),
      );
      return Result.success(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      return Result.failure(_extractError(e));
    }
  }
}

// ============================================================
// Holding Repository
// ============================================================

final holdingRepositoryProvider = Provider<HoldingRepository>((ref) {
  return HoldingRepository(ref.read(dioProvider));
});

class HoldingRepository {
  HoldingRepository(this._dio);

  final Dio _dio;

  Future<Result<List<Holding>>> listHoldings(String portfolioId) async {
    try {
      final response = await _dio.get(ApiConstants.holdings(portfolioId));
      await HiveCacheManager.set('holdings_list_${portfolioId}_raw', response.data);
      await HiveCacheManager.set('holdings_list_${portfolioId}_raw_time', DateTime.now().millisecondsSinceEpoch);
      final data = response.data as Map<String, dynamic>;
      final holdings = (data['holdings'] as List)
          .map((h) => Holding.fromJson(h as Map<String, dynamic>))
          .toList();
      return Result.success(holdings);
    } on DioException catch (e) {
      return Result.failure(_extractError(e));
    }
  }

  Future<Result<Holding>> createHolding(
      String portfolioId, Map<String, dynamic> data) async {
    try {
      final response =
          await _dio.post(ApiConstants.holdings(portfolioId), data: data);
      return Result.success(
          Holding.fromJson(response.data as Map<String, dynamic>));
    } on DioException catch (e) {
      return Result.failure(_extractError(e));
    }
  }

  Future<Result<Holding>> updateHolding(
      String portfolioId, String holdingId, Map<String, dynamic> data) async {
    try {
      final response = await _dio
          .patch(ApiConstants.holding(portfolioId, holdingId), data: data);
      return Result.success(
          Holding.fromJson(response.data as Map<String, dynamic>));
    } on DioException catch (e) {
      return Result.failure(_extractError(e));
    }
  }

  Future<Result<void>> deleteHolding(
      String portfolioId, String holdingId) async {
    try {
      await _dio.delete(ApiConstants.holding(portfolioId, holdingId));
      return const Result.success(null);
    } on DioException catch (e) {
      return Result.failure(_extractError(e));
    }
  }
}

// ============================================================
// AI Repository
// ============================================================

final aiRepositoryProvider = Provider<AIRepository>((ref) {
  return AIRepository(ref.read(dioProvider));
});

class AIRepository {
  AIRepository(this._dio);

  final Dio _dio;

  Future<Result<AIRecommendation>> getRecommendation(
      String portfolioId, String holdingId) async {
    try {
      final response = await _dio
          .get(ApiConstants.aiRecommendation(portfolioId, holdingId));
      return Result.success(AIRecommendation.fromJson(
          response.data as Map<String, dynamic>));
    } on DioException catch (e) {
      return Result.failure(_extractError(e));
    }
  }

  Future<Result<ChatMessage>> chat({
    required String message,
    String? portfolioId,
  }) async {
    try {
      final response = await _dio.post(ApiConstants.aiChat, data: {
        'message': message,
        if (portfolioId != null) 'portfolio_id': portfolioId,
      });
      return Result.success(
          ChatMessage.fromJson(response.data as Map<String, dynamic>));
    } on DioException catch (e) {
      return Result.failure(_extractError(e));
    }
  }

  Future<Result<DailyBrief>> getCopilotBrief(String portfolioId) async {
    try {
      final response = await _dio.get(ApiConstants.copilotBrief(portfolioId));
      return Result.success(DailyBrief.fromJson(response.data as Map<String, dynamic>));
    } on DioException catch (e) {
      return Result.failure(_extractError(e));
    }
  }

  Future<Result<PortfolioDoctor>> getCopilotDoctor(String portfolioId) async {
    try {
      final response = await _dio.get(ApiConstants.copilotDoctor(portfolioId));
      return Result.success(PortfolioDoctor.fromJson(response.data as Map<String, dynamic>));
    } on DioException catch (e) {
      return Result.failure(_extractError(e));
    }
  }

  Future<Result<ScenarioSimulation>> simulateScenario(
    String portfolioId,
    List<Map<String, dynamic>> actions,
  ) async {
    try {
      final response = await _dio.post(
        ApiConstants.copilotScenario(portfolioId),
        data: {
          'portfolio_id': portfolioId,
          'actions': actions,
        },
      );
      return Result.success(ScenarioSimulation.fromJson(response.data as Map<String, dynamic>));
    } on DioException catch (e) {
      return Result.failure(_extractError(e));
    }
  }

  Future<Result<AdvancedAnalysis>> getCopilotAdvanced(String portfolioId) async {
    try {
      final response = await _dio.get(ApiConstants.copilotAdvanced(portfolioId));
      return Result.success(AdvancedAnalysis.fromJson(response.data as Map<String, dynamic>));
    } on DioException catch (e) {
      return Result.failure(_extractError(e));
    }
  }
}

// ============================================================
// Market Repository
// ============================================================

final marketRepositoryProvider = Provider<MarketRepository>((ref) {
  return MarketRepository(ref.read(dioProvider));
});

class MarketRepository {
  MarketRepository(this._dio);

  final Dio _dio;

  Future<Result<MarketOverview>> getMarketOverview() async {
    try {
      final response = await _dio.get(ApiConstants.marketOverview);
      await HiveCacheManager.set('market_overview_raw', response.data);
      await HiveCacheManager.set('market_overview_raw_time', DateTime.now().millisecondsSinceEpoch);
      return Result.success(MarketOverview.fromJson(response.data as Map<String, dynamic>));
    } on DioException catch (e) {
      return Result.failure(_extractError(e));
    }
  }
}

// ============================================================
// Notification Repository
// ============================================================

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.read(dioProvider));
});

class NotificationRepository {
  NotificationRepository(this._dio);
  final Dio _dio;

  Future<Result<List<AppNotification>>> listNotifications({
    bool unreadOnly = false,
    int limit = 50,
  }) async {
    try {
      final response = await _dio.get(ApiConstants.notifications, queryParameters: {
        'unread_only': unreadOnly,
        'limit': limit,
      });
      final data = response.data as Map<String, dynamic>;
      final rawList = data['notifications'] as List<dynamic>? ?? [];
      final notifications = rawList
          .map((n) => AppNotification.fromJson(n as Map<String, dynamic>))
          .toList();
      return Result.success(notifications);
    } on DioException catch (e) {
      return Result.failure(_extractError(e));
    }
  }

  Future<Result<int>> getUnreadCount() async {
    try {
      final response = await _dio.get(ApiConstants.notificationsCount);
      final data = response.data as Map<String, dynamic>;
      return Result.success(data['unread_count'] as int? ?? 0);
    } on DioException catch (e) {
      return Result.failure(_extractError(e));
    }
  }

  Future<Result<bool>> markRead(String notificationId) async {
    try {
      await _dio.post(ApiConstants.notificationRead(notificationId));
      return const Result.success(true);
    } on DioException catch (e) {
      return Result.failure(_extractError(e));
    }
  }

  Future<Result<int>> markAllRead() async {
    try {
      final response = await _dio.post(ApiConstants.notificationsReadAll);
      final data = response.data as Map<String, dynamic>;
      return Result.success(data['marked_read'] as int? ?? 0);
    } on DioException catch (e) {
      return Result.failure(_extractError(e));
    }
  }
}

// ============================================================
// Goal Repository
// ============================================================

final goalRepositoryProvider = Provider<GoalRepository>((ref) {
  return GoalRepository(ref.read(dioProvider));
});

class GoalRepository {
  GoalRepository(this._dio);
  final Dio _dio;

  Future<Result<List<FinancialGoal>>> listGoals({bool activeOnly = true}) async {
    try {
      final response = await _dio.get(ApiConstants.goals, queryParameters: {
        'active_only': activeOnly,
      });
      final data = response.data as Map<String, dynamic>;
      final rawList = data['goals'] as List<dynamic>? ?? [];
      final goals = rawList
          .map((g) => FinancialGoal.fromJson(g as Map<String, dynamic>))
          .toList();
      return Result.success(goals);
    } on DioException catch (e) {
      return Result.failure(_extractError(e));
    }
  }

  Future<Result<FinancialGoal>> createGoal(Map<String, dynamic> goalData) async {
    try {
      final response = await _dio.post(ApiConstants.goals, data: goalData);
      return Result.success(
        FinancialGoal.fromJson(response.data as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      return Result.failure(_extractError(e));
    }
  }

  Future<Result<FinancialGoal>> updateGoal(String goalId, Map<String, dynamic> data) async {
    try {
      final response = await _dio.put(ApiConstants.goal(goalId), data: data);
      return Result.success(
        FinancialGoal.fromJson(response.data as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      return Result.failure(_extractError(e));
    }
  }

  Future<Result<void>> deleteGoal(String goalId) async {
    try {
      await _dio.delete(ApiConstants.goal(goalId));
      return const Result.success(null);
    } on DioException catch (e) {
      return Result.failure(_extractError(e));
    }
  }
}

// ============================================================
// Watchlist Repository
// ============================================================

final watchlistRepositoryProvider = Provider<WatchlistRepository>((ref) {
  return WatchlistRepository(ref.read(dioProvider));
});

class WatchlistRepository {
  WatchlistRepository(this._dio);
  final Dio _dio;

  Future<Result<List<WatchlistItem>>> listWatchlists() async {
    try {
      final response = await _dio.get(ApiConstants.watchlists);
      final data = response.data as Map<String, dynamic>;
      final rawList = data['watchlists'] as List<dynamic>? ?? [];
      final watchlists = rawList
          .map((w) => WatchlistItem.fromJson(w as Map<String, dynamic>))
          .toList();
      return Result.success(watchlists);
    } on DioException catch (e) {
      return Result.failure(_extractError(e));
    }
  }

  Future<Result<WatchlistItem>> createWatchlist({
    required String name,
    List<String> symbols = const [],
  }) async {
    try {
      final response = await _dio.post(ApiConstants.watchlists, data: {
        'name': name,
        'symbols': symbols,
      });
      return Result.success(
        WatchlistItem.fromJson(response.data as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      return Result.failure(_extractError(e));
    }
  }

  Future<Result<Map<String, dynamic>>> addSymbol(String watchlistId, {
    required String symbol,
    double? alertAbove,
    double? alertBelow,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.watchlistSymbols(watchlistId),
        data: {
          'symbol': symbol,
          if (alertAbove != null) 'alert_above': alertAbove,
          if (alertBelow != null) 'alert_below': alertBelow,
        },
      );
      return Result.success(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      return Result.failure(_extractError(e));
    }
  }

  Future<Result<List<WatchlistIntelligenceItem>>> getIntelligence(
    String watchlistId,
  ) async {
    try {
      final response = await _dio.get(
        ApiConstants.watchlistIntelligence(watchlistId),
      );
      final data = response.data as Map<String, dynamic>;
      final rawList = data['intelligence'] as List<dynamic>? ?? [];
      final items = rawList
          .map((i) => WatchlistIntelligenceItem.fromJson(i as Map<String, dynamic>))
          .toList();
      return Result.success(items);
    } on DioException catch (e) {
      return Result.failure(_extractError(e));
    }
  }

  Future<Result<void>> removeSymbol(String watchlistId, String symbol) async {
    try {
      await _dio.delete(
        ApiConstants.watchlistRemoveSymbol(watchlistId, symbol),
      );
      return const Result.success(null);
    } on DioException catch (e) {
      return Result.failure(_extractError(e));
    }
  }

  Future<Result<void>> deleteWatchlist(String watchlistId) async {
    try {
      await _dio.delete(ApiConstants.watchlist(watchlistId));
      return const Result.success(null);
    } on DioException catch (e) {
      return Result.failure(_extractError(e));
    }
  }
}

// ============================================================
// Helpers
// ============================================================

String _extractError(DioException e) {
  if (e.response?.data is Map<String, dynamic>) {
    final data = e.response!.data as Map<String, dynamic>;
    return data['error'] as String? ??
        data['detail'] as String? ??
        data['message'] as String? ??
        'An error occurred';
  }
  if (e.type == DioExceptionType.connectionTimeout) {
    return 'Connection timed out';
  }
  if (e.type == DioExceptionType.receiveTimeout) {
    return 'Server took too long to respond';
  }
  return e.message ?? 'An unexpected error occurred';
}

