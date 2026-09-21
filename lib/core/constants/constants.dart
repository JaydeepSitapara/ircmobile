// App-wide constants — SharedPreferences keys, channel names, route names,
// and configurable defaults.
//
// All native channel strings are declared here so they can be kept in sync
// between Flutter and Kotlin without hunting across multiple files.

// ---------------------------------------------------------------------------
// SharedPreferences keys
// ---------------------------------------------------------------------------

class StorageKeys {
  StorageKeys._();

  static const String todayCount = 'today_count';
  static const String todayDate = 'today_date';
  static const String totalCount = 'total_count';
  static const String trackingEnabled = 'tracking_enabled';
  static const String overlayEnabled = 'overlay_enabled';
  static const String dailyGoal = 'daily_goal';

  /// JSON-encoded `Map<String, int>` (ISO date string → count).
  static const String history = 'reel_history';
}

// ---------------------------------------------------------------------------
// Platform channel names — must match Kotlin side exactly
// ---------------------------------------------------------------------------

class ChannelNames {
  ChannelNames._();

  static const String methodChannel = 'reels_counter/native';
  static const String eventChannel = 'reels_counter/events';
}

// ---------------------------------------------------------------------------
// Method channel method names
// ---------------------------------------------------------------------------

class MethodNames {
  MethodNames._();

  static const String isAccessibilityServiceEnabled =
      'isAccessibilityServiceEnabled';
  static const String openAccessibilitySettings = 'openAccessibilitySettings';
  static const String isOverlayPermissionGranted = 'isOverlayPermissionGranted';
  static const String openOverlaySettings = 'openOverlaySettings';
  static const String startTracking = 'startTracking';
  static const String stopTracking = 'stopTracking';
  static const String showOverlay = 'showOverlay';
  static const String hideOverlay = 'hideOverlay';
  static const String getCurrentCount = 'getCurrentCount';
  static const String syncCount = 'syncCount';
}

// ---------------------------------------------------------------------------
// Event channel event keys
// ---------------------------------------------------------------------------

class EventNames {
  EventNames._();

  static const String reelDetected = 'reelDetected';
  static const String trackingStarted = 'trackingStarted';
  static const String trackingStopped = 'trackingStopped';
  static const String overlayStatusChanged = 'overlayStatusChanged';
}

// ---------------------------------------------------------------------------
// Route names
// ---------------------------------------------------------------------------

class Routes {
  Routes._();

  static const String home = '/';
  static const String dashboard = '/dashboard';
  static const String history = '/history';
  static const String statistics = '/statistics';
  static const String settings = '/settings';
}

// ---------------------------------------------------------------------------
// App defaults
// ---------------------------------------------------------------------------

class AppDefaults {
  AppDefaults._();

  static const int defaultDailyGoal = 200;
  static const String instagramPackage = 'com.instagram.android';
  static const String appVersion = '1.0.0';
}
