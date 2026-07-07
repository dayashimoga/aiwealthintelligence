import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shimmer/shimmer.dart';
import 'package:wealthai/core/widgets/common_widgets.dart';

void main() {
  testWidgets('StatCard renders label, value and change indicators',
      (WidgetTester tester) async {
    // Build StatCard
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StatCard(
            label: 'Total Valuation',
            value: '₹1,50,000',
            change: '+5.5%',
            changePositive: true,
            icon: Icons.trending_up,
          ),
        ),
      ),
    );

    // Wait for animations to settle
    await tester.pumpAndSettle();

    // Verify label and value render
    expect(find.text('Total Valuation'), findsOneWidget);
    expect(find.text('₹1,50,000'), findsOneWidget);
    expect(find.text('+5.5%'), findsOneWidget);
    expect(find.byIcon(Icons.trending_up),
        findsNWidgets(2)); // Card icon + change trend icon
  });

  testWidgets('RecommendationChip renders correct styled label text',
      (WidgetTester tester) async {
    // Build strong buy chip
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RecommendationChip(
            action: 'strong_buy',
            confidence: 92.5,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('STRONG BUY'), findsOneWidget);
  });

  testWidgets('SkeletonLoader renders shimmer content placeholder',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SkeletonLoader(
            width: 120,
            height: 24,
          ),
        ),
      ),
    );

    // The shimmer package might run a continuous looping animation, which pumpAndSettle would wait for indefinitely.
    // So we just pump one frame to verify structure rather than pumpAndSettle.
    await tester.pump(const Duration(milliseconds: 100));

    // Find Shimmer widget
    expect(find.byType(Shimmer), findsOneWidget);
  });
}
