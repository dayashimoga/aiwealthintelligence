import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_constants.dart';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Provides a configured Dio HTTP client with auth interceptor.
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: ApiConstants.baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  ));

  dio.interceptors.add(ConnectivityInterceptor());
  dio.interceptors.add(AuthInterceptor(ref));
  dio.interceptors.add(RetryInterceptor(dio));
  dio.interceptors.add(LogInterceptor(
    requestBody: true,
    responseBody: true,
    logPrint: (obj) => print('[API] $obj'),
  ));

  return dio;
});

/// Provides secure storage for tokens.
final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
});

/// Token storage keys.
class TokenKeys {
  static const accessToken = 'access_token';
  static const refreshToken = 'refresh_token';
}

/// Interceptor that attaches JWT tokens and handles 401 refresh.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._ref);

  final Ref _ref;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Skip auth for login/register
    if (options.path.contains('/auth/login') ||
        options.path.contains('/auth/register')) {
      return handler.next(options);
    }

    final storage = _ref.read(secureStorageProvider);
    final token = await storage.read(key: TokenKeys.accessToken);

    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      // Attempt token refresh
      final storage = _ref.read(secureStorageProvider);
      final refreshToken = await storage.read(key: TokenKeys.refreshToken);

      if (refreshToken != null) {
        try {
          final dio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl));
          final response = await dio.post(
            ApiConstants.refresh,
            data: {'refresh_token': refreshToken},
          );

          if (response.statusCode == 200) {
            final data = response.data as Map<String, dynamic>;
            await storage.write(
              key: TokenKeys.accessToken,
              value: data['access_token'] as String,
            );
            await storage.write(
              key: TokenKeys.refreshToken,
              value: data['refresh_token'] as String,
            );

            // Retry original request
            final retryOptions = err.requestOptions;
            retryOptions.headers['Authorization'] =
                'Bearer ${data['access_token']}';

            final retryDio = _ref.read(dioProvider);
            final retryResponse = await retryDio.fetch(retryOptions);
            return handler.resolve(retryResponse);
          }
        } catch (_) {
          // Refresh failed — clear tokens
          await storage.delete(key: TokenKeys.accessToken);
          await storage.delete(key: TokenKeys.refreshToken);
        }
      }
    }

    handler.next(err);
  }
}

/// Interceptor that checks connectivity before launching requests.
class ConnectivityInterceptor extends Interceptor {
  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      return handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          error: 'No internet connection',
        ),
      );
    }
    handler.next(options);
  }
}

/// Interceptor that retries failed GET requests on timeouts.
class RetryInterceptor extends Interceptor {
  RetryInterceptor(this.dio);

  final Dio dio;
  final int maxRetries = 3;
  final int delayMs = 1500;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    final isGet = options.method.toUpperCase() == 'GET';
    final isTimeout = err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout;

    if (isGet && isTimeout) {
      final retries = (options.extra['retries'] as int? ?? 0);
      if (retries < maxRetries) {
        options.extra['retries'] = retries + 1;
        print('[API] Retrying request: ${options.path} (Attempt ${retries + 1} of $maxRetries)');
        await Future.delayed(Duration(milliseconds: delayMs * (retries + 1)));
        try {
          final response = await dio.fetch(options);
          return handler.resolve(response);
        } on DioException catch (retryErr) {
          return super.onError(retryErr, handler);
        }
      }
    }
    super.onError(err, handler);
  }
}

