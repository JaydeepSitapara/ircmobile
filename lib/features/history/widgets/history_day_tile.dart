import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// A single row in the History list showing a date label and reel count.
class HistoryDayTile extends StatelessWidget {
  const HistoryDayTile({
    super.key,
    required this.date,
    required this.count,
    this.isToday = false,
  });

  final DateTime date;
  final int count;

  /// Marks this tile as today's entry so it can be styled differently.
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final dateLabel = _dateLabel(date, isToday);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isToday
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.play_circle_outline,
          color: isToday
              ? colorScheme.onPrimaryContainer
              : colorScheme.onSurfaceVariant,
        ),
      ),
      title: Text(
        dateLabel,
        style: textTheme.bodyLarge?.copyWith(
          fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
          color: colorScheme.onSurface,
        ),
      ),
      trailing: Text(
        '$count ${count == 1 ? 'Reel' : 'Reels'}',
        style: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: colorScheme.primary,
        ),
      ),
    );
  }

  static String _dateLabel(DateTime date, bool isToday) {
    if (isToday) return 'Today';

    final yesterday =
        DateTime.now().subtract(const Duration(days: 1));
    if (date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day) {
      return 'Yesterday';
    }

    return DateFormat('EEE, MMM d').format(date);
  }
}
