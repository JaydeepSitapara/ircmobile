package ircmobile.app.ircmobile.tracking

import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import ircmobile.app.ircmobile.instagram.InstagramDetector
import ircmobile.app.ircmobile.instagram.ReelChangeDetector
import ircmobile.app.ircmobile.instagram.ReelFingerprintGenerator
import ircmobile.app.ircmobile.instagram.ReelScreenDetector

// ---------------------------------------------------------------------------
// Core state machine for the Reel detection pipeline.
//
// Receives processed events from InstagramEventProcessor and manages the full
// TrackingState lifecycle. Emits ReelDetectedEvents through FlutterEventBridge
// when a new Reel is confirmed.
//
// State transitions:
//
//   NOT_INSTAGRAM
//     ↓  (Instagram foreground)
//   INSTAGRAM_OPEN
//     ↓  (confidence = 1)
//   POSSIBLE_REELS
//     ↓  (confidence ≥ threshold)
//   REELS_ACTIVE ←──────────────────────────────┐
//     ↓  (stable fingerprint, different from last)│
//   REEL_COUNTED                                  │
//     ↓  (emitted)                                │
//   WAITING_FOR_NEXT ─────────────────────────────┘
//
//   Any state → NOT_INSTAGRAM when Instagram closes.
//   REELS_ACTIVE → INSTAGRAM_OPEN when user navigates away from Reels.
// ---------------------------------------------------------------------------
class ReelTrackingManager(
    private val bridge: FlutterEventBridge,
    private val counterManager: ircmobile.app.ircmobile.counter.CounterManager? = null,
    private val overlayService: ircmobile.app.ircmobile.overlay.OverlayService? = null
) {

    private var state: TrackingState = TrackingState.NOT_INSTAGRAM
    private val screenDetector = ReelScreenDetector()
    private val fingerprintGenerator = ReelFingerprintGenerator()
    private val changeDetector = ReelChangeDetector()
    private val debouncer = ReelDebouncer()

    /** Captured from TYPE_WINDOW_STATE_CHANGED events. */
    private var lastWindowTitle: CharSequence? = null

    /** Last confirmed confidence score, exposed for debug UI. */
    private var lastConfidence = 0

    /** Last fingerprint that was emitted, exposed for debug UI. */
    private var lastEmittedFingerprint = ""

    /** Timestamp of the last scroll-triggered Reel count. Used for debouncing. */
    private var lastScrollTime = 0L

    /** When false, all processing is skipped (user disabled tracking in Settings). */
    var isTrackingEnabled: Boolean = true
        set(value) {
            field = value
            if (!value) {
                transitionTo(TrackingState.NOT_INSTAGRAM)
                changeDetector.reset()
                debouncer.reset()
                lastScrollTime = 0L
                log("Tracking disabled")
            }
        }

    // ---------------------------------------------------------------------------
    // Main processing entry point
    // ---------------------------------------------------------------------------

    /**
     * Process one accessibility event.
     *
     * @param event     The raw AccessibilityEvent.
     * @param rootNode  Root of the active window — obtained via
     *                  [AccessibilityService.getRootInActiveWindow].
     */
    fun process(event: AccessibilityEvent, rootNode: AccessibilityNodeInfo?) {
        if (!isTrackingEnabled) return

        val packageName = event.packageName?.toString()

        // ── Not Instagram ─────────────────────────────────────────────────────
        if (!InstagramDetector.isInstagramPackage(packageName)) {
            if (state != TrackingState.NOT_INSTAGRAM) {
                logVerbose("Left Instagram")
                bridge.emitInstagramStatus(false)
                overlayService?.onInstagramVisibilityChanged(false)
                transitionTo(TrackingState.NOT_INSTAGRAM)
                changeDetector.reset()
                debouncer.reset()
                lastScrollTime = 0L
            }
            return
        }

        // ── Instagram is foreground ───────────────────────────────────────────
        if (state == TrackingState.NOT_INSTAGRAM) {
            log("Instagram detected")
            bridge.emitInstagramStatus(true)
            transitionTo(TrackingState.INSTAGRAM_OPEN)
            overlayService?.onInstagramVisibilityChanged(true)
        }

        // Capture window title from TYPE_WINDOW_STATE_CHANGED.
        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            lastWindowTitle = event.text?.firstOrNull()
            logVerbose("Window title: $lastWindowTitle")
        }

        // ── Primary path: TYPE_VIEW_SCROLLED → count the swipe directly ───────
        // This is the most reliable signal that the user swiped to a new Reel.
        if (event.eventType == AccessibilityEvent.TYPE_VIEW_SCROLLED) {
            handleScrollEvent(packageName!!)
            return
        }

        // ── Secondary path: confidence-based Reels screen detection ──────────
        // Only evaluate when rootNode is available (avoid dropping state on null)
        if (rootNode == null) return

        val confidence = screenDetector.getConfidence(rootNode, lastWindowTitle)
        lastConfidence = confidence
        val onReels = confidence >= TrackingConfig.REELS_CONFIDENCE_THRESHOLD

        when {
            !onReels && (state == TrackingState.REELS_ACTIVE ||
                         state == TrackingState.WAITING_FOR_NEXT) -> {
                log("Left Reels screen (confidence=$confidence)")
                bridge.emitReelsScreenStatus(false)
                transitionTo(TrackingState.INSTAGRAM_OPEN)
                changeDetector.reset()
            }

            !onReels -> { /* still on a non-Reels screen — do nothing */ }

            onReels -> {
                if (state == TrackingState.INSTAGRAM_OPEN ||
                    state == TrackingState.POSSIBLE_REELS) {
                    log("Reels screen confirmed (confidence=$confidence)")
                    bridge.emitReelsScreenStatus(true)
                    transitionTo(TrackingState.REELS_ACTIVE)
                }
                // On content changes also attempt fingerprint-based detection
                // as a fallback when no scroll events are delivered.
                evaluateReelChangeByFingerprint(packageName!!, rootNode)
            }
        }
    }

    // ---------------------------------------------------------------------------
    // Primary: scroll-event-based Reel counting
    // ---------------------------------------------------------------------------

    private fun handleScrollEvent(packageName: String) {
        val now = System.currentTimeMillis()

        // Ensure we're at least in INSTAGRAM_OPEN state
        if (state == TrackingState.NOT_INSTAGRAM) return

        // Move to REELS_ACTIVE if we're on Instagram and get a scroll
        if (state == TrackingState.INSTAGRAM_OPEN || state == TrackingState.POSSIBLE_REELS) {
            log("Reels screen implied by scroll event")
            bridge.emitReelsScreenStatus(true)
            transitionTo(TrackingState.REELS_ACTIVE)
        }

        // Debounce: ignore scrolls within SCROLL_DEBOUNCE_MS of the last counted scroll
        val timeSinceLast = now - lastScrollTime
        if (lastScrollTime > 0 && timeSinceLast < TrackingConfig.SCROLL_DEBOUNCE_MS) {
            logVerbose("Scroll debounced: ${timeSinceLast}ms since last count")
            return
        }

        lastScrollTime = now
        countNewReel(packageName, "scroll")
    }

    // ---------------------------------------------------------------------------
    // Secondary: fingerprint-based Reel counting (fallback)
    // ---------------------------------------------------------------------------

    private fun evaluateReelChangeByFingerprint(packageName: String, rootNode: AccessibilityNodeInfo?) {
        val fingerprint = fingerprintGenerator.generate(rootNode)

        if (fingerprint.isEmpty()) {
            logVerbose("Empty fingerprint — waiting for stable content")
            return
        }

        // Require same fingerprint twice in a row to be stable
        val readyToCount = changeDetector.evaluate(fingerprint)
        if (!readyToCount) {
            logVerbose("Fingerprint unstable or unchanged: $fingerprint")
            return
        }

        // Timing gate
        if (!debouncer.shouldProcess()) {
            logVerbose("Debounce: too soon after last fingerprint count")
            return
        }

        debouncer.recordProcessed()
        countNewReel(packageName, "fingerprint:$fingerprint")
        changeDetector.recordCounted(fingerprint)
    }

    // ---------------------------------------------------------------------------
    // Shared count-and-emit logic
    // ---------------------------------------------------------------------------

    private fun countNewReel(packageName: String, source: String) {
        log("New Reel detected via $source")
        lastEmittedFingerprint = source

        val countResult = counterManager?.increment()
        val todayCount = countResult?.todayCount ?: 0
        val totalCount = countResult?.totalCount ?: 0

        overlayService?.updateCounter(todayCount)

        transitionTo(TrackingState.REEL_COUNTED)

        bridge.emitReelDetected(
            ReelDetectedEvent(
                timestamp = countResult?.timestamp ?: System.currentTimeMillis(),
                packageName = packageName,
                fingerprint = source,
                detectionConfidence = lastConfidence
            ),
            todayCount = todayCount,
            totalCount = totalCount
        )

        transitionTo(TrackingState.WAITING_FOR_NEXT)
        transitionTo(TrackingState.REELS_ACTIVE)
    }

    // ---------------------------------------------------------------------------
    // State machine helper
    // ---------------------------------------------------------------------------

    private fun transitionTo(newState: TrackingState) {
        if (state != newState) {
            logVerbose("State: $state → $newState")
        }
        state = newState
        bridge.emitTrackingState(newState)
    }

    // ---------------------------------------------------------------------------
    // Debug / introspection
    // ---------------------------------------------------------------------------

    fun getCurrentState(): TrackingState = state
    fun getLastFingerprint(): String = lastEmittedFingerprint
    fun getConfidence(): Int = lastConfidence
    fun getCurrentFingerprint(): String = changeDetector.getCurrentFingerprint()

    fun getDebugInfo(): Map<String, String> = mapOf(
        "state" to state.name,
        "confidence" to lastConfidence.toString(),
        "lastFingerprint" to lastEmittedFingerprint,
        "currentFingerprint" to changeDetector.getCurrentFingerprint(),
        "trackingEnabled" to isTrackingEnabled.toString()
    )

    private fun log(msg: String) = Log.d(TrackingConfig.DEBUG_LOG_TAG, msg)

    private fun logVerbose(msg: String) {
        if (TrackingConfig.DEBUG_LOGGING) Log.v(TrackingConfig.DEBUG_LOG_TAG, msg)
    }
}
