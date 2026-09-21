import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/constants.dart';
import '../../dashboard/providers/reels_counter_provider.dart';

/// Production Settings screen with sections for Tracking, Overlay, Goals,
/// Data management (Reset Today, Clear History), and Privacy / About.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: false,
      ),
      body: Consumer<ReelsCounterProvider>(
        builder: (context, provider, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
            children: [
              _SectionLabel(label: 'Tracking'),
              _TrackingTile(provider: provider),
              const Divider(height: 1, indent: 16),
              _AccessibilityTile(provider: provider),
              const Divider(height: 1, indent: 16),

              _SectionLabel(label: 'Floating Overlay'),
              _OverlayTile(provider: provider),
              const Divider(height: 1, indent: 16),

              _SectionLabel(label: 'Goals'),
              _GoalTile(provider: provider),
              const Divider(height: 1, indent: 16),

              _SectionLabel(label: 'Data & Reset'),
              _ResetTodayTile(provider: provider),
              const Divider(height: 1, indent: 16),
              _ClearHistoryTile(provider: provider),
              const Divider(height: 1, indent: 16),

              _SectionLabel(label: 'About & Privacy'),
              _PrivacyTile(),
              const Divider(height: 1, indent: 16),
              _AboutTile(),
              const Divider(height: 1, indent: 16),
              _VersionTile(),
            ],
          );
        },
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

class _TrackingTile extends StatelessWidget {
  const _TrackingTile({required this.provider});

  final ReelsCounterProvider provider;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: const Text('Reel Tracking'),
      subtitle: Text(
        provider.trackingEnabled
            ? 'Counting Reels while Instagram is open.'
            : 'Tracking is disabled.',
      ),
      secondary: const Icon(Icons.track_changes_outlined),
      value: provider.trackingEnabled,
      onChanged: (value) async {
        if (value && !provider.accessibilityEnabled) {
          _showAccessibilityDialog(context, provider);
          return;
        }
        await provider.setTrackingEnabled(value);
      },
    );
  }

  void _showAccessibilityDialog(
    BuildContext context,
    ReelsCounterProvider provider,
  ) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.accessibility_new),
        title: const Text('Accessibility Access Required'),
        content: const Text(
          'To count Instagram Reels, enable the Reels Counter '
          'Accessibility Service in Android settings.\n\n'
          'This permission is only used to detect Reel transitions — '
          'no personal data or messages are read or stored.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              provider.openAccessibilitySettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}

class _AccessibilityTile extends StatelessWidget {
  const _AccessibilityTile({required this.provider});

  final ReelsCounterProvider provider;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: const Icon(Icons.accessibility_new_outlined),
      title: const Text('Accessibility Permission'),
      subtitle: Row(
        children: [
          Icon(
            Icons.circle,
            size: 8,
            color: provider.accessibilityEnabled
                ? colorScheme.tertiary
                : colorScheme.outline,
          ),
          const SizedBox(width: 6),
          Text(
            provider.accessibilityEnabled ? 'Granted & Ready' : 'Permission Missing',
            style: TextStyle(
              color: provider.accessibilityEnabled
                  ? colorScheme.tertiary
                  : colorScheme.outline,
            ),
          ),
        ],
      ),
      trailing: TextButton(
        onPressed: provider.openAccessibilitySettings,
        child: const Text('Configure'),
      ),
    );
  }
}

class _OverlayTile extends StatelessWidget {
  const _OverlayTile({required this.provider});

  final ReelsCounterProvider provider;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: const Text('Floating Counter'),
      subtitle: Text(
        provider.overlayEnabled
            ? 'Floating pill shown on top of Instagram Reels.'
            : 'Floating overlay is hidden.',
      ),
      secondary: const Icon(Icons.picture_in_picture_outlined),
      value: provider.overlayEnabled,
      onChanged: (value) async {
        if (value && !provider.overlayPermissionGranted) {
          _showOverlayPermissionDialog(context, provider);
          return;
        }
        await provider.setOverlayEnabled(value);
      },
    );
  }

  void _showOverlayPermissionDialog(
    BuildContext context,
    ReelsCounterProvider provider,
  ) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.picture_in_picture),
        title: const Text('"Display over other apps" Required'),
        content: const Text(
          'To show the floating Reel counter while Instagram is open, '
          'grant the "Display over other apps" permission in system settings.\n\n'
          'The overlay is draggable and only appears when viewing Reels.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              provider.openOverlaySettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}

class _GoalTile extends StatelessWidget {
  const _GoalTile({required this.provider});

  final ReelsCounterProvider provider;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.flag_outlined),
      title: const Text('Daily Goal'),
      subtitle: Text('${provider.dailyGoal} Reels per day'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showGoalDialog(context, provider),
    );
  }

  void _showGoalDialog(BuildContext context, ReelsCounterProvider provider) {
    final controller = TextEditingController(text: provider.dailyGoal.toString());
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set Daily Goal'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Reels per day',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text);
              if (value != null && value > 0) {
                provider.setDailyGoal(value);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _ResetTodayTile extends StatelessWidget {
  const _ResetTodayTile({required this.provider});

  final ReelsCounterProvider provider;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.restart_alt_outlined),
      title: const Text("Reset Today's Count"),
      subtitle: const Text("Zeroes today's counter without deleting history."),
      onTap: () => _showResetDialog(context),
    );
  }

  void _showResetDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Reset Today's Count?"),
        content: const Text(
          "This will reset your Reel count for today to 0. "
          "Your historical statistics will remain intact.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              provider.resetToday();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Today's count reset to 0")),
              );
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}

class _ClearHistoryTile extends StatelessWidget {
  const _ClearHistoryTile({required this.provider});

  final ReelsCounterProvider provider;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
      title: const Text('Clear All History', style: TextStyle(color: Colors.redAccent)),
      subtitle: const Text('Permanently deletes past daily statistics.'),
      onTap: () => _showClearDialog(context),
    );
  }

  void _showClearDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete All History?'),
        content: const Text(
          'This will permanently delete all past daily records and chart data. '
          "Today's active count will remain. This action cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              provider.clearHistory();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All history cleared')),
              );
            },
            child: const Text('Delete History'),
          ),
        ],
      ),
    );
  }
}

class _PrivacyTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.privacy_tip_outlined),
      title: const Text('Privacy Policy'),
      subtitle: const Text('100% offline & local on your device.'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Commitment'),
            content: const SingleChildScrollView(
              child: Text(
                'Reels Counter is designed with strict privacy standards:\n\n'
                '• No Account or Login Required\n'
                '• No Instagram Credentials Captured\n'
                '• 100% Local Processing\n'
                '• Accessibility data is never uploaded to any remote server\n'
                '• All history is stored securely on your device only.',
              ),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AboutTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.info_outline),
      title: const Text('About Reels Counter'),
      subtitle: const Text('Track and manage your digital viewing habits.'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.video_library_outlined),
            title: const Text('Reels Counter'),
            content: const Text(
              'A native Android + Flutter utility built to help users become conscious of their Instagram Reel viewing time.\n\n'
              'Features real-time accessibility detection, floating overlay, daily goals, and rich usage statistics.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _VersionTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.tag),
      title: const Text('Version'),
      subtitle: const Text(AppDefaults.appVersion),
    );
  }
}
