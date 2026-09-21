import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../constants/constants.dart';

/// Thin wrapper around [SharedPreferences] that handles all persistence for
/// the Reels Counter.
///
/// Daily reset logic:
///   On each [load] the stored date is compared with today. If they differ,
///   [todayCount] is moved into [history] under the old date and reset to 0.
class StorageService {
  StorageService._();

  static StorageService? _instance;

  static StorageService get instance {
    _instance ??= StorageService._();
    return _instance!;
  }

  late SharedPreferences _prefs;

  /// Must be called once before any other method, typically from [main].
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _performDailyReset();
  }

  // ---------------------------------------------------------------------------
  // Daily reset
  // ---------------------------------------------------------------------------

  /// ISO-8601 date string for today, e.g. "2026-09-21".
  static String _todayString() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}'
        '-${now.month.toString().padLeft(2, '0')}'
        '-${now.day.toString().padLeft(2, '0')}';
  }

  /// If the stored date differs from today, archive today's count into history
  /// and reset the daily counter. Handles multi-day gaps gracefully.
  void _performDailyReset() {
    final storedDate = _prefs.getString(StorageKeys.todayDate);
    final today = _todayString();

    if (storedDate != null && storedDate != today) {
      // Archive the count under the old date.
      final oldCount = _prefs.getInt(StorageKeys.todayCount) ?? 0;
      if (oldCount > 0) {
        final history = loadHistory();
        history[storedDate] = oldCount;
        _saveHistory(history);
      }
      // Reset daily counter.
      _prefs.setInt(StorageKeys.todayCount, 0);
    }

    // Always stamp today's date so we detect the next rollover.
    _prefs.setString(StorageKeys.todayDate, today);
  }

  // ---------------------------------------------------------------------------
  // Today's count
  // ---------------------------------------------------------------------------

  int loadTodayCount() => _prefs.getInt(StorageKeys.todayCount) ?? 0;

  Future<void> saveTodayCount(int count) async {
    await _prefs.setInt(StorageKeys.todayCount, count);
  }

  // ---------------------------------------------------------------------------
  // Total count
  // ---------------------------------------------------------------------------

  int loadTotalCount() => _prefs.getInt(StorageKeys.totalCount) ?? 0;

  Future<void> saveTotalCount(int count) async {
    await _prefs.setInt(StorageKeys.totalCount, count);
  }

  // ---------------------------------------------------------------------------
  // History — Map<String, int> where key is ISO date "YYYY-MM-DD"
  // ---------------------------------------------------------------------------

  Map<String, int> loadHistory() {
    final raw = _prefs.getString(StorageKeys.history);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v as int));
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveHistory(Map<String, int> history) async {
    await _prefs.setString(StorageKeys.history, jsonEncode(history));
  }

  /// Saves the full history map (called by the provider when today's entry
  /// needs to be included).
  Future<void> saveHistory(Map<String, int> history) => _saveHistory(history);

  // ---------------------------------------------------------------------------
  // Settings
  // ---------------------------------------------------------------------------

  bool loadTrackingEnabled() =>
      _prefs.getBool(StorageKeys.trackingEnabled) ?? false;

  Future<void> saveTrackingEnabled(bool value) async {
    await _prefs.setBool(StorageKeys.trackingEnabled, value);
  }

  bool loadOverlayEnabled() =>
      _prefs.getBool(StorageKeys.overlayEnabled) ?? false;

  Future<void> saveOverlayEnabled(bool value) async {
    await _prefs.setBool(StorageKeys.overlayEnabled, value);
  }

  int loadDailyGoal() =>
      _prefs.getInt(StorageKeys.dailyGoal) ?? AppDefaults.defaultDailyGoal;

  Future<void> saveDailyGoal(int goal) async {
    await _prefs.setInt(StorageKeys.dailyGoal, goal);
  }

  // ---------------------------------------------------------------------------
  // Convenience: clear all data (used in tests)
  // ---------------------------------------------------------------------------

  Future<void> clearAll() async {
    await _prefs.clear();
  }
}
