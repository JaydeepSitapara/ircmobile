import 'package:intl/intl.dart';

/// Immutable model representing the Reel count for a single calendar day.
class DailyReelCount {
  const DailyReelCount({
    required this.date,
    required this.count,
    this.updatedAt,
  });

  /// The calendar date of this record.
  final DateTime date;

  /// The number of Reels watched on this day.
  final int count;

  /// When this record was last mutated.
  final DateTime? updatedAt;

  /// ISO date string `yyyy-MM-dd`.
  String get isoDate =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// User-friendly relative label ("Today", "Yesterday", or "Monday, Sep 22").
  String get relativeLabel {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final difference = today.difference(target).inDays;

    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    if (difference < 7 && difference > 1) {
      return DateFormat('EEEE, MMM d').format(date);
    }
    return DateFormat('MMM d, yyyy').format(date);
  }

  /// Short formatted date (e.g., "Sep 22").
  String get shortFormattedDate => DateFormat('MMM d').format(date);

  /// Weekday abbreviation (e.g., "Mon", "Tue").
  String get weekdayAbbr => DateFormat('E').format(date);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyReelCount &&
          runtimeType == other.runtimeType &&
          date.year == other.date.year &&
          date.month == other.date.month &&
          date.day == other.date.day &&
          count == other.count;

  @override
  int get hashCode =>
      date.year.hashCode ^ date.month.hashCode ^ date.day.hashCode ^ count.hashCode;

  @override
  String toString() => 'DailyReelCount(date: $isoDate, count: $count)';
}
