import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/reels_counter_provider.dart';
import '../widgets/counter_display_widget.dart';
import '../widgets/daily_goal_progress.dart';
import '../widgets/status_chip_widget.dart';

/// Main production dashboard showing live Reel counter, daily goal progress,
/// activity summary cards, and native status indicators.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reels Counter'),
        centerTitle: false,
        actions: [
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'Debug: add reel',
              onPressed: () {
                context.read<ReelsCounterProvider>().debugIncrement();
              },
            ),
        ],
      ),
      body: Consumer<ReelsCounterProvider>(
        builder: (context, provider, _) {
          if (!provider.initialized) {
            return const Center(child: CircularProgressIndicator());
          }
          return _DashboardBody(provider: provider);
        },
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.provider});

  final ReelsCounterProvider provider;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => provider.refreshOnResume(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          // Large Counter Section
          _CounterSection(provider: provider),
          const SizedBox(height: 24),

          // Daily Goal Progress Widget
          DailyGoalProgress(
            todayCount: provider.todayCount,
            dailyGoal: provider.dailyGoal,
          ),
          const SizedBox(height: 24),

          // 4-Card Summary Grid
          _SummaryGrid(provider: provider),
          const SizedBox(height: 24),

          // Native Tracking & Overlay Status
          _StatusSection(provider: provider),
          const SizedBox(height: 20),

          // Permission Alert Banners
          if (!provider.accessibilityEnabled) ...[
            _AccessibilityAlertBanner(provider: provider),
            const SizedBox(height: 12),
          ],
          if (provider.overlayEnabled && !provider.overlayPermissionGranted) ...[
            _OverlayAlertBanner(provider: provider),
            const SizedBox(height: 12),
          ],

          // Native Debug Panel (visible only in debug builds)
          if (kDebugMode) ...[
            const SizedBox(height: 16),
            _NativeDebugPanel(provider: provider),
          ],
        ],
      ),
    );
  }
}

class _CounterSection extends StatelessWidget {
  const _CounterSection({required this.provider});

  final ReelsCounterProvider provider;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateLabel = DateFormat('EEEE, MMMM d').format(now);

    return Column(
      children: [
        const SizedBox(height: 8),
        Text(
          dateLabel,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 8),
        Semantics(
          label: '${provider.todayCount} Reels Watched Today',
          child: CounterDisplayWidget(count: provider.todayCount),
        ),
      ],
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.provider});

  final ReelsCounterProvider provider;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withAlpha(80),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withAlpha(50)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _SummaryCell(
                  label: 'Today',
                  value: provider.todayCount,
                  icon: Icons.today_outlined,
                ),
              ),
              Container(
                height: 40,
                width: 1,
                color: colorScheme.outlineVariant.withAlpha(80),
              ),
              Expanded(
                child: _SummaryCell(
                  label: 'This Week',
                  value: provider.weeklyTotal,
                  icon: Icons.date_range_outlined,
                ),
              ),
            ],
          ),
          Divider(height: 24, color: colorScheme.outlineVariant.withAlpha(80)),
          Row(
            children: [
              Expanded(
                child: _SummaryCell(
                  label: 'This Month',
                  value: provider.monthlyTotal,
                  icon: Icons.calendar_month_outlined,
                ),
              ),
              Container(
                height: 40,
                width: 1,
                color: colorScheme.outlineVariant.withAlpha(80),
              ),
              Expanded(
                child: _SummaryCell(
                  label: 'All Time',
                  value: provider.totalCount,
                  icon: Icons.all_inclusive,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryCell extends StatelessWidget {
  const _SummaryCell({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final formatter = NumberFormat.decimalPattern();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colorScheme.primary.withAlpha(180)),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formatter.format(value),
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              Text(
                label,
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

class _StatusSection extends StatelessWidget {
  const _StatusSection({required this.provider});

  final ReelsCounterProvider provider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Live Tracking Status',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatusChipWidget(
              label: provider.trackingEnabled ? 'Tracking Active' : 'Tracking Inactive',
              active: provider.trackingEnabled,
            ),
            StatusChipWidget(
              label: provider.overlayEnabled ? 'Floating Counter Active' : 'Floating Counter Inactive',
              active: provider.overlayEnabled,
            ),
            StatusChipWidget(
              label: provider.accessibilityEnabled ? 'Accessibility Ready' : 'Accessibility Off',
              active: provider.accessibilityEnabled,
            ),
          ],
        ),
      ],
    );
  }
}

class _AccessibilityAlertBanner extends StatelessWidget {
  const _AccessibilityAlertBanner({required this.provider});

  final ReelsCounterProvider provider;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withAlpha(150),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.error.withAlpha(80)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.accessibility_new, color: colorScheme.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Accessibility Permission Required',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: colorScheme.onErrorContainer,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Enable the Reels Counter Accessibility service so the app can track when you watch Instagram Reels.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onErrorContainer,
                      ),
                ),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: provider.openAccessibilitySettings,
                  child: const Text('Open Settings'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OverlayAlertBanner extends StatelessWidget {
  const _OverlayAlertBanner({required this.provider});

  final ReelsCounterProvider provider;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.tertiaryContainer.withAlpha(150),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.tertiary.withAlpha(80)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.picture_in_picture_outlined, color: colorScheme.onTertiaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Overlay Permission Required',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: colorScheme.onTertiaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Grant "Display over other apps" permission to show the floating counter on top of Instagram.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onTertiaryContainer,
                      ),
                ),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: provider.openOverlaySettings,
                  child: const Text('Grant Permission'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NativeDebugPanel extends StatelessWidget {
  const _NativeDebugPanel({required this.provider});

  final ReelsCounterProvider provider;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bug_report_outlined, size: 16, color: colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                'Native Tracking Debug',
                style: textTheme.labelLarge?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _DebugRow(
            label: 'Package',
            value: provider.instagramDetected ? 'com.instagram.android' : '—',
            active: provider.instagramDetected,
          ),
          _DebugRow(
            label: 'State',
            value: provider.lastNativeState.isEmpty ? 'NOT_INSTAGRAM' : provider.lastNativeState,
          ),
          _DebugRow(
            label: 'Screen',
            value: provider.reelsScreenActive ? 'Reels ●' : '—',
            active: provider.reelsScreenActive,
          ),
          _DebugRow(
            label: 'Fingerprint',
            value: provider.lastFingerprint.isEmpty ? '—' : provider.lastFingerprint,
          ),
          _DebugRow(
            label: 'Confidence',
            value: '${provider.detectionConfidence} / 3',
          ),
          _DebugRow(
            label: 'Native events',
            value: '${provider.nativeEventCount}',
          ),
          _DebugRow(
            label: "Today's count",
            value: '${provider.todayCount}',
          ),
        ],
      ),
    );
  }
}

class _DebugRow extends StatelessWidget {
  const _DebugRow({
    required this.label,
    required this.value,
    this.active,
  });

  final String label;
  final String value;
  final bool? active;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final valueColor = active == null
        ? colorScheme.onSurfaceVariant
        : active!
            ? colorScheme.tertiary
            : colorScheme.outline;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: textTheme.labelSmall?.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
