import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ircmobile/core/services/storage_service.dart';
import 'package:ircmobile/features/dashboard/providers/reels_counter_provider.dart';
import 'package:ircmobile/platform/native_tracking_service.dart';

const MethodChannel _channel = MethodChannel('reels_counter/native');

/// Registers a mock handler that returns safe defaults for all native calls.
void _setupMockChannel() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, (MethodCall call) async {
    switch (call.method) {
      case 'isAccessibilityServiceEnabled':
        return false;
      case 'isOverlayPermissionGranted':
        return false;
      default:
        return null;
    }
  });
}

void _tearDownMockChannel() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, null);
}

/// Helper: build a provider pre-seeded with [history] and [todayCount].
Future<ReelsCounterProvider> buildProvider({
  Map<String, int> history = const {},
  int todayCount = 0,
  int totalCount = 0,
}) async {
  _setupMockChannel();
  SharedPreferences.setMockInitialValues({});
  await StorageService.instance.init();

  if (history.isNotEmpty) {
    await StorageService.instance.saveHistory(history);
  }
  if (todayCount > 0) {
    await StorageService.instance.saveTodayCount(todayCount);
  }
  if (totalCount > 0) {
    await StorageService.instance.saveTotalCount(totalCount);
  }

  final provider = ReelsCounterProvider(
    storage: StorageService.instance,
    native: NativeTrackingService.instance,
  );
  await provider.init();
  return provider;
}

DateTime daysAgo(int days) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day).subtract(Duration(days: days));
}

String formatDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}'
    '-${date.month.toString().padLeft(2, '0')}'
    '-${date.day.toString().padLeft(2, '0')}';

void main() {
  // Required so that MethodChannel calls in NativeTrackingService don't crash.
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    _tearDownMockChannel();
    await StorageService.instance.clearAll();
  });

  group('Statistics — weekly total', () {
    test('sums today and last 6 days', () async {
      final history = {
        formatDate(daysAgo(1)): 50,
        formatDate(daysAgo(2)): 30,
        formatDate(daysAgo(6)): 20,
        formatDate(daysAgo(7)): 99, // outside 7-day window
      };
      final provider = await buildProvider(history: history, todayCount: 10);

      // 10 (today) + 50 + 30 + 20 = 110
      expect(provider.weeklyTotal, 110);
    });

    test('returns 0 with no data', () async {
      final provider = await buildProvider();
      expect(provider.weeklyTotal, 0);
    });
  });

  group('Statistics — monthly total', () {
    test('sums today and last 29 days', () async {
      final history = {
        formatDate(daysAgo(1)): 100,
        formatDate(daysAgo(29)): 50,
        formatDate(daysAgo(30)): 999, // outside 30-day window
      };
      final provider = await buildProvider(history: history, todayCount: 5);

      // 5 + 100 + 50 = 155
      expect(provider.monthlyTotal, 155);
    });
  });

  group('Statistics — recentDays', () {
    test('entry at index 0 is today', () async {
      final provider = await buildProvider(todayCount: 7);
      final days = provider.recentDays(7);
      expect(days.first.value, 7);
    });

    test('historical entries are populated correctly', () async {
      final history = {
        formatDate(daysAgo(1)): 44,
        formatDate(daysAgo(2)): 22,
      };
      final provider = await buildProvider(history: history);
      final days = provider.recentDays(7);
      expect(days[1].value, 44); // yesterday
      expect(days[2].value, 22); // two days ago
    });

    test('entries beyond history default to 0', () async {
      final provider = await buildProvider();
      final days = provider.recentDays(7);
      for (final entry in days) {
        expect(entry.value, 0);
      }
    });
  });

  group('Statistics — fullHistory', () {
    test('includes today in fullHistory', () async {
      final provider = await buildProvider(todayCount: 15);
      final full = provider.fullHistory;
      final todayKey = formatDate(DateTime.now());
      expect(full[todayKey], 15);
    });
  });
}
