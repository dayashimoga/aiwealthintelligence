import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../network/api_client.dart';
import '../repositories/repositories.dart';

/// Authentication states the app can be in.
enum AuthStatus {
  /// Still checking secure storage for a token (splash).
  loading,

  /// No token found — user must log in.
  unauthenticated,

  /// Valid token found and user is onboarded.
  authenticated,

  /// Valid token but user has not completed onboarding.
  onboarding,
}

/// Global auth state — drives router redirect.
final authStateProvider = StateNotifierProvider<AuthNotifier, AuthStatus>((ref) {
  return AuthNotifier(ref.read(secureStorageProvider), ref);
});

class AuthNotifier extends StateNotifier<AuthStatus> {
  AuthNotifier(this._storage, this._ref) : super(AuthStatus.loading) {
    revalidate();
  }

  final FlutterSecureStorage _storage;
  final Ref _ref;

  /// Called on startup or after biometric unlock — reads persisted token and validates it.
  Future<void> revalidate() async {
    final token = await _storage.read(key: TokenKeys.accessToken);
    if (token == null || token.isEmpty) {
      state = AuthStatus.unauthenticated;
      return;
    }

    // Validate token by fetching profile (also warms up cache).
    final result = await _ref.read(authRepositoryProvider).getProfile();
    result.when(
      success: (user) {
        state = user.isOnboarded ? AuthStatus.authenticated : AuthStatus.onboarding;
      },
      failure: (_, __) {
        // Token expired or invalid — clear it.
        _storage.delete(key: TokenKeys.accessToken);
        _storage.delete(key: TokenKeys.refreshToken);
        state = AuthStatus.unauthenticated;
      },
    );
  }

  /// Call after successful login to update auth state.
  Future<void> setAuthenticated({bool onboarded = true}) async {
    state = onboarded ? AuthStatus.authenticated : AuthStatus.onboarding;
  }

  /// Completes onboarding and moves to authenticated.
  void completeOnboarding() {
    state = AuthStatus.authenticated;
  }

  /// Logs out: clears tokens and resets state.
  Future<void> logout() async {
    await _ref.read(authRepositoryProvider).logout();
    await _storage.delete(key: TokenKeys.accessToken);
    await _storage.delete(key: TokenKeys.refreshToken);
    state = AuthStatus.unauthenticated;
  }
}
