import '../models/daily_reel_count.dart';
import '../models/reels_stats.dart';
import '../services/storage_service.dart';
import '../../platform/native_tracking_service.dart';

abstract class ReelsRepository {
  Future<ReelsStats> getStats({
    required int todayCount,
    required int totalCount,
    required Map<String, int> history,
  });

  Future<List<DailyReelCount>> getHistory({
    required int todayCount,
    required Map<String, int> history,
    int limit = 90,
    int offset = 0,
  });

  Future<void> setDailyGoal(int goal);

  Future<void> resetToday();

  Future<void> clearHistory();
}

class NativeReelsRepository implements ReelsRepository {
  const NativeReelsRepository({
    required StorageService storage,
    required NativeTrackingService native,
  })  : _storage = storage,
        _native = native;

  final StorageService _storage;
  final NativeTrackingService _native;

  @override
  Future<ReelsStats> getStats({
    required int todayCount,
    required int totalCount,
    required Map<String, int> history,
  }) async {
    final now = DateTime.now();
    final todayKey = _formatDate(now);

    // Combine history with today
    final fullHistory = {...history, todayKey: todayCount};

    // Calculate Last 7 Days (including today)
    int weeklySum = 0;
    final last7DaysList = <DailyReelCount>[];
    for (int i = 6; i >= 0; i--) {
      final day = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final dayKey = _formatDate(day);
      final count = (dayKey == todayKey) ? todayCount : (history[dayKey] ?? 0);
      weeklySum += count;
      last7DaysList.add(DailyReelCount(date: day, count: count));
    }

    // Calculate Last 30 Days (including today)
    int monthlySum = 0;
    for (int i = 0; i < 30; i++) {
      final day = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final dayKey = _formatDate(day);
      final count = (dayKey == todayKey) ? todayCount : (history[dayKey] ?? 0);
      monthlySum += count;
    }

    // Filter valid recorded days (> 0 count) for average calculation
    final recordedDaysWithCounts = fullHistory.entries
        .where((e) => e.value > 0)
        .toList();

    final daysTracked = recordedDaysWithCounts.length;
    final totalRecordedSum = recordedDaysWithCounts.fold<int>(0, (sum, e) => sum + e.value);
    final average = daysTracked > 0 ? (totalRecordedSum / daysTracked) : 0.0;

    // Find highest day
    DailyReelCount? highestDay;
    for (final entry in fullHistory.entries) {
      if (entry.value > 0) {
        final parsedDate = DateTime.tryParse(entry.key);
        if (parsedDate != null) {
          if (highestDay == null || entry.value > highestDay.count) {
            highestDay = DailyReelCount(date: parsedDate, count: entry.value);
          }
        }
      }
    }

    return ReelsStats(
      today: todayCount,
      total: totalCount > 0 ? totalCount : totalRecordedSum,
      weekly: weeklySum,
      monthly: monthlySum,
      averagePerRecordedDay: average,
      highestDay: highestDay,
      daysTracked: daysTracked,
      last7Days: last7DaysList,
    );
  }

  @override
  Future<List<DailyReelCount>> getHistory({
    required int todayCount,
    required Map<String, int> history,
    int limit = 90,
    int offset = 0,
  }) async {
    final now = DateTime.now();
    final todayKey = _formatDate(now);
    final fullMap = {...history, todayKey: todayCount};

    final allRecords = <DailyReelCount>[];
    for (final entry in fullMap.entries) {
      final parsedDate = DateTime.tryParse(entry.key);
      if (parsedDate != null) {
        allRecords.add(DailyReelCount(date: parsedDate, count: entry.value));
      }
    }

    // Sort newest first
    allRecords.sort((a, b) => b.date.compareTo(a.date));

    if (offset >= allRecords.length) return [];
    final endIndex = (offset + limit).clamp(0, allRecords.length);
    return allRecords.sublist(offset, endIndex);
  }

  @override
  Future<void> setDailyGoal(int goal) async {
    await _storage.saveDailyGoal(goal);
  }

  @override
  Future<void> resetToday() async {
    await _storage.saveTodayCount(0);
    await _native.resetTodayCount();
  }

  @override
  Future<void> clearHistory() async {
    await _storage.saveHistory({});
  }

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}
