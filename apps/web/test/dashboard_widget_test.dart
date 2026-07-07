/// Widget tests for DashboardScreen.
///
/// Tests loading state, portfolio-loaded state, empty state.
/// Uses ProviderScope overrides to inject mock data — no real network calls.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import 'package:wealthai/core/models/models.dart';
import 'package:wealthai/core/providers/portfolio_providers.dart';
import 'package:wealthai/features/dashboard/screens/dashboard_screen.dart';

// ─────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────

Portfolio _mockPortfolio({String id = 'p1', String name = 'Test Portfolio'}) => Portfolio(
      id: id,
      name: name,
      description: 'My test portfolio',
      currency: 'INR',
      totalInvested: 90000,
      totalCurrentValue: 100000,
      totalGainLoss: 10000,
      totalGainLossPct: 11.1,
    );

PortfolioAnalytics _mockAnalytics() => const PortfolioAnalytics(
      portfolioId: 'p1',
      totalInvested: 90000,
      totalCurrentValue: 100000,
      totalGainLoss: 10000,
      totalGainLossPct: 11.1,
      holdingCount: 3,
      diversificationScore: 72,
      riskScore: 40,
      aiHealthScore: 85,
      sectorAllocation: {'Tech': 40, 'Finance': 35, 'Energy': 25},
    );

Widget _wrapDashboard({List<Override> overrides = const []}) {
  final router = GoRouter(
    initialLocation: '/dashboard',
    routes: [
      GoRoute(
        path: '/dashboard',
        builder: (_, __) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/portfolios',
        builder: (_, __) => const Scaffold(body: Text('Portfolios')),
      ),
    ],
  );

  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  group('DashboardScreen', () {
    testWidgets('shows shimmer/loading state while portfolios are loading', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrapDashboard(
          overrides: [
            // portfoliosProvider in loading state (stream never emits)
            portfoliosProvider.overrideWith(
              (ref) => Stream<List<Portfolio>>.empty(),
            ),
          ],
        ),
      );

      // Just pump once — shows loading state
      await tester.pump();

      // Shimmer or CircularProgressIndicator should be visible during loading
      final hasShimmer = find.byType(Shimmer).evaluate().isNotEmpty;
      final hasProgress = find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
      expect(hasShimmer || hasProgress, isTrue,
          reason: 'Expected shimmer or progress indicator during loading');
    });

    testWidgets('shows portfolio name when loaded', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final mockPortfolio = _mockPortfolio();
      final mockAnalytics = _mockAnalytics();

      await tester.pumpWidget(
        _wrapDashboard(
          overrides: [
            portfoliosProvider.overrideWith(
              (ref) => Stream.value([mockPortfolio]),
            ),
            selectedPortfolioIdProvider.overrideWith((ref) => 'p1'),
            portfolioAnalyticsProvider.overrideWith(
              (ref) => Stream.value(mockAnalytics),
            ),
            holdingsProvider.overrideWith(
              (ref) => Stream.value([]),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Portfolio name should appear somewhere in the dashboard
      expect(find.textContaining('Test Portfolio'), findsWidgets);
    });

    testWidgets('shows portfolio-related content when no portfolios exist', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrapDashboard(
          overrides: [
            portfoliosProvider.overrideWith(
              (ref) => Stream.value([]),
            ),
            selectedPortfolioIdProvider.overrideWith((ref) => null),
            portfolioAnalyticsProvider.overrideWith(
              (ref) => Stream.value(null),
            ),
            holdingsProvider.overrideWith(
              (ref) => Stream.value([]),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Dashboard should show something about portfolios or create prompt
      final hasPortfolioText =
          find.textContaining('portfolio', findRichText: true).evaluate().isNotEmpty ||
              find.textContaining('Portfolio').evaluate().isNotEmpty ||
              find.textContaining('Create').evaluate().isNotEmpty;
      expect(hasPortfolioText, isTrue);
    });
  });
}
