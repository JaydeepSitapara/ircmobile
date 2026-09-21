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

    /** When false, all processing is skipped (user disabled tracking in Settings). */
    var isTrackingEnabled: Boolean = true
        set(value) {
            field = value
            if (!value) {
                transitionTo(TrackingState.NOT_INSTAGRAM)
                changeDetector.reset()
                debouncer.reset()
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
                overlayService?.onReelsScreenVisibilityChanged(false)
                transitionTo(TrackingState.NOT_INSTAGRAM)
                changeDetector.reset()
                debouncer.reset()
            }
            return
        }

        // ── Instagram is foreground ───────────────────────────────────────────
        if (state == TrackingState.NOT_INSTAGRAM) {
            log("Instagram detected")
            bridge.emitInstagramStatus(true)
            transitionTo(TrackingState.INSTAGRAM_OPEN)
        }

        // Capture window title for screen detection Signal 1.
        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            lastWindowTitle = event.text?.firstOrNull()
            logVerbose("Window title: $lastWindowTitle")
        }

        // ── Evaluate Reels screen confidence ─────────────────────────────────
        val confidence = screenDetector.getConfidence(rootNode, lastWindowTitle)
        lastConfidence = confidence
        val onReels = confidence >= TrackingConfig.REELS_CONFIDENCE_THRESHOLD

        when {
            // ── Left Reels screen ─────────────────────────────────────────────
            !onReels && (state == TrackingState.REELS_ACTIVE ||
                         state == TrackingState.WAITING_FOR_NEXT) -> {
                log("Left Reels screen (confidence=$confidence)")
                bridge.emitReelsScreenStatus(false)
                overlayService?.onReelsScreenVisibilityChanged(false)
                transitionTo(TrackingState.INSTAGRAM_OPEN)
                changeDetector.reset()
            }

            !onReels && state == TrackingState.POSSIBLE_REELS -> {
                overlayService?.onReelsScreenVisibilityChanged(false)
                transitionTo(TrackingState.INSTAGRAM_OPEN)
            }

            !onReels -> return   // still on a non-Reels screen — nothing to do

            // ── Possible Reels (confidence = 1) ───────────────────────────────
            confidence == 1 && state == TrackingState.INSTAGRAM_OPEN -> {
                logVerbose("Possible Reels (confidence=1)")
                transitionTo(TrackingState.POSSIBLE_REELS)
            }

            // ── Reels screen confirmed ─────────────────────────────────────────
            onReels -> {
                if (state == TrackingState.INSTAGRAM_OPEN ||
                    state == TrackingState.POSSIBLE_REELS) {
                    log("Reels screen confirmed (confidence=$confidence)")
                    bridge.emitReelsScreenStatus(true)
                    overlayService?.onReelsScreenVisibilityChanged(true)
                    transitionTo(TrackingState.REELS_ACTIVE)
                }
                evaluateReelChange(packageName!!, rootNode)
            }
        }
    }

    // ---------------------------------------------------------------------------
    // Reel change evaluation
    // ---------------------------------------------------------------------------

    private fun evaluateReelChange(packageName: String, rootNode: AccessibilityNodeInfo?) {
        val fingerprint = fingerprintGenerator.generate(rootNode)

        if (fingerprint.isEmpty()) {
            logVerbose("Empty fingerprint — waiting for stable content")
            return
        }

        // Two-step stabilisation: requires same fingerprint in two consecutive events.
        val readyToCount = changeDetector.evaluate(fingerprint)

        if (!readyToCount) {
            logVerbose("Fingerprint not yet stable or unchanged: $fingerprint")
            return
        }

        // Timing gate (secondary protection).
        if (!debouncer.shouldProcess()) {
            logVerbose("Debounce: event too soon after last count")
            return
        }

        // ── New Reel confirmed ─────────────────────────────────────────────────
        log("New Reel detected — fingerprint=$fingerprint confidence=$lastConfidence")
        changeDetector.recordCounted(fingerprint)
        debouncer.recordProcessed()
        lastEmittedFingerprint = fingerprint

        // Increment native counter and update overlay
        val countResult = counterManager?.increment()
        val todayCount = countResult?.todayCount ?: 0
        val totalCount = countResult?.totalCount ?: 0

        if (countResult != null) {
            overlayService?.updateCounter(todayCount)
        }

        transitionTo(TrackingState.REEL_COUNTED)

        bridge.emitReelDetected(
            ReelDetectedEvent(
                timestamp = countResult?.timestamp ?: System.currentTimeMillis(),
                packageName = packageName,
                fingerprint = fingerprint,
                detectionConfidence = lastConfidence
            ),
            todayCount = todayCount,
            totalCount = totalCount
        )

        // Immediately return to REELS_ACTIVE so the next Reel can be detected.
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
