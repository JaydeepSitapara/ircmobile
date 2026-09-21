import 'package:flutter_test/flutter_test.dart';
import 'package:ircmobile/core/models/daily_reel_count.dart';
import 'package:ircmobile/core/models/reels_stats.dart';

void main() {
  group('DailyReelCount', () {
    test('isoDate returns correctly padded string', () {
      final record = DailyReelCount(date: DateTime(2026, 9, 5), count: 42);
      expect(record.isoDate, '2026-09-05');
    });

    test('relativeLabel returns Today for current date', () {
      final now = DateTime.now();
      final record = DailyReelCount(date: now, count: 15);
      expect(record.relativeLabel, 'Today');
    });

    test('relativeLabel returns Yesterday for previous day', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final record = DailyReelCount(date: yesterday, count: 25);
      expect(record.relativeLabel, 'Yesterday');
    });

    test('equality works based on calendar date and count', () {
      final r1 = DailyReelCount(date: DateTime(2026, 9, 21, 10, 30), count: 50);
      final r2 = DailyReelCount(date: DateTime(2026, 9, 21, 18, 45), count: 50);
      final r3 = DailyReelCount(date: DateTime(2026, 9, 22), count: 50);

      expect(r1, equals(r2));
      expect(r1, isNot(equals(r3)));
    });
  });

  group('ReelsStats', () {
    test('empty factory creates valid zeroed object', () {
      final empty = ReelsStats.empty();
      expect(empty.today, 0);
      expect(empty.total, 0);
      expect(empty.weekly, 0);
      expect(empty.monthly, 0);
      expect(empty.averagePerRecordedDay, 0.0);
      expect(empty.highestDay, isNull);
      expect(empty.daysTracked, 0);
      expect(empty.last7Days, isEmpty);
    });
  });
}
