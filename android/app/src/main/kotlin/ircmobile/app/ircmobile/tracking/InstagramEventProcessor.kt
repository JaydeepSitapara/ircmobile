package ircmobile.app.ircmobile.tracking

import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import ircmobile.app.ircmobile.instagram.InstagramDetector

// ---------------------------------------------------------------------------
// First filter in the pipeline. Receives raw AccessibilityEvents from the
// service and discards irrelevant ones before passing to ReelTrackingManager.
//
// Filtering strategy:
//   1. Null events → discard.
//   2. Event types not in RELEVANT_EVENT_TYPES → discard.
//   3. Non-Instagram package → pass through (manager needs to know Instagram
//      closed) but with null rootNode.
//   4. Instagram events → pass through with rootNode.
// ---------------------------------------------------------------------------
class InstagramEventProcessor(private val manager: ReelTrackingManager) {

    companion object {
        /**
         * Only these event types carry information relevant to Reel detection.
         * Processing every event type would waste CPU and battery.
         *
         *  TYPE_WINDOW_STATE_CHANGED  → navigation between Instagram screens
         *  TYPE_WINDOW_CONTENT_CHANGED → content update within a screen
         *  TYPE_VIEW_SCROLLED          → user swiped to next/previous Reel
         */
        private val RELEVANT_EVENT_TYPES = intArrayOf(
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED,
            AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED,
            AccessibilityEvent.TYPE_VIEW_SCROLLED
        )
    }

    /**
     * Process one raw accessibility event.
     *
     * [rootNode] must be obtained from
     * [AccessibilityService.getRootInActiveWindow] by the caller (the service
     * has direct access; the processor does not).
     */
    fun process(event: AccessibilityEvent?, rootNode: AccessibilityNodeInfo?) {
        if (event == null) return

        // Discard irrelevant event types early.
        if (event.eventType !in RELEVANT_EVENT_TYPES) return

        val packageName = event.packageName?.toString()

        // For non-Instagram events, pass to manager with null node so the state
        // machine can detect that Instagram has gone to the background.
        if (!InstagramDetector.isInstagramPackage(packageName)) {
            manager.process(event, null)
            return
        }

        // Instagram event: pass with window root for full analysis.
        manager.process(event, rootNode)
    }

    // ---------------------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------------------

    private operator fun IntArray.contains(value: Int): Boolean =
        this.any { it == value }
}
