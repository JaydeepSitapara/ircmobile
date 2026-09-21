import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/models/daily_reel_count.dart';
import '../../dashboard/providers/reels_counter_provider.dart';

/// Displays the full per-day Reel count history, newest first.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        centerTitle: false,
      ),
      body: Consumer<ReelsCounterProvider>(
        builder: (context, provider, _) {
          return FutureBuilder<List<DailyReelCount>>(
            future: provider.getHistoryList(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !provider.initialized) {
                return const Center(child: CircularProgressIndicator());
              }

              final history = snapshot.data ?? [];
              final filteredHistory = history.where((d) => d.count > 0 || _isToday(d.date)).toList();

              if (filteredHistory.isEmpty) {
                return const _EmptyHistoryView();
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                itemCount: filteredHistory.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final record = filteredHistory[index];
                  final isToday = _isToday(record.date);

                  return _HistoryCard(
                    record: record,
                    isToday: isToday,
                    dailyGoal: provider.dailyGoal,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  static bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.record,
    required this.isToday,
    required this.dailyGoal,
  });

  final DailyReelCount record;
  final bool isToday;
  final int dailyGoal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final goalMet = record.count >= dailyGoal && dailyGoal > 0;
    final formattedNum = NumberFormat.decimalPattern().format(record.count);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isToday
            ? colorScheme.primaryContainer.withAlpha(80)
            : colorScheme.surfaceContainerHighest.withAlpha(90),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isToday
              ? colorScheme.primary.withAlpha(120)
              : colorScheme.outlineVariant.withAlpha(60),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isToday
                  ? colorScheme.primary.withAlpha(30)
                  : colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isToday ? Icons.today : Icons.history,
              size: 20,
              color: isToday ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      record.relativeLabel,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isToday ? colorScheme.primary : colorScheme.onSurface,
                      ),
                    ),
                    if (isToday) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'LIVE',
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.onPrimary,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  record.shortFormattedDate,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formattedNum,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: goalMet ? colorScheme.tertiary : colorScheme.onSurface,
                ),
              ),
              Text(
                'Reels',
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyHistoryView extends StatelessWidget {
  const _EmptyHistoryView();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withAlpha(120),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.calendar_today_outlined,
                size: 48,
                color: colorScheme.outline,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No history yet',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your daily Reel viewing activity will automatically appear here once tracking starts.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
