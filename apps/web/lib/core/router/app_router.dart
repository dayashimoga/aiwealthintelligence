import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
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
import '../widgets/shell_scaffold.dart';

/// Global router provider.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/dashboard',
    debugLogDiagnostics: true,
    routes: [
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
