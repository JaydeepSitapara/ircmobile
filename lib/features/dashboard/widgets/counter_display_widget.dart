import 'package:flutter/material.dart';

/// Displays the large animated reel count with a label beneath it.
class CounterDisplayWidget extends StatelessWidget {
  const CounterDisplayWidget({
    super.key,
    required this.count,
    this.label = 'Reels Watched',
  });

  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Animated count number.
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) => ScaleTransition(
            scale: animation,
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: Text(
            '$count',
            key: ValueKey<int>(count),
            style: textTheme.displayLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
              fontSize: 96,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: textTheme.titleMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
