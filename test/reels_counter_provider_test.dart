import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ircmobile/core/services/storage_service.dart';
import 'package:ircmobile/features/dashboard/providers/reels_counter_provider.dart';
import 'package:ircmobile/platform/native_tracking_service.dart';

void main() {
  // Required so that MethodChannel calls in NativeTrackingService don't crash.
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock the native channel to return safe defaults.
  const MethodChannel channel = MethodChannel('reels_counter/native');

  late ReelsCounterProvider provider;

  setUp(() async {
    // Register a mock handler for the native channel that returns safe defaults.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      switch (call.method) {
        case 'isAccessibilityServiceEnabled':
          return false;
        case 'isOverlayPermissionGranted':
          return false;
        default:
          return null;
      }
    });

    SharedPreferences.setMockInitialValues({});
    await StorageService.instance.init();
    provider = ReelsCounterProvider(
      storage: StorageService.instance,
      native: NativeTrackingService.instance,
    );
    await provider.init();
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await StorageService.instance.clearAll();
  });

  group('ReelsCounterProvider — initial state', () {
    test('today count starts at 0', () {
      expect(provider.todayCount, 0);
    });

    test('total count starts at 0', () {
      expect(provider.totalCount, 0);
    });

    test('tracking is disabled by default', () {
      expect(provider.trackingEnabled, isFalse);
    });

    test('overlay is disabled by default', () {
      expect(provider.overlayEnabled, isFalse);
    });

    test('initialized is true after init', () {
      expect(provider.initialized, isTrue);
    });
  });

  group('ReelsCounterProvider — increment', () {
    test('debugIncrement increases todayCount by 1', () async {
      await provider.debugIncrement();
      expect(provider.todayCount, 1);
    });

    test('debugIncrement increases totalCount by 1', () async {
      await provider.debugIncrement();
      expect(provider.totalCount, 1);
    });

    test('multiple increments accumulate', () async {
      await provider.debugIncrement();
      await provider.debugIncrement();
      await provider.debugIncrement();
      expect(provider.todayCount, 3);
      expect(provider.totalCount, 3);
    });

    test('increments are persisted', () async {
      await provider.debugIncrement();
      expect(StorageService.instance.loadTodayCount(), 1);
      expect(StorageService.instance.loadTotalCount(), 1);
    });
  });

  group('ReelsCounterProvider — reset', () {
    test('resetToday zeroes todayCount', () async {
      await provider.debugIncrement();
      await provider.debugIncrement();
      await provider.resetToday();
      expect(provider.todayCount, 0);
    });

    test('resetToday does not affect totalCount', () async {
      await provider.debugIncrement();
      await provider.debugIncrement();
      await provider.resetToday();
      // totalCount remains at 2.
      expect(provider.totalCount, 2);
    });
  });

  group('ReelsCounterProvider — tracking toggle', () {
    test('setTrackingEnabled persists the value', () async {
      await provider.setTrackingEnabled(true);
      expect(provider.trackingEnabled, isTrue);
      expect(StorageService.instance.loadTrackingEnabled(), isTrue);
    });

    test('can toggle off again', () async {
      await provider.setTrackingEnabled(true);
      await provider.setTrackingEnabled(false);
      expect(provider.trackingEnabled, isFalse);
    });
  });

  group('ReelsCounterProvider — overlay toggle', () {
    test('setOverlayEnabled persists the value', () async {
      await provider.setOverlayEnabled(true);
      expect(provider.overlayEnabled, isTrue);
    });
  });

  group('ReelsCounterProvider — daily goal', () {
    test('setDailyGoal updates and persists', () async {
      await provider.setDailyGoal(500);
      expect(provider.dailyGoal, 500);
      expect(StorageService.instance.loadDailyGoal(), 500);
    });
  });

  group('ReelsCounterProvider — statistics', () {
    test('weeklyTotal includes todayCount', () async {
      await provider.debugIncrement();
      expect(provider.weeklyTotal, greaterThanOrEqualTo(1));
    });

    test('monthlyTotal includes todayCount', () async {
      await provider.debugIncrement();
      expect(provider.monthlyTotal, greaterThanOrEqualTo(1));
    });

    test('recentDays returns requested number of entries', () {
      final days = provider.recentDays(7);
      expect(days.length, 7);
    });

    test('recentDays first entry is today', () {
      final days = provider.recentDays(7);
      final today = DateTime.now();
      expect(days.first.key.year, today.year);
      expect(days.first.key.month, today.month);
      expect(days.first.key.day, today.day);
    });
  });
}
