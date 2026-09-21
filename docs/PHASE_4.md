# Phase 4 — Background Reliability, Persistent Counter & State Synchronization

## Overview

Phase 4 establishes **Android Native as the single authoritative source of truth** for all Reel counting, persistence, background tracking, and overlay updates.

---

## 1. Architectural Model

```
                Android Native (Authoritative Single Source of Truth)
                                          │
                       ┌──────────────────┴──────────────────┐
                       ▼                                     ▼
            ReelsAccessibilityService                 CounterStorage
            (Scoped to Instagram)                (SharedPreferences:
                       │                           todayCount, totalCount,
                       ▼                           dailyHistory JSON,
                Reel Detection                     todayDate, settings)
                       │                                     ▲
                       ▼                                     │
                 CounterManager ─────────────────────────────┘
                       │
               ┌───────┴───────┐
               ▼               ▼
         OverlayService   FlutterEventBridge
         (WindowManager)  (EventChannel / MethodChannel)
                               │
                               ▼
                            Flutter
                       (Client / View)
```

---

## 2. Native Storage & Data Model (`CounterStorage.kt`)

All tracking state is persisted in Android `SharedPreferences` under `ircmobile_counter_prefs`:

| Key | Type | Description |
|---|---|---|
| `native_today_count` | `Int` | Today's accumulated Reel count. |
| `native_total_count` | `Int` | Lifetime total Reel count. |
| `native_today_date` | `String` | Local date string (`yyyy-MM-dd`) when `today_count` was initialized. |
| `native_daily_history` | `String` (JSON) | Serialized map of `date -> count` (e.g., `{"2026-09-21": 127, "2026-09-20": 184}`). |
| `native_tracking_enabled` | `Boolean` | User preference for accessibility tracking. |
| `native_overlay_enabled` | `Boolean` | User preference for the floating counter overlay. |
| `native_last_updated` | `Long` | Unix timestamp of the last mutation. |

---

## 3. Daily Rollover Logic

The application **does not** rely on unreliable midnight alarm timers.

Instead, on every read or mutation in `CounterStorage`:
1. The current local calendar date (`yyyy-MM-dd`) is computed using `Locale.getDefault()` and device timezone.
2. If `currentDate != storedDate`:
   - If `storedTodayCount > 0`, it is archived into `dailyHistory[storedDate] = storedTodayCount`.
   - `todayCount` is atomically reset to `0`.
   - `todayDate` is updated to `currentDate`.
   - State is committed to `SharedPreferences`.

This guarantees accurate daily tracking even if the device was turned off or the app was closed at midnight.

---

## 4. Background Tracking & Process Independence

1. **Flutter Process Killed / Closed**:
   - `ReelsAccessibilityService` stays active in Android system background.
   - When the user opens Instagram and browses Reels, `ReelTrackingManager` processes transitions.
   - `CounterManager.increment()` atomically updates and persists `todayCount` and `totalCount` to `CounterStorage`.
   - `OverlayService` updates the floating pill in real time.
2. **Flutter App Opened / Resumed**:
   - `ReelsCounterProvider.init()` / `refreshOnResume()` queries native `getTrackingState`.
   - Ingests authoritative `todayCount`, `totalCount`, `dailyHistory`, and toggles.
   - Replaces in-memory values and refreshes Dashboard & Statistics without delay.

---

## 5. MethodChannel & EventChannel Specification

### MethodChannel (`reels_counter/native`)

| Method | Response | Purpose |
|---|---|---|
| `getTrackingState` / `getInitialState` | `Map<String, Any>` | Full state dump (`todayCount`, `totalCount`, `todayDate`, `dailyHistory`, `trackingEnabled`, `overlayEnabled`, `accessibilityEnabled`, `overlayPermissionGranted`). |
| `getTodayCount` | `Int` | Reads authoritative `todayCount`. |
| `getTotalCount` | `Int` | Reads lifetime `totalCount`. |
| `getDailyHistory` | `Map<String, Int>` | Reads date-to-count map. |
| `resetTodayCount` | `Int` (0) | Resets today's count to 0 in storage and updates overlay. |
| `setTrackingEnabled` | `void` | Persists tracking toggle in native storage and service. |
| `setOverlayEnabled` | `void` | Persists overlay toggle in native storage and service. |

### EventChannel (`reels_counter/events`)

When a Reel transition is confirmed, Kotlin emits:
```json
{
  "type": "reelDetected",
  "todayCount": 128,
  "totalCount": 3422,
  "timestamp": 1780000000000,
  "fingerprint": "987654321",
  "confidence": 3,
  "packageName": "com.instagram.android"
}
```
Flutter receives the authoritative count directly in the payload, eliminating race conditions or independent calculation drift.

---

## 6. Device Lifecycle & Limitations

- **App Force Stop**: When a user explicitly force stops Reels Counter in Android Settings, the OS stops all processes and accessibility services until the user manually launches the app. This is standard Android security architecture.
- **Device Restart**: When the phone restarts, Android restores enabled Accessibility Services according to OS policy. On app launch, `CounterStorage` restores persistent counts seamlessly.
- **Battery Optimization**: On certain OEM devices (e.g. Xiaomi, Huawei), battery savers can terminate background services. If encountered, users should allow "Unrestricted background usage" in Android App Info.

---

## 7. Verification Results

```bash
# Android JVM Unit Tests
./gradlew :app:testDebugUnitTest   # 39/39 tests passed

# Flutter Analysis & Unit Tests
flutter analyze                    # 0 issues found
flutter test                       # 40/40 tests passed

# Debug APK Build
flutter build apk --debug          # Built app-debug.apk
```
