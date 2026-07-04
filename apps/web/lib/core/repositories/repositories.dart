import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../network/api_client.dart';
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
      return Result.success(
          User.fromJson(response.data as Map<String, dynamic>));
    } on DioException catch (e) {
      return Result.failure(_extractError(e),
          statusCode: e.response?.statusCode);
    }
  }

  Future<void> logout() async {
    final storage = _ref.read(secureStorageProvider);
    await storage.delete(key: TokenKeys.accessToken);
    await storage.delete(key: TokenKeys.refreshToken);
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
