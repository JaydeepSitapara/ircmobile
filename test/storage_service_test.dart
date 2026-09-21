import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ircmobile/core/services/storage_service.dart';
import 'package:ircmobile/core/constants/constants.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.instance.init();
  });

  tearDown(() async {
    await StorageService.instance.clearAll();
  });

  group('StorageService — today count', () {
    test('defaults to 0', () {
      expect(StorageService.instance.loadTodayCount(), 0);
    });

    test('saves and loads today count', () async {
      await StorageService.instance.saveTodayCount(42);
      expect(StorageService.instance.loadTodayCount(), 42);
    });
  });

  group('StorageService — total count', () {
    test('defaults to 0', () {
      expect(StorageService.instance.loadTotalCount(), 0);
    });

    test('saves and loads total count', () async {
      await StorageService.instance.saveTotalCount(1000);
      expect(StorageService.instance.loadTotalCount(), 1000);
    });
  });

  group('StorageService — history', () {
    test('defaults to empty map', () {
      expect(StorageService.instance.loadHistory(), isEmpty);
    });

    test('saves and loads history', () async {
      final history = {'2026-09-20': 184, '2026-09-19': 92};
      await StorageService.instance.saveHistory(history);
      final loaded = StorageService.instance.loadHistory();
      expect(loaded, equals(history));
    });
  });

  group('StorageService — settings', () {
    test('tracking disabled by default', () {
      expect(StorageService.instance.loadTrackingEnabled(), isFalse);
    });

    test('overlay disabled by default', () {
      expect(StorageService.instance.loadOverlayEnabled(), isFalse);
    });

    test('daily goal defaults to ${AppDefaults.defaultDailyGoal}', () {
      expect(
        StorageService.instance.loadDailyGoal(),
        AppDefaults.defaultDailyGoal,
      );
    });

    test('saves and loads daily goal', () async {
      await StorageService.instance.saveDailyGoal(300);
      expect(StorageService.instance.loadDailyGoal(), 300);
    });
  });

  group('StorageService — daily reset', () {
    test('resets today count when date changes', () async {
      // Simulate yesterday's date stored in prefs.
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final yesterdayStr =
          '${yesterday.year.toString().padLeft(4, '0')}'
          '-${yesterday.month.toString().padLeft(2, '0')}'
          '-${yesterday.day.toString().padLeft(2, '0')}';

      SharedPreferences.setMockInitialValues({
        StorageKeys.todayDate: yesterdayStr,
        StorageKeys.todayCount: 127,
        StorageKeys.totalCount: 500,
      });

      // Re-init triggers the daily reset.
      await StorageService.instance.init();

      // Today's count should be reset.
      expect(StorageService.instance.loadTodayCount(), 0);

      // Yesterday's count should be in history.
      final history = StorageService.instance.loadHistory();
      expect(history[yesterdayStr], 127);
    });

    test('does not reset if same day', () async {
      final today = DateTime.now();
      final todayStr =
          '${today.year.toString().padLeft(4, '0')}'
          '-${today.month.toString().padLeft(2, '0')}'
          '-${today.day.toString().padLeft(2, '0')}';

      SharedPreferences.setMockInitialValues({
        StorageKeys.todayDate: todayStr,
        StorageKeys.todayCount: 50,
      });

      await StorageService.instance.init();

      // Count should remain.
      expect(StorageService.instance.loadTodayCount(), 50);
    });
  });
}
