package ircmobile.app.ircmobile.instagram

// ---------------------------------------------------------------------------
// Tracks fingerprint state to determine when the visible Reel has changed.
//
// Two-step stabilisation:
//   1. A "pending" fingerprint is updated on every event.
//   2. A fingerprint is "stable" when it matches the pending value from the
//      previous event (two consecutive identical fingerprints).
//   3. Only a stable fingerprint that differs from the last counted one
//      triggers a Reel count.
//
// This prevents premature counts during the brief transition between Reels
// (where the accessibility tree may flash intermediate states).
// ---------------------------------------------------------------------------
class ReelChangeDetector {

    /** The fingerprint that was most recently counted. */
    private var lastCountedFingerprint: String = ""

    /** The fingerprint seen in the previous event cycle. */
    private var previousFingerprint: String = ""

    /** The fingerprint seen in the current event cycle. */
    private var currentFingerprint: String = ""

    /**
     * Updates internal state with the latest [fingerprint] and returns true
     * if it has stabilised (appeared in two consecutive calls) AND differs
     * from the last counted fingerprint.
     *
     * Returns false when:
     * - [fingerprint] is empty (no stable data available).
     * - [fingerprint] equals the last counted value (same Reel).
     * - [fingerprint] has not yet appeared twice in a row (still transitioning).
     */
    fun evaluate(fingerprint: String): Boolean {
        if (fingerprint.isEmpty()) {
            previousFingerprint = ""
            currentFingerprint = ""
            return false
        }

        val stabilised = fingerprint == currentFingerprint
        previousFingerprint = currentFingerprint
        currentFingerprint = fingerprint

        if (!stabilised) return false
        return fingerprint != lastCountedFingerprint
    }

    /** Records [fingerprint] as the last successfully counted Reel. */
    fun recordCounted(fingerprint: String) {
        lastCountedFingerprint = fingerprint
    }

    /** Resets all state — called when leaving the Reels screen. */
    fun reset() {
        lastCountedFingerprint = ""
        previousFingerprint = ""
        currentFingerprint = ""
    }

    fun getLastCountedFingerprint(): String = lastCountedFingerprint
    fun getCurrentFingerprint(): String = currentFingerprint
}
