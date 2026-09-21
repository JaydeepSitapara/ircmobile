package ircmobile.app.ircmobile.instagram

import android.view.accessibility.AccessibilityNodeInfo
import ircmobile.app.ircmobile.tracking.TrackingConfig

// ---------------------------------------------------------------------------
// Determines whether the current Instagram screen is the Reels experience.
//
// Instagram has many screens (Home, Explore, Reels, DMs, Profile, Stories…).
// We must not count any screen other than Reels.
//
// Detection strategy — multi-signal confidence scoring (0–3):
//
//   Signal 1 (+1): Window title / class contains Reels-related text.
//   Signal 2 (+1): Accessibility tree contains Reels-positive signals
//                  (audio labels, "reel" text, Reels action descriptions).
//   Signal 3 (+1): A video surface (SurfaceView / TextureView) is present,
//                  indicating full-screen video playback.
//   Disqualifier: Non-Reels negative signals (DMs, Edit Profile, Stories
//                 composer, etc.) immediately return confidence = 0.
//
// Confidence ≥ [TrackingConfig.REELS_CONFIDENCE_THRESHOLD] → Reels screen.
//
// MAINTAINABILITY NOTE:
//   When Instagram changes its UI, update InstagramAccessibilityParser's
//   signal lists (NON_REELS_NEGATIVE_SIGNALS / REELS_POSITIVE_SIGNALS)
//   and/or the window-title keywords in this file.
// ---------------------------------------------------------------------------
class ReelScreenDetector {

    // Keywords in the window title that suggest the Reels screen.
    private val WINDOW_TITLE_REELS_KEYWORDS = listOf("reel", "reels", "video", "watch", "clips")

    // ---------------------------------------------------------------------------
    // Public API
    // ---------------------------------------------------------------------------

    /**
     * Returns a confidence score in [0, 3] for the likelihood that the user is
     * currently on the Instagram Reels screen.
     *
     * @param rootNode  Root of the current accessibility window. Null → 0.
     * @param windowTitle  Title/text from the last TYPE_WINDOW_STATE_CHANGED event.
     */
    fun getConfidence(rootNode: AccessibilityNodeInfo?, windowTitle: CharSequence?): Int {
        if (rootNode == null) return 0

        // Disqualifier: strong non-Reels screen signals.
        if (InstagramAccessibilityParser.hasNonReelsSignal(rootNode)) return 0

        var confidence = 0

        // Signal 1: Window title
        val titleLower = windowTitle?.toString()?.lowercase() ?: ""
        if (WINDOW_TITLE_REELS_KEYWORDS.any { titleLower.contains(it) }) {
            confidence++
        }

        // Signal 2: Positive Reels signals in accessibility nodes.
        val positiveCount = InstagramAccessibilityParser.countReelsPositiveSignals(rootNode)
        if (positiveCount >= 2) {
            confidence += 2
        } else if (positiveCount >= 1) {
            confidence += 1
        }

        // Signal 3: Video surface present (full-screen video playback).
        if (InstagramAccessibilityParser.containsVideoNode(rootNode)) {
            confidence++
        }

        return confidence.coerceAtMost(3)
    }

    /**
     * Convenience wrapper. Returns true when confidence meets the threshold.
     */
    fun isReelsScreen(rootNode: AccessibilityNodeInfo?, windowTitle: CharSequence?): Boolean =
        getConfidence(rootNode, windowTitle) >= TrackingConfig.REELS_CONFIDENCE_THRESHOLD
}
