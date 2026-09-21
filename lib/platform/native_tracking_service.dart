import 'package:flutter/services.dart';

import '../core/constants/constants.dart';

/// Abstracts all Flutter ↔ Kotlin communication via [MethodChannel] and
/// [EventChannel].
///
/// Phase 1: All method calls catch [MissingPluginException] and return safe
/// defaults so the Flutter layer is fully functional even before the native
/// side is implemented.
///
/// Phase 2: The Kotlin [MainActivity] registers the channel handlers and the
/// stubs below become live.
class NativeTrackingService {
  NativeTrackingService._();

  static NativeTrackingService? _instance;

  static NativeTrackingService get instance {
    _instance ??= NativeTrackingService._();
    return _instance!;
  }

    static const MethodChannel _methodChannel =
      MethodChannel(ChannelNames.methodChannel);

  static const EventChannel _eventChannel =
      EventChannel(ChannelNames.eventChannel);

  // ---------------------------------------------------------------------------
  // Accessibility
  // ---------------------------------------------------------------------------

  /// Returns true when the [ReelsAccessibilityService] is active.
  Future<bool> isAccessibilityServiceEnabled() async {
    try {
      final result = await _methodChannel
          .invokeMethod<bool>(MethodNames.isAccessibilityServiceEnabled);
      return result ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (e) {
      _log('isAccessibilityServiceEnabled error: ${e.message}');
      return false;
    }
  }

  /// Opens the system Accessibility settings page.
  Future<void> openAccessibilitySettings() async {
    try {
      await _methodChannel.invokeMethod(MethodNames.openAccessibilitySettings);
    } on MissingPluginException {
      // No-op in Phase 1.
    } on PlatformException catch (e) {
      _log('openAccessibilitySettings error: ${e.message}');
    }
  }

  // ---------------------------------------------------------------------------
  // Overlay
  // ---------------------------------------------------------------------------

  /// Returns true when SYSTEM_ALERT_WINDOW permission is granted.
  Future<bool> isOverlayPermissionGranted() async {
    try {
      final result = await _methodChannel
          .invokeMethod<bool>(MethodNames.isOverlayPermissionGranted);
      return result ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (e) {
      _log('isOverlayPermissionGranted error: ${e.message}');
      return false;
    }
  }

  /// Opens the system "Draw over other apps" settings page.
  Future<void> openOverlaySettings() async {
    try {
      await _methodChannel.invokeMethod(MethodNames.openOverlaySettings);
    } on MissingPluginException {
      // No-op in Phase 1.
    } on PlatformException catch (e) {
      _log('openOverlaySettings error: ${e.message}');
    }
  }

  // ---------------------------------------------------------------------------
  // Tracking control
  // ---------------------------------------------------------------------------

  Future<void> startTracking() async {
    try {
      await _methodChannel.invokeMethod(MethodNames.startTracking);
    } on MissingPluginException {
      // No-op in Phase 1.
    } on PlatformException catch (e) {
      _log('startTracking error: ${e.message}');
    }
  }

  Future<void> stopTracking() async {
    try {
      await _methodChannel.invokeMethod(MethodNames.stopTracking);
    } on MissingPluginException {
      // No-op in Phase 1.
    } on PlatformException catch (e) {
      _log('stopTracking error: ${e.message}');
    }
  }

  // ---------------------------------------------------------------------------
  // Overlay control
  // ---------------------------------------------------------------------------

  Future<void> showOverlay(int count) async {
    try {
      await _methodChannel
          .invokeMethod(MethodNames.showOverlay, {'count': count});
    } on MissingPluginException {
      // No-op in Phase 1.
    } on PlatformException catch (e) {
      _log('showOverlay error: ${e.message}');
    }
  }

  Future<void> hideOverlay() async {
    try {
      await _methodChannel.invokeMethod(MethodNames.hideOverlay);
    } on MissingPluginException {
      // No-op in Phase 1.
    } on PlatformException catch (e) {
      _log('hideOverlay error: ${e.message}');
    }
  }

  // ---------------------------------------------------------------------------
  // State synchronization & query
  // ---------------------------------------------------------------------------

  /// Fetches the authoritative native tracking state.
  Future<Map<String, dynamic>?> getTrackingState() async {
    try {
      final result = await _methodChannel.invokeMapMethod<String, dynamic>('getTrackingState');
      return result;
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e) {
      _log('getTrackingState error: ${e.message}');
      return null;
    }
  }

  /// Fetches the native daily history map (ISO date -> count).
  Future<Map<String, int>?> getDailyHistory() async {
    try {
      final result = await _methodChannel.invokeMapMethod<String, dynamic>('getDailyHistory');
      if (result == null) return null;
      return result.map((key, value) => MapEntry(key, value is int ? value : (value as num).toInt()));
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e) {
      _log('getDailyHistory error: ${e.message}');
      return null;
    }
  }

  /// Resets today's count on the native side.
  Future<int?> resetTodayCount() async {
    try {
      final result = await _methodChannel.invokeMethod<int>('resetTodayCount');
      return result;
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e) {
      _log('resetTodayCount error: ${e.message}');
      return null;
    }
  }

  /// Pushes the current Flutter-side count to the native overlay.
  Future<void> syncCount(int count) async {
    try {
      await _methodChannel
          .invokeMethod(MethodNames.syncCount, {'count': count});
    } on MissingPluginException {
      // Safe no-op in tests
    } on PlatformException catch (e) {
      _log('syncCount error: ${e.message}');
    }
  }

  /// Queries the current native counter value.
  Future<int?> getCurrentCount() async {
    try {
      final result = await _methodChannel.invokeMethod<int>(MethodNames.getCurrentCount);
      return result;
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e) {
      _log('getCurrentCount error: ${e.message}');
      return null;
    }
  }

  /// Queries status of native overlay.
  Future<Map<String, dynamic>?> getOverlayStatus() async {
    try {
      final result = await _methodChannel.invokeMapMethod<String, dynamic>('getOverlayStatus');
      return result;
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e) {
      _log('getOverlayStatus error: ${e.message}');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Event stream — native → Flutter
  // ---------------------------------------------------------------------------

  /// Broadcasts events from the Kotlin layer (reel detected, tracking
  /// started/stopped, overlay status). In Phase 1 this stream emits nothing.
  /// Returns an empty stream if the platform channel is unavailable (e.g., in
  /// unit tests).
  Stream<Map<String, dynamic>> get nativeEvents {
    try {
      return _eventChannel.receiveBroadcastStream().map((dynamic event) {
        if (event is Map) {
          return Map<String, dynamic>.from(event);
        }
        return <String, dynamic>{};
      });
    } catch (_) {
      return const Stream.empty();
    }
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  void _log(String message) {
    // ignore: avoid_print
    print('[NativeTrackingService] $message');
  }
}
