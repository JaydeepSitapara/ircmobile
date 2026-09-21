# Phase 2 — Android Native Reel Detection

## Architecture

```
onAccessibilityEvent()
        │
        ▼
InstagramEventProcessor       ← event type filter + package filter
        │
        ▼
ReelTrackingManager           ← owns the TrackingState state machine
   ├── ReelScreenDetector     ← multi-signal confidence (0–3)
   ├── ReelFingerprintGenerator ← stable hash of Reel content nodes
   ├── ReelChangeDetector     ← two-step stabilisation + duplicate guard
   └── ReelDebouncer          ← timing gate (secondary guard)
        │
        ▼
FlutterEventBridge            ← thread-safe EventChannel sink writer
        │
        ▼
Flutter ReelsCounterProvider  ← todayCount++ on "reelDetected"
```

All Kotlin files live under:
```
android/app/src/main/kotlin/ircmobile/app/ircmobile/
├── instagram/
│   ├── InstagramDetector.kt
│   ├── InstagramAccessibilityParser.kt
│   ├── ReelScreenDetector.kt
│   ├── ReelFingerprintGenerator.kt
│   └── ReelChangeDetector.kt
└── tracking/
    ├── TrackingConfig.kt
    ├── TrackingState.kt
    ├── ReelDebouncer.kt
    ├── FlutterEventBridge.kt
    ├── InstagramEventProcessor.kt
    └── ReelTrackingManager.kt
```

---

## AccessibilityService Setup

### Manifest declaration (`AndroidManifest.xml`)
```xml
<service
    android:name=".ReelsAccessibilityService"
    android:exported="true"
    android:permission="android.permission.BIND_ACCESSIBILITY_SERVICE">
    <intent-filter>
        <action android:name="android.accessibilityservice.AccessibilityService" />
    </intent-filter>
    <meta-data
        android:name="android.accessibilityservice"
        android:resource="@xml/accessibility_service_config" />
</service>
```

### Accessibility XML config (`res/xml/accessibility_service_config.xml`)
```xml
android:packageNames="com.instagram.android"
```

> **Critical:** The `packageNames` attribute means the Android system delivers
> events **only from Instagram**. Events from all other apps (Chrome, Messages,
> etc.) are filtered at the OS level — the service never sees them.

### Event types requested
| Event | Reason |
|---|---|
| `TYPE_WINDOW_STATE_CHANGED` | Navigation between Instagram screens |
| `TYPE_WINDOW_CONTENT_CHANGED` | Content updates within a screen |
| `TYPE_VIEW_SCROLLED` | User swiped to next/previous Reel |

---

## Detection Strategy

### Step 1 — Instagram Package Check
`InstagramDetector.isInstagramPackage()` — O(1) string equality.
Non-Instagram packages exit immediately.

### Step 2 — Reels Screen Detection (confidence 0–3)
`ReelScreenDetector.getConfidence()` evaluates three independent signals:

| Signal | How | Weight |
|---|---|---|
| Window title | TYPE_WINDOW_STATE_CHANGED text contains "reel"/"video" | +1 |
| Positive node signals | Accessibility tree contains "audio", "reel", etc. | +1 |
| Video surface | SurfaceView / TextureView present in tree | +1 |

**Negative disqualifiers** (any match → confidence = 0):
- "direct", "message", "edit profile", "new post", "followers", etc.

Threshold: confidence ≥ 2 → Reels screen confirmed.

### Step 3 — Reel Fingerprinting
`ReelFingerprintGenerator.generate()`:
1. Extract stable text tokens from the accessibility tree (creator name, caption, audio label)
2. Filter volatile elements (like counts, "ago", "follow", etc.)
3. Sort tokens (order-independent)
4. Hash the joined string
5. Return empty string if fewer than 2 tokens found

### Step 4 — Change Detection (two-step stabilisation)
`ReelChangeDetector.evaluate()`:
- A fingerprint must appear in **two consecutive events** to be considered stable
- A stable fingerprint that differs from the last counted one → triggers count
- Prevents counting during brief transition states between Reels

### Step 5 — Debounce (secondary guard)
`ReelDebouncer.shouldProcess()`:
- Minimum 500ms between counts (configurable in `TrackingConfig`)
- Guards against edge cases where two different fingerprints are generated
  within milliseconds for the same Reel (mid-render tree changes)

---

## State Machine

```
NOT_INSTAGRAM
      │  (Instagram foreground)
      ▼
INSTAGRAM_OPEN
      │  (confidence = 1)
      ▼
POSSIBLE_REELS
      │  (confidence ≥ 2)
      ▼
REELS_ACTIVE ◄──────────────────────────────────┐
      │  (stable fingerprint, != last counted)   │
      │  (debounce passes)                        │
      ▼                                           │
REEL_COUNTED                                      │
      │                                           │
      ▼                                           │
WAITING_FOR_NEXT ───────────────────────────────►┘
```

Additional transitions:
- Any state → NOT_INSTAGRAM when non-Instagram event arrives
- REELS_ACTIVE → INSTAGRAM_OPEN when confidence drops below threshold

---

## Flutter ↔ Kotlin Event Types

### EventChannel (Kotlin → Flutter)
| type | Payload | Meaning |
|---|---|---|
| `reelDetected` | `fingerprint`, `confidence`, `timestamp` | New Reel confirmed |
| `instagramDetected` | — | Instagram came to foreground |
| `instagramClosed` | — | Instagram went to background |
| `reelsScreenActive` | — | Reels screen confirmed |
| `reelsScreenInactive` | — | Left Reels screen |
| `trackingState` | `state` (enum name) | State machine transitioned |

### MethodChannel (Flutter → Kotlin)
| Method | Returns | Description |
|---|---|---|
| `isAccessibilityServiceEnabled` | `bool` | Checks `ENABLED_ACCESSIBILITY_SERVICES` |
| `openAccessibilitySettings` | `void` | Opens system Accessibility settings |
| `isOverlayPermissionGranted` | `bool` | Checks `Settings.canDrawOverlays()` |
| `openOverlaySettings` | `void` | Opens overlay permission settings |
| `startTracking` | `void` | Enables tracking in service |
| `stopTracking` | `void` | Disables tracking in service |
| `getTrackingStatus` | `Map` | Returns `serviceRunning`, `accessibilityEnabled`, `trackingEnabled`, `debugInfo` |

---

## Logcat Debugging

```bash
# Filter to Reel tracking logs only
adb logcat -s ReelTracker

# Full verbose output for Reel tracking
adb logcat -v time ReelTracker:V *:S
```

### Expected log sequence (Reels detected)
```
ReelTracker D  Instagram detected
ReelTracker D  Reels screen confirmed (confidence=2)
ReelTracker V  Fingerprint not yet stable: 123456789
ReelTracker V  Fingerprint not yet stable: 123456789
ReelTracker D  New Reel detected — fingerprint=123456789 confidence=2
ReelTracker D  Instagram detected       ← next Reel after swipe
ReelTracker V  Fingerprint not yet stable: 987654321
ReelTracker D  New Reel detected — fingerprint=987654321 confidence=3
```

### Print accessibility tree (debug builds)
In `onAccessibilityEvent()`, temporarily call:
```kotlin
InstagramAccessibilityParser.printNodeTree(rootNode)
```
This prints a 4-level deep tree to Logcat. Use this when Instagram updates
its UI and detection needs recalibration.

---

## Known Limitations

### 1. Zero accessible text in some Reels
If Instagram renders a Reel with all text on a Canvas (not TextView nodes),
`ReelFingerprintGenerator.generate()` returns `""` and that Reel is skipped.
**Frequency:** Rare; most Reels have at least a creator name or audio label
accessible to the Accessibility API.

### 2. Instagram UI changes break signals
Instagram frequently updates its UI. If signals change:
- Update `InstagramAccessibilityParser.REELS_POSITIVE_SIGNALS`
- Update `InstagramAccessibilityParser.NON_REELS_NEGATIVE_SIGNALS`
- Update `ReelScreenDetector.WINDOW_TITLE_REELS_KEYWORDS`
- Re-run on-device testing

### 3. Very fast scrolling may miss Reels
If a user scrolls through 5 Reels in under 500ms total, some may be missed
because the fingerprint stabilisation requires 2 consecutive same-fingerprint
events AND the debounce interval. This is intentional — extremely brief Reels
are not meaningful "views".

### 4. ReelTrackingManagerTest is partial
`AccessibilityNodeInfo` is an Android framework class that returns null/0 in
JVM unit tests. Tests that exercise Reel counting (which requires real node
content) must run on-device. The JVM tests cover: state transitions, package
detection, debouncer, and change detector.

### 5. Instagram beta / Lite not supported
Only `com.instagram.android` is detected. Instagram Lite (`com.instagram.lite`)
is documented as a known limitation in `InstagramDetector`.

---

## Manual Testing Procedure

### Build & Install
```bash
flutter build apk --debug
adb install build/app/outputs/flutter-apk/app-debug.apk
```

### Setup
1. Open **Reels Counter** app
2. Tap "Open Accessibility Settings" banner
3. Find "Reels Counter" in the list → enable it
4. Return to app → "Accessibility On" chip turns green

### Functional Testing
1. Watch Logcat: `adb logcat -s ReelTracker`
2. Open Instagram → open Reels tab
3. Watch Logcat for "Reels screen confirmed"
4. Scroll through 3 Reels slowly (~1s each)
5. Return to Reels Counter → counter should show **3**
6. Verify Debug Panel shows correct state

### Negative Testing (must NOT count)
| Screen | Expected count change |
|---|---|
| Instagram Home feed | 0 |
| Instagram Explore/Search | 0 |
| Instagram Stories | 0 |
| Instagram DMs | 0 |
| Instagram Profile | 0 |
| Any non-Instagram app | 0 |

### Logcat Quick Reference
```bash
# All tracking events
adb logcat -s ReelTracker

# With timestamps
adb logcat -v time -s ReelTracker

# Print accessibility tree (requires debug build + manual call)
# Look for "=== Accessibility Tree ===" in output
```
