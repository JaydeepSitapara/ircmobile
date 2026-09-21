import 'package:flutter/material.dart';

/// Linear progress bar showing [current] vs [goal] with a text label.
class GoalProgressWidget extends StatelessWidget {
  const GoalProgressWidget({
    super.key,
    required this.current,
    required this.goal,
  });

  final int current;
  final int goal;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final progress = goal > 0 ? (current / goal).clamp(0.0, 1.0) : 0.0;
    final isComplete = current >= goal && goal > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Daily Goal',
              style: textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              '$current / $goal',
              style: textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: isComplete
                    ? colorScheme.tertiary
                    : colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            backgroundColor: colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(
              isComplete ? colorScheme.tertiary : colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}
