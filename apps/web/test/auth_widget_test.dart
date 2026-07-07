/// Flutter widget tests for auth screens: Login, Register, ForgotPassword.
///
/// Uses ProviderScope overrides to inject mock repositories so no real
/// network calls are made. All navigation is asserted via GoRouter.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:wealthai/core/network/result.dart';
import 'package:wealthai/core/repositories/repositories.dart';
import 'package:wealthai/features/auth/screens/login_screen.dart';
import 'package:wealthai/features/auth/screens/register_screen.dart';
import 'package:wealthai/features/auth/screens/forgot_password_screen.dart';

// ─────────────────────────────────────────────
// Mocks
// ─────────────────────────────────────────────

class MockAuthRepository extends Mock implements AuthRepository {}

// Helper: wrap widget with ProviderScope + MaterialApp + GoRouter
Widget _wrap(
  Widget screen, {
  MockAuthRepository? authRepo,
  GoRouter? router,
}) {
  final repo = authRepo ?? MockAuthRepository();
  final go = router ??
      GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(path: '/', builder: (_, __) => screen),
          GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
          GoRoute(
              path: '/register', builder: (_, __) => const RegisterScreen()),
          GoRoute(
              path: '/forgot-password',
              builder: (_, __) => const ForgotPasswordScreen()),
          GoRoute(
              path: '/dashboard',
              builder: (_, __) => const Scaffold(body: Text('Dashboard'))),
          GoRoute(
              path: '/onboarding',
              builder: (_, __) => const Scaffold(body: Text('Onboarding'))),
        ],
      );

  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp.router(routerConfig: go),
  );
}

// ─────────────────────────────────────────────
// LoginScreen Tests
// ─────────────────────────────────────────────

void main() {
  group('LoginScreen', () {
    testWidgets('renders email, password fields and Sign In button',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_wrap(const LoginScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(TextFormField), findsAtLeastNWidgets(2));
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Forgot password?'), findsOneWidget);
    });

    testWidgets('shows validation errors on empty submit', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_wrap(const LoginScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your email'), findsOneWidget);
    });

    testWidgets('navigates to /forgot-password on link tap', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_wrap(const LoginScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('forgot_password_link')));
      await tester.pumpAndSettle();

      expect(find.text('Reset Password'), findsOneWidget);
    });
  });

  // ─────────────────────────────────────────────
  // RegisterScreen Tests
  // ─────────────────────────────────────────────

  group('RegisterScreen', () {
    testWidgets(
        'renders name, email, password fields and Create Account button',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_wrap(const RegisterScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(TextFormField), findsAtLeastNWidgets(3));
      expect(find.text('Create Account'), findsOneWidget);
    });

    testWidgets('shows terms error if checkbox not ticked', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final mock = MockAuthRepository();

      await tester.pumpWidget(_wrap(const RegisterScreen(), authRepo: mock));
      await tester.pumpAndSettle();

      // Fill all fields
      await tester.enterText(find.byType(TextFormField).at(0), 'Test User');
      await tester.enterText(
          find.byType(TextFormField).at(1), 'test@example.com');
      await tester.enterText(find.byType(TextFormField).at(2), 'Password123!');

      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();

      expect(find.text('Please agree to Terms & Conditions'), findsOneWidget);
    });
  });

  // ─────────────────────────────────────────────
  // ForgotPasswordScreen Tests
  // ─────────────────────────────────────────────

  group('ForgotPasswordScreen', () {
    testWidgets('renders email field and Send Reset Code button',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_wrap(const ForgotPasswordScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Reset Password'), findsOneWidget);
      expect(find.byKey(const Key('reset_email_field')), findsOneWidget);
      expect(find.byKey(const Key('send_reset_code_button')), findsOneWidget);
    });

    testWidgets('shows validation error for empty email', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_wrap(const ForgotPasswordScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('send_reset_code_button')));
      await tester.pumpAndSettle();

      expect(find.text('Enter your email'), findsOneWidget);
    });

    testWidgets('advances to step 2 after successful OTP request',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final mock = MockAuthRepository();
      when(() => mock.requestPasswordReset(any()))
          .thenAnswer((_) async => const Result.success('Code sent'));

      await tester
          .pumpWidget(_wrap(const ForgotPasswordScreen(), authRepo: mock));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('reset_email_field')), 'user@example.com');
      await tester.tap(find.byKey(const Key('send_reset_code_button')));
      await tester.pumpAndSettle();

      // Step 2 should now be visible
      expect(find.text('Enter Reset Code'), findsOneWidget);
      expect(find.byKey(const Key('reset_code_field')), findsOneWidget);
    });

    testWidgets('shows password mismatch error on step 2', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final mock = MockAuthRepository();
      when(() => mock.requestPasswordReset(any()))
          .thenAnswer((_) async => const Result.success('Code sent'));

      await tester
          .pumpWidget(_wrap(const ForgotPasswordScreen(), authRepo: mock));
      await tester.pumpAndSettle();

      // Step 1 — enter email
      await tester.enterText(
          find.byKey(const Key('reset_email_field')), 'user@example.com');
      await tester.tap(find.byKey(const Key('send_reset_code_button')));
      await tester.pumpAndSettle();

      // Step 2 — enter mismatched passwords
      await tester.enterText(
          find.byKey(const Key('reset_code_field')), '123456');
      await tester.enterText(
          find.byKey(const Key('reset_new_password_field')), 'Password1!');
      await tester.enterText(
          find.byKey(const Key('reset_confirm_password_field')), 'Different1!');

      await tester.tap(find.byKey(const Key('confirm_reset_button')));
      await tester.pumpAndSettle();

      expect(find.text('Passwords do not match'), findsOneWidget);
    });
  });
}
