import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/onboarding_wizard.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/portfolio/screens/portfolio_detail_screen.dart';
import '../../features/portfolio/screens/portfolio_list_screen.dart';
import '../../features/portfolio/screens/add_holding_screen.dart';
import '../../features/ai/screens/ai_chat_screen.dart';
import '../../features/ai/screens/recommendation_screen.dart';
import '../../features/market/screens/market_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/import/screens/import_screen.dart';
import '../../features/copilot/screens/copilot_screen.dart';
import '../../features/copilot/screens/portfolio_doctor_screen.dart';
import '../../features/copilot/screens/scenario_screen.dart';
import '../../features/copilot/screens/advanced_analysis_screen.dart';
import '../providers/auth_provider.dart';
import '../widgets/shell_scaffold.dart';

/// Splash / loading screen shown while checking stored token.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

/// Global router provider with auth guard redirect.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: false,
    refreshListenable: _AuthNotifierListenable(ref),
    redirect: (context, state) {
      final authStatus = ref.read(authStateProvider);
      final location = state.matchedLocation;

      // While loading, always go to splash.
      if (authStatus == AuthStatus.loading) {
        return location == '/splash' ? null : '/splash';
      }

      final isOnAuthRoute = location == '/login' ||
          location == '/register' ||
          location == '/splash';

      // Unauthenticated — send to login (unless already there).
      if (authStatus == AuthStatus.unauthenticated) {
        return isOnAuthRoute ? null : '/login';
      }

      // Needs onboarding — send to onboarding wizard.
      if (authStatus == AuthStatus.onboarding) {
        return location == '/onboarding' ? null : '/onboarding';
      }

      // Authenticated — redirect away from auth routes.
      if (authStatus == AuthStatus.authenticated && isOnAuthRoute) {
        return '/dashboard';
      }

      return null;
    },
    routes: [
      // Splash
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const _SplashScreen(),
      ),

      // Auth routes (no shell)
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingWizardScreen(),
      ),

      // Main app routes with shell scaffold
      ShellRoute(
        builder: (context, state, child) => ShellScaffold(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            name: 'dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/portfolios',
            name: 'portfolios',
            builder: (context, state) => const PortfolioListScreen(),
            routes: [
              GoRoute(
                path: ':portfolioId',
                name: 'portfolio-detail',
                builder: (context, state) => PortfolioDetailScreen(
                  portfolioId: state.pathParameters['portfolioId']!,
                ),
                routes: [
                  GoRoute(
                    path: 'add-holding',
                    name: 'add-holding',
                    builder: (context, state) => AddHoldingScreen(
                      portfolioId: state.pathParameters['portfolioId']!,
                    ),
                  ),
                  GoRoute(
                    path: 'recommendation/:holdingId',
                    name: 'recommendation',
                    builder: (context, state) => RecommendationScreen(
                      portfolioId: state.pathParameters['portfolioId']!,
                      holdingId: state.pathParameters['holdingId']!,
                    ),
                  ),
                  GoRoute(
                    path: 'import',
                    name: 'portfolio-import',
                    builder: (context, state) => ImportScreen(
                      portfolioId: state.pathParameters['portfolioId']!,
                    ),
                  ),
                  GoRoute(
                    path: 'doctor',
                    name: 'portfolio-doctor',
                    builder: (context, state) => PortfolioDoctorScreen(
                      portfolioId: state.pathParameters['portfolioId']!,
                    ),
                  ),
                  GoRoute(
                    path: 'scenario',
                    name: 'portfolio-scenario',
                    builder: (context, state) => ScenarioScreen(
                      portfolioId: state.pathParameters['portfolioId']!,
                    ),
                  ),
                  GoRoute(
                    path: 'advanced-analysis',
                    name: 'portfolio-advanced-analysis',
                    builder: (context, state) => AdvancedAnalysisScreen(
                      portfolioId: state.pathParameters['portfolioId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/copilot',
            name: 'copilot',
            builder: (context, state) => const CopilotScreen(),
          ),
          GoRoute(
            path: '/ai-chat',
            name: 'ai-chat',
            builder: (context, state) => const AIChatScreen(),
          ),
          GoRoute(
            path: '/market',
            name: 'market',
            builder: (context, state) => const MarketScreen(),
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Page not found',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(state.uri.toString()),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/dashboard'),
              child: const Text('Go to Dashboard'),
            ),
          ],
        ),
      ),
    ),
  );
});

/// Listenable that triggers router refresh when auth state changes.
class _AuthNotifierListenable extends ChangeNotifier {
  _AuthNotifierListenable(this._ref) {
    _ref.listen<AuthStatus>(authStateProvider, (_, __) {
      notifyListeners();
    });
  }

  final Ref _ref;
}
