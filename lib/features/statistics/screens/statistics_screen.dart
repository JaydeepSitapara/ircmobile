import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/models/reels_stats.dart';
import '../../dashboard/providers/reels_counter_provider.dart';

/// Shows statistical analysis: 4-card overview, 7-day BarChart, and
/// detailed activity metrics (Average per recorded day, Highest day, Days tracked).
class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics'),
        centerTitle: false,
      ),
      body: Consumer<ReelsCounterProvider>(
        builder: (context, provider, _) {
          return FutureBuilder<ReelsStats>(
            future: provider.getStats(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !provider.initialized) {
                return const Center(child: CircularProgressIndicator());
              }

              final stats = snapshot.data ?? ReelsStats.empty();

              if (stats.total == 0 && stats.today == 0) {
                return const _EmptyStatsView();
              }

              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  _SummaryGrid(stats: stats),
                  const SizedBox(height: 28),
                  _SectionHeader(title: 'Last 7 Days Activity'),
                  const SizedBox(height: 16),
                  _WeeklyBarChart(stats: stats),
                  const SizedBox(height: 28),
                  _SectionHeader(title: 'Activity Insights'),
                  const SizedBox(height: 14),
                  _InsightsSection(stats: stats),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.stats});

  final ReelsStats stats;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.55,
      children: [
        _StatCard(label: 'Today', value: stats.today, icon: Icons.today_outlined),
        _StatCard(label: 'Last 7 Days', value: stats.weekly, icon: Icons.date_range_outlined),
        _StatCard(label: 'Last 30 Days', value: stats.monthly, icon: Icons.calendar_month_outlined),
        _StatCard(label: 'All Time', value: stats.total, icon: Icons.all_inclusive),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withAlpha(90),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Icon(icon, size: 18, color: colorScheme.primary.withAlpha(160)),
            ],
          ),
          Text(
            NumberFormat.decimalPattern().format(value),
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyBarChart extends StatelessWidget {
  const _WeeklyBarChart({required this.stats});

  final ReelsStats stats;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final days = stats.last7Days;

    final maxValue = days.isEmpty
        ? 0
        : days.map((e) => e.count).fold<int>(0, (a, b) => a > b ? a : b);
    final maxY = (maxValue < 10 ? 10.0 : (maxValue * 1.25)).ceilToDouble();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withAlpha(80),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withAlpha(50)),
      ),
      child: SizedBox(
        height: 200,
        child: BarChart(
          BarChartData(
            maxY: maxY,
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => colorScheme.inverseSurface,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final day = days[group.x];
                  return BarTooltipItem(
                    '${rod.toY.toInt()} Reels\n',
                    TextStyle(
                      color: colorScheme.onInverseSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    children: [
                      TextSpan(
                        text: day.shortFormattedDate,
                        style: TextStyle(
                          color: colorScheme.onInverseSurface.withAlpha(180),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              show: true,
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index < 0 || index >= days.length) {
                      return const SizedBox.shrink();
                    }
                    final isToday = index == days.length - 1;
                    final label = isToday ? 'Today' : days[index].weekdayAbbr;

                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                          color: isToday ? colorScheme.primary : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  },
                  reservedSize: 28,
                ),
              ),
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(
                color: colorScheme.outlineVariant.withAlpha(80),
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(show: false),
            barGroups: List.generate(days.length, (i) {
              final isToday = i == days.length - 1;
              return BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: days[i].count.toDouble(),
                    color: isToday ? colorScheme.primary : colorScheme.primary.withAlpha(120),
                    width: 20,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _InsightsSection extends StatelessWidget {
  const _InsightsSection({required this.stats});

  final ReelsStats stats;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final avgStr = stats.averagePerRecordedDay > 0
        ? '${stats.averagePerRecordedDay.toStringAsFixed(1)} Reels / day'
        : '—';

    final highestStr = stats.highestDay != null
        ? '${NumberFormat.decimalPattern().format(stats.highestDay!.count)} Reels (${stats.highestDay!.shortFormattedDate})'
        : '—';

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withAlpha(80),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withAlpha(50)),
      ),
      child: Column(
        children: [
          _InsightTile(
            icon: Icons.speed_outlined,
            title: 'Daily Average',
            subtitle: 'Average on recorded days with activity',
            value: avgStr,
          ),
          Divider(height: 1, indent: 56, color: colorScheme.outlineVariant.withAlpha(60)),
          _InsightTile(
            icon: Icons.emoji_events_outlined,
            title: 'Highest Day',
            subtitle: 'Most Reels watched in a single day',
            value: highestStr,
          ),
          Divider(height: 1, indent: 56, color: colorScheme.outlineVariant.withAlpha(60)),
          _InsightTile(
            icon: Icons.calendar_today_outlined,
            title: 'Days Tracked',
            subtitle: 'Days with recorded tracking activity',
            value: '${stats.daysTracked} days',
          ),
        ],
      ),
    );
  }
}

class _InsightTile extends StatelessWidget {
  const _InsightTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.primary.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: colorScheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  subtitle,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyStatsView extends StatelessWidget {
  const _EmptyStatsView();

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
                Icons.insights_outlined,
                size: 48,
                color: colorScheme.outline,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Not enough data yet',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start watching Instagram Reels to build your viewing trends and statistics.',
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
