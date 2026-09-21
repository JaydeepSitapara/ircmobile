import 'package:flutter/material.dart';

/// Reusable widget displaying daily goal progress with animated linear progress
/// and goal milestone status.
class DailyGoalProgress extends StatelessWidget {
  const DailyGoalProgress({
    super.key,
    required this.todayCount,
    required this.dailyGoal,
  });

  final int todayCount;
  final int dailyGoal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final validGoal = dailyGoal > 0 ? dailyGoal : 1;
    final progress = (todayCount / validGoal).clamp(0.0, 1.0);
    final goalMet = todayCount >= validGoal;

    final progressColor = goalMet ? colorScheme.tertiary : colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withAlpha(120),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: goalMet
              ? colorScheme.tertiary.withAlpha(100)
              : colorScheme.outlineVariant.withAlpha(60),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Daily Goal',
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              Semantics(
                label: '$todayCount of $dailyGoal Reels watched',
                child: Text(
                  '$todayCount / $dailyGoal',
                  style: textTheme.bodyMedium?.copyWith(
                    color: progressColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            goalMet
                ? 'Daily goal reached! 🎉'
                : '${validGoal - todayCount} more Reels to reach goal',
            style: textTheme.bodySmall?.copyWith(
              color: goalMet ? colorScheme.tertiary : colorScheme.onSurfaceVariant,
              fontWeight: goalMet ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
