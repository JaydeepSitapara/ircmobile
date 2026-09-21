import 'package:flutter/foundation.dart';

import '../../../core/models/daily_reel_count.dart';
import '../../../core/models/reels_stats.dart';
import '../../../core/repositories/reels_repository.dart';
import '../../../core/services/storage_service.dart';
import '../../../platform/native_tracking_service.dart';

/// Central state provider for Reels Counter.
///
/// Coordinates between native tracking events, persistent repository storage,
/// and reactive Flutter UI views.
class ReelsCounterProvider extends ChangeNotifier {
  ReelsCounterProvider({
    required StorageService storage,
    required NativeTrackingService native,
    ReelsRepository? repository,
  })  : _storage = storage,
        _native = native,
        _repository = repository ??
            NativeReelsRepository(storage: storage, native: native);

  final StorageService _storage;
  final NativeTrackingService _native;
  final ReelsRepository _repository;

  // ---------------------------------------------------------------------------
  // State fields
  // ---------------------------------------------------------------------------

  int _todayCount = 0;
  int _totalCount = 0;
  bool _trackingEnabled = false;
  bool _overlayEnabled = false;
  int _dailyGoal = 200;

  /// Per-day history: ISO date string → count (excludes today).
  Map<String, int> _history = {};

  bool _accessibilityEnabled = false;
  bool _overlayPermissionGranted = false;

  bool _initialized = false;
  bool _isLoading = false;
  String? _errorMessage;

  // Phase 2/3 live tracking debug state
  bool _instagramDetected = false;
  bool _reelsScreenActive = false;
  String _lastNativeState = '';
  String _lastFingerprint = '';
  int _detectionConfidence = 0;
  int _nativeEventCount = 0;

  // ---------------------------------------------------------------------------
  // Public getters
  // ---------------------------------------------------------------------------

  int get todayCount => _todayCount;
  int get totalCount => _totalCount;
  bool get trackingEnabled => _trackingEnabled;
  bool get overlayEnabled => _overlayEnabled;
  int get dailyGoal => _dailyGoal;
  bool get accessibilityEnabled => _accessibilityEnabled;
  bool get overlayPermissionGranted => _overlayPermissionGranted;
  bool get initialized => _initialized;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool get instagramDetected => _instagramDetected;
  bool get reelsScreenActive => _reelsScreenActive;
  String get lastNativeState => _lastNativeState;
  String get lastFingerprint => _lastFingerprint;
  int get detectionConfidence => _detectionConfidence;
  int get nativeEventCount => _nativeEventCount;

  Map<String, int> get history => Map.unmodifiable(_history);

  Map<String, int> get fullHistory {
    final today = _todayKey();
    return {..._history, today: _todayCount};
  }

  // ---------------------------------------------------------------------------
  // Computed statistics (Synchronous snapshots for UI)
  // ---------------------------------------------------------------------------

  int get weeklyTotal {
    final now = DateTime.now();
    int total = _todayCount;
    for (int i = 1; i <= 6; i++) {
      final day = now.subtract(Duration(days: i));
      total += _history[_formatDate(day)] ?? 0;
    }
    return total;
  }

  int get monthlyTotal {
    final now = DateTime.now();
    int total = _todayCount;
    for (int i = 1; i <= 29; i++) {
      final day = now.subtract(Duration(days: i));
      total += _history[_formatDate(day)] ?? 0;
    }
    return total;
  }

  /// Calculates statistics snapshot using the repository logic.
  Future<ReelsStats> getStats() async {
    return _repository.getStats(
      todayCount: _todayCount,
      totalCount: _totalCount,
      history: _history,
    );
  }

  /// Returns historical records sorted newest first with pagination.
  Future<List<DailyReelCount>> getHistoryList({int limit = 90, int offset = 0}) async {
    return _repository.getHistory(
      todayCount: _todayCount,
      history: _history,
      limit: limit,
      offset: offset,
    );
  }

  /// Returns counts for the last [days] calendar days, newest first.
  List<MapEntry<DateTime, int>> recentDays(int days) {
    final now = DateTime.now();
    final result = <MapEntry<DateTime, int>>[];
    for (int i = 0; i < days; i++) {
      final day = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final key = _formatDate(day);
      final count = i == 0 ? _todayCount : (_history[key] ?? 0);
      result.add(MapEntry(day, count));
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // Initialisation & Synchronization
  // ---------------------------------------------------------------------------

  Future<void> init() async {
    _isLoading = true;
    _todayCount = _storage.loadTodayCount();
    _totalCount = _storage.loadTotalCount();
    _trackingEnabled = _storage.loadTrackingEnabled();
    _overlayEnabled = _storage.loadOverlayEnabled();
    _dailyGoal = _storage.loadDailyGoal();
    _history = _storage.loadHistory();

    await _refreshPermissionStatus();
    await _syncWithNativeState();

    _subscribeToNativeEvents();

    _initialized = true;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _refreshPermissionStatus() async {
    _accessibilityEnabled = await _native.isAccessibilityServiceEnabled();
    _overlayPermissionGranted = await _native.isOverlayPermissionGranted();
  }

  Future<void> _syncWithNativeState() async {
    final state = await _native.getTrackingState();
    if (state != null) {
      final nativeToday = state['todayCount'] as int?;
      final nativeTotal = state['totalCount'] as int?;
      final nativeHistory = state['dailyHistory'] as Map?;
      final nativeTracking = state['trackingEnabled'] as bool?;
      final nativeOverlay = state['overlayEnabled'] as bool?;

      if (nativeToday != null) _todayCount = nativeToday;
      if (nativeTotal != null) _totalCount = nativeTotal;
      if (nativeTracking != null) _trackingEnabled = nativeTracking;
      if (nativeOverlay != null) _overlayEnabled = nativeOverlay;
      if (nativeHistory != null) {
        _history = nativeHistory.map(
          (k, v) => MapEntry(k.toString(), v is int ? v : (v as num).toInt()),
        );
        await _storage.saveHistory(_history);
      }

      await _storage.saveTodayCount(_todayCount);
      await _storage.saveTotalCount(_totalCount);
      await _storage.saveTrackingEnabled(_trackingEnabled);
      await _storage.saveOverlayEnabled(_overlayEnabled);
    } else {
      await _syncWithNativeCounter();
    }
  }

  Future<void> _syncWithNativeCounter() async {
    final nativeCount = await _native.getCurrentCount();
    if (nativeCount != null && nativeCount > _todayCount) {
      final diff = nativeCount - _todayCount;
      _todayCount = nativeCount;
      _totalCount += diff;
      await _storage.saveTodayCount(_todayCount);
      await _storage.saveTotalCount(_totalCount);
    } else {
      await _native.syncCount(_todayCount);
    }
  }

  /// Call this when returning to Flutter app from background/Android settings.
  Future<void> refreshOnResume() async {
    await _refreshPermissionStatus();
    await _syncWithNativeState();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Native Event Stream Handling
  // ---------------------------------------------------------------------------

  void _subscribeToNativeEvents() {
    try {
      _native.nativeEvents.listen(
        _handleNativeEvent,
        onError: (Object error) {
          debugPrint('[ReelsCounterProvider] Native event error: $error');
        },
      );
    } catch (e) {
      debugPrint('[ReelsCounterProvider] Could not subscribe to events: $e');
    }
  }

  void _handleNativeEvent(Map<String, dynamic> event) {
    _nativeEventCount++;
    final type = event['type'] as String?;

    switch (type) {
      case 'reelDetected':
        _lastFingerprint = (event['fingerprint'] as String?) ?? '';
        _detectionConfidence = (event['confidence'] as int?) ?? 0;
        final nativeToday = event['todayCount'] as int?;
        final nativeTotal = event['totalCount'] as int?;
        if (nativeToday != null && nativeToday > 0) {
          _todayCount = nativeToday;
          _totalCount = nativeTotal ?? (_totalCount + 1);
          _storage.saveTodayCount(_todayCount);
          _storage.saveTotalCount(_totalCount);
          notifyListeners();
        } else {
          _incrementCounter();
        }

      case 'trackingStarted':
        _trackingEnabled = true;
        notifyListeners();

      case 'trackingStopped':
        _trackingEnabled = false;
        notifyListeners();

      case 'overlayStatusChanged':
        final enabled = event['enabled'] as bool?;
        if (enabled != null) {
          _overlayEnabled = enabled;
          notifyListeners();
        }

      case 'instagramDetected':
        _instagramDetected = true;
        notifyListeners();

      case 'instagramClosed':
        _instagramDetected = false;
        _reelsScreenActive = false;
        notifyListeners();

      case 'reelsScreenActive':
        _reelsScreenActive = true;
        notifyListeners();

      case 'reelsScreenInactive':
        _reelsScreenActive = false;
        notifyListeners();

      case 'trackingState':
        _lastNativeState = (event['state'] as String?) ?? '';
        notifyListeners();

      default:
        debugPrint('[ReelsCounterProvider] Unknown event type: $type');
    }
  }

  // ---------------------------------------------------------------------------
  // State Mutations
  // ---------------------------------------------------------------------------

  Future<void> _incrementCounter() async {
    _todayCount++;
    _totalCount++;
    await _storage.saveTodayCount(_todayCount);
    await _storage.saveTotalCount(_totalCount);
    if (_overlayEnabled) {
      await _native.syncCount(_todayCount);
    }
    notifyListeners();
  }

  Future<void> debugIncrement() async {
    await _incrementCounter();
  }

  /// Resets today's counter without deleting historical records.
  Future<void> resetToday() async {
    _todayCount = 0;
    await _repository.resetToday();
    notifyListeners();
  }

  /// Clears historical records (preserves today's current count).
  Future<void> clearHistory() async {
    _history = {};
    await _repository.clearHistory();
    notifyListeners();
  }

  Future<void> setTrackingEnabled(bool value) async {
    _trackingEnabled = value;
    await _storage.saveTrackingEnabled(value);
    if (value) {
      await _native.startTracking();
    } else {
      await _native.stopTracking();
    }
    notifyListeners();
  }

  Future<void> setOverlayEnabled(bool value) async {
    _overlayEnabled = value;
    await _storage.saveOverlayEnabled(value);
    if (value) {
      await _native.showOverlay(_todayCount);
    } else {
      await _native.hideOverlay();
    }
    notifyListeners();
  }

  Future<void> setDailyGoal(int goal) async {
    if (goal <= 0) return;
    _dailyGoal = goal;
    await _repository.setDailyGoal(goal);
    notifyListeners();
  }

  Future<void> openAccessibilitySettings() async {
    await _native.openAccessibilitySettings();
  }

  Future<void> openOverlaySettings() async {
    await _native.openOverlaySettings();
  }

  // ---------------------------------------------------------------------------
  // Date Helpers
  // ---------------------------------------------------------------------------

  String _todayKey() => _formatDate(DateTime.now());

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}
