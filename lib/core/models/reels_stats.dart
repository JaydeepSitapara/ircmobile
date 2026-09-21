import 'daily_reel_count.dart';

/// Immutable statistical snapshot computed from historical and live tracking data.
class ReelsStats {
  const ReelsStats({
    required this.today,
    required this.total,
    required this.weekly,
    required this.monthly,
    required this.averagePerRecordedDay,
    required this.highestDay,
    required this.daysTracked,
    required this.last7Days,
  });

  /// Today's live count.
  final int today;

  /// Lifetime total count.
  final int total;

  /// Reels watched in the last 7 calendar days (including today).
  final int weekly;

  /// Reels watched in the last 30 calendar days (including today).
  final int monthly;

  /// Average reels watched per recorded day with data.
  final double averagePerRecordedDay;

  /// The record with the single highest count.
  final DailyReelCount? highestDay;

  /// Number of distinct calendar days with tracked Reel counts.
  final int daysTracked;

  /// Data points for the last 7 calendar days (chronological, ending with today).
  final List<DailyReelCount> last7Days;

  /// Returns an empty stats snapshot when no data exists.
  factory ReelsStats.empty() {
    return const ReelsStats(
      today: 0,
      total: 0,
      weekly: 0,
      monthly: 0,
      averagePerRecordedDay: 0.0,
      highestDay: null,
      daysTracked: 0,
      last7Days: [],
    );
  }

  @override
  String toString() =>
      'ReelsStats(today: $today, total: $total, weekly: $weekly, monthly: $monthly, '
      'avg: ${averagePerRecordedDay.toStringAsFixed(1)}, days: $daysTracked)';
}
