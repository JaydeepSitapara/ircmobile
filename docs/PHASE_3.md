# Phase 3 — Native Android Floating Reel Counter

## Overview

Phase 3 implements the **system-level floating counter overlay** on Android that appears over Instagram while the user is actively viewing Reels.

---

## Architecture

```
                 Flutter (Dashboard & Settings)
                               │
                 MethodChannel │ EventChannel
                               ▼
                        MainActivity
                               │
          ┌────────────────────┴────────────────────┐
          ▼                                         ▼
ReelsAccessibilityService                      OverlayService
          │                                         │
          ▼ (detects Reel / screen change)          ▼ (WindowManager)
 ReelTrackingManager ────────────────────────►  OverlayView
          │                                     (Draggable Pill)
          ▼                                         ▲
   CounterManager ──────────────────────────────────┘
(Single Source of Truth)
```

---

## 1. Native WindowManager Overlay (`OverlayService.kt` & `OverlayView.kt`)

### Window Parameters
- **Window Type**: `WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY` (Android 8.0+ / API 26+) with `TYPE_PHONE` fallback.
- **Flags**: `FLAG_NOT_FOCUSABLE | FLAG_LAYOUT_NO_LIMITS | FLAG_NOT_TOUCH_MODAL`.
- **Pixel Format**: `PixelFormat.TRANSLUCENT`.
- **Dimensions**: `WRAP_CONTENT` (does not take over or obstruct Instagram touches).

### Visual Styling (`OverlayView.kt`)
- **Pill Shape**: 24dp rounded corners with `#E6181824` dark background (90% opacity).
- **Accent**: 7dp Instagram magenta (`#E1306C`) status indicator dot.
- **Typography**: Clean, bold white text (`Reels: 127`).
- **Counter Change Animation**: Subtle pulse (`SCALE_X/Y` up 1.12x and return with `OvershootInterpolator`) on Reel detection.

### Drag & Position Persistence
- The overlay view is touch-draggable anywhere on the screen.
- On touch release (`ACTION_UP`), current `(x, y)` coordinates are saved via `OverlayPosition.save(context, pos)` in `ircmobile_overlay_prefs`.
- On next appearance, coordinates are loaded and restored.

---

## 2. Instagram & Reels-Exclusive Visibility

The floating overlay is displayed **strictly** when all four conditions are met:
1. `Floating Counter` setting is toggled **ON** by the user.
2. `SYSTEM_ALERT_WINDOW` ("Display over other apps") permission is granted.
3. Instagram (`com.instagram.android`) is in the foreground.
4. Active screen is confirmed as the **Reels screen** (confidence ≥ 2 in `ReelScreenDetector`).

When the user leaves the Reels screen (navigates to Home feed, DMs, Profile, Explore) or leaves Instagram, the overlay is **automatically hidden** by `OverlayService.onReelsScreenVisibilityChanged(false)`.

---

## 3. Counter State & Synchronization (`CounterManager.kt`)

`CounterManager` is the single source of truth for the native counter state:
- Maintains `todayCount` and `totalCount`.
- Backed by Android `SharedPreferences` (`ircmobile_counter_prefs`) so Reel counts are incremented and retained even if Flutter is in the background or killed.
- Automatically resets `todayCount` to `0` when the calendar day changes (`yyyy-MM-dd`).
- Synchronizes with Flutter on app launch and resume via MethodChannel `getCurrentCount` and `syncCount`.

---

## 4. MethodChannel API Extensions

| Method | Direction | Description |
|---|---|---|
| `isOverlayPermissionGranted` | Flutter ➔ Kotlin | Checks `Settings.canDrawOverlays(context)`. |
| `openOverlaySettings` | Flutter ➔ Kotlin | Launches `Settings.ACTION_MANAGE_OVERLAY_PERMISSION`. |
| `startOverlay` / `showOverlay` | Flutter ➔ Kotlin | Enables overlay in `OverlayService`. |
| `stopOverlay` / `hideOverlay` | Flutter ➔ Kotlin | Disables overlay in `OverlayService`. |
| `syncCount` | Flutter ➔ Kotlin | Syncs today's count to `CounterManager` and updates `OverlayView`. |
| `getCurrentCount` | Flutter ➔ Kotlin | Reads latest count from `CounterManager`. |
| `getOverlayStatus` | Flutter ➔ Kotlin | Returns map (`overlayEnabled`, `overlayShowing`, `permissionGranted`, `positionX`, `positionY`). |
| `setOverlayPosition` | Flutter ➔ Kotlin | Updates saved `(x, y)` overlay coordinates. |
| `getOverlayPosition` | Flutter ➔ Kotlin | Returns current `(x, y)` overlay coordinates. |

---

## 5. Testing & Verification

### Automated Android JVM Tests
```bash
./gradlew :app:testDebugUnitTest
```
- `CounterManagerTest.kt`: State management, daily reset, listener notifications.
- `OverlayPositionTest.kt`: Coordinate storage, equality, and default positioning.
- `InstagramDetectorTest.kt`, `ReelChangeDetectorTest.kt`, `ReelDebouncerTest.kt`, `ReelTrackingManagerTest.kt`.

### Automated Flutter Tests & Static Analysis
```bash
flutter analyze
flutter test
```

---

## 6. Manual Testing Instructions on Physical Device

```bash
# 1. Build and install debug APK
flutter build apk --debug
adb install build/app/outputs/flutter-apk/app-debug.apk

# 2. Permissions Setup
# Open Reels Counter app -> Settings:
# - Enable 'Reel Tracking' -> Tap 'Open Settings' -> Enable Reels Counter Accessibility Service.
# - Enable 'Floating Counter' -> Tap 'Open Settings' -> Enable "Display over other apps".

# 3. Test Floating Overlay
# Open Instagram -> Navigate to Reels:
# - Floating pill ("Reels: 0") appears in the upper right.
# - Drag the pill to another position (e.g., lower left).
# - Swipe to next Reel -> Pill pulses gently and updates to "Reels: 1".
# - Swipe to 5 Reels -> Pill increments to "Reels: 5".

# 4. Test Visibility Filtering
# In Instagram, tap the Home tab or DM tab:
# - Floating pill automatically disappears.
# Navigate back to Reels tab:
# - Floating pill reappears at the saved dragged position ("Reels: 5").
# Exit Instagram to Android Home screen:
# - Floating pill is hidden.

# 5. Test Flutter Synchronization
# Return to Reels Counter Flutter app:
# - Dashboard displays "5 Reels Watched" today.
```
