package ircmobile.app.ircmobile.tracking

// ---------------------------------------------------------------------------
// Timing gate that prevents counting the same Reel from multiple rapid
// accessibility events.
//
// The debouncer is a SECONDARY mechanism. The primary guard is fingerprint
// comparison in ReelChangeDetector. The debouncer protects against edge cases
// where two different fingerprints could be generated within milliseconds for
// the same Reel (e.g., if the accessibility tree updates mid-render).
// ---------------------------------------------------------------------------
open class ReelDebouncer {

    private var lastProcessedTime = 0L

    /**
     * Returns true if enough time has elapsed since the last processed Reel
     * to allow a new one to be counted.
     */
    fun shouldProcess(): Boolean {
        val now = currentTimeMs()
        return (now - lastProcessedTime) >= TrackingConfig.MIN_REEL_TRANSITION_INTERVAL_MS
    }

    /** Records that a Reel was just counted. Call immediately after counting. */
    fun recordProcessed() {
        lastProcessedTime = currentTimeMs()
    }

    /** Resets the timer — called when leaving the Reels screen. */
    fun reset() {
        lastProcessedTime = 0L
    }

    /** Overridable for testing without Thread.sleep(). */
    protected open fun currentTimeMs(): Long = System.currentTimeMillis()
}
