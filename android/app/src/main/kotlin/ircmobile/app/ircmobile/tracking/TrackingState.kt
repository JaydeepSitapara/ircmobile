package ircmobile.app.ircmobile.tracking

// ---------------------------------------------------------------------------
// State machine enum representing the lifecycle of Instagram/Reels detection.
// ---------------------------------------------------------------------------
enum class TrackingState {
    /** Instagram is not in the foreground. */
    NOT_INSTAGRAM,

    /** Instagram is foreground but we are not on the Reels screen. */
    INSTAGRAM_OPEN,

    /** Signals suggest Reels, but confidence is below threshold (score = 1). */
    POSSIBLE_REELS,

    /** Reels screen is confirmed (confidence ≥ threshold). Waiting for a Reel
     *  fingerprint to stabilize. */
    REELS_ACTIVE,

    /** A new Reel was just confirmed and is being emitted to Flutter. */
    REEL_COUNTED,

    /** Emitted; waiting for the fingerprint to change again before counting. */
    WAITING_FOR_NEXT
}

// ---------------------------------------------------------------------------
// Event emitted to Flutter when a new Reel is detected.
//
// Only metadata is captured — no personal Instagram content is stored.
// ---------------------------------------------------------------------------
data class ReelDetectedEvent(
    /** Unix epoch milliseconds when detection occurred. */
    val timestamp: Long,

    /** Package name that produced the event (always com.instagram.android). */
    val packageName: String,

    /** Stable hash of visible non-volatile Reel content nodes. Empty string if
     *  no stable nodes were available to fingerprint. */
    val fingerprint: String,

    /** Detection confidence score (0–3) when the Reel was counted. */
    val detectionConfidence: Int
)
