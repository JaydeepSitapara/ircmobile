package ircmobile.app.ircmobile.tracking

import ircmobile.app.ircmobile.BuildConfig

// ---------------------------------------------------------------------------
// Central configuration for all tunable tracking constants.
//
// When Instagram changes its UI and detection needs tuning, adjust these
// values without touching detection logic.
// ---------------------------------------------------------------------------
object TrackingConfig {

    /** Minimum milliseconds between counting two different Reels. Prevents
     *  duplicate counts from rapid accessibility events for the same Reel. */
    const val MIN_REEL_TRANSITION_INTERVAL_MS = 500L

    /** How many consecutive events must produce the same fingerprint before
     *  we treat it as a stable, confirmed Reel. */
    const val FINGERPRINT_STABILITY_THRESHOLD = 2

    /** Minimum confidence score (0–3) required to treat the current screen
     *  as the Reels screen. */
    const val REELS_CONFIDENCE_THRESHOLD = 1

    /** Maximum depth to traverse the accessibility node tree. Deep traversals
     *  are expensive; Instagram's relevant nodes are typically within 6 levels. */
    const val MAX_NODE_TRAVERSE_DEPTH = 7

    /** Maximum number of text tokens used to compute the Reel fingerprint. */
    const val FINGERPRINT_NODE_LIMIT = 12

    /** Logcat tag used for all tracking-related log output. */
    const val DEBUG_LOG_TAG = "ReelTracker"

    /** Enable verbose debug logging. Automatically false in release builds. */
    val DEBUG_LOGGING: Boolean = BuildConfig.DEBUG
}
