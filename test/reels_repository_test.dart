import 'package:flutter_test/flutter_test.dart';
import 'package:ircmobile/core/repositories/reels_repository.dart';
import 'package:ircmobile/core/services/storage_service.dart';
import 'package:ircmobile/platform/native_tracking_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService storage;
  late NativeTrackingService native;
  late NativeReelsRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService.instance;
    await storage.init();
    native = NativeTrackingService.instance;
    repository = NativeReelsRepository(storage: storage, native: native);
  });

  group('NativeReelsRepository', () {
    test('getStats calculates weekly, average, and highest day correctly', () async {
      final now = DateTime.now();
      String fmt(DateTime d) =>
          '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

      final d1 = fmt(now.subtract(const Duration(days: 1)));
      final d2 = fmt(now.subtract(const Duration(days: 2)));

      final history = {
        d1: 100,
        d2: 300,
      };

      final stats = await repository.getStats(
        todayCount: 200,
        totalCount: 600,
        history: history,
      );

      expect(stats.today, 200);
      expect(stats.total, 600);
      expect(stats.weekly, 600);
      expect(stats.daysTracked, 3);
      expect(stats.averagePerRecordedDay, 200.0); // (200 + 100 + 300) / 3 = 200
      expect(stats.highestDay?.count, 300);
      expect(stats.last7Days.length, 7);
    });

    test('getHistory sorts records newest first', () async {
      final history = {
        '2026-09-10': 50,
        '2026-09-15': 120,
        '2026-09-01': 30,
      };

      final historyList = await repository.getHistory(
        todayCount: 10,
        history: history,
      );

      expect(historyList.isNotEmpty, true);
      // Newest should be today (or highest date)
      for (int i = 0; i < historyList.length - 1; i++) {
        expect(historyList[i].date.isAfter(historyList[i + 1].date), true);
      }
    });
  });
}
