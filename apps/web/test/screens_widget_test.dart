import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:wealthai/core/models/models.dart';
import 'package:wealthai/core/providers/portfolio_providers.dart';
import 'package:wealthai/features/dashboard/screens/dashboard_screen.dart';
import 'package:wealthai/features/settings/screens/settings_screen.dart';
import 'package:wealthai/features/copilot/screens/advanced_analysis_screen.dart';

void main() {
  testWidgets('HealthRingWidget renders score and EXCELLENT label', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: HealthRingWidget(score: 85.0),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('85'), findsOneWidget);
    expect(find.text('EXCELLENT'), findsOneWidget);
  });

  testWidgets('RiskGaugeWidget renders label range and needle', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RiskGaugeWidget(score: 45.0),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('MODERATE'), findsOneWidget);
    expect(find.text('Portfolio Risk'), findsOneWidget);
  });

  testWidgets('SettingsScreen mock profile state bindings', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final mockUser = User(
      id: 'usr-123',
      email: 'test@wealthai.app',
      fullName: 'Test User',
      role: 'user',
      isVerified: true,
      mfaEnabled: false,
      passkeys: const [],
      trustedDevices: const [],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userProfileProvider.overrideWith((ref) => Stream.value(mockUser)),
        ],
        child: const MaterialApp(
          home: SettingsScreen(),
        ),
      ),
    );

    // Let Stream emit mock User data
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();

    // Verify profile details display
    expect(find.text('Test User'), findsOneWidget);
    expect(find.text('test@wealthai.app'), findsOneWidget);
    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Passkeys'), findsOneWidget);
    expect(find.text('Two-Factor Authentication'), findsOneWidget);
  });

  testWidgets('AdvancedAnalysisScreen renders stress tests and goals tabs', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final mockAnalysis = AdvancedAnalysis(
      portfolioId: 'port-1',
      stressTest: const [
        StressScenarioResult(
          scenarioName: 'Inflation Spike',
          scenarioDescription: 'Rate hike scenario',
          estimatedNewValue: 85000,
          changeValue: -15000,
          changePercentage: -15,
          impactLevel: 'moderate',
        )
      ],
      taxHarvesting: const [],
      totalPotentialTaxSavings: 1500,
      behavioralBiases: const [],
      goals: const [
        GoalProgress(
          goalName: 'Retirement fund',
          targetAmount: 5000000,
          currentAmount: 1200000,
          progressPercentage: 24,
          status: 'on_track',
        )
      ],
      calculatedAt: DateTime.now(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          advancedAnalysisProvider.overrideWith((ref) => Future.value(mockAnalysis)),
        ],
        child: const MaterialApp(
          home: AdvancedAnalysisScreen(portfolioId: 'port-1'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Tab titles render
    expect(find.text('Stress Tests'), findsOneWidget);
    expect(find.text('Inflation Spike'), findsOneWidget);
    expect(find.text('Retirement fund'), findsNothing); // goal content is in goal tab view

    // Switch to Goals Tab
    await tester.tap(find.text('Goals'));
    await tester.pumpAndSettle();

    expect(find.text('Retirement fund'), findsOneWidget);
  });
}
