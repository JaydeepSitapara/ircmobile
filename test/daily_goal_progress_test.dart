import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ircmobile/features/dashboard/widgets/daily_goal_progress.dart';

void main() {
  testWidgets('DailyGoalProgress displays counts and progress accurately', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DailyGoalProgress(
            todayCount: 100,
            dailyGoal: 200,
          ),
        ),
      ),
    );

    expect(find.text('Daily Goal'), findsOneWidget);
    expect(find.text('100 / 200'), findsOneWidget);
    expect(find.text('100 more Reels to reach goal'), findsOneWidget);

    final progressIndicator = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(progressIndicator.value, 0.5);
  });

  testWidgets('DailyGoalProgress displays goal reached when exceeding goal', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DailyGoalProgress(
            todayCount: 250,
            dailyGoal: 200,
          ),
        ),
      ),
    );

    expect(find.text('250 / 200'), findsOneWidget);
    expect(find.text('Daily goal reached! 🎉'), findsOneWidget);

    final progressIndicator = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    // Value clamped to 1.0
    expect(progressIndicator.value, 1.0);
  });
}
