package ircmobile.app.ircmobile

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import io.flutter.plugin.common.EventChannel
import ircmobile.app.ircmobile.tracking.FlutterEventBridge
import ircmobile.app.ircmobile.tracking.InstagramEventProcessor
import ircmobile.app.ircmobile.tracking.ReelTrackingManager
import ircmobile.app.ircmobile.tracking.TrackingConfig

// ---------------------------------------------------------------------------
// Android AccessibilityService that powers Instagram Reel detection.
//
// The service itself contains minimal logic. All detection is delegated to:
//   InstagramEventProcessor → ReelTrackingManager → FlutterEventBridge
//
// Lifecycle:
//   onServiceConnected()  → initialise components; link to MainActivity bridge
//   onAccessibilityEvent() → forward to processor (error-isolated)
//   onInterrupt()         → log; no special action required
//   onDestroy()           → clear singleton reference
//
// GOOGLE PLAY NOTE:
//   This service observes accessibility events solely to count Reel transitions
//   for the user's own tracking. It does not automate any actions, read
//   private messages, or collect personal data.
// ---------------------------------------------------------------------------
class ReelsAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = TrackingConfig.DEBUG_LOG_TAG

        /** Singleton reference to the running service instance (null when stopped). */
        @Volatile
        private var instance: ReelsAccessibilityService? = null

        /** Returns the active service instance, or null if not running. */
        fun getInstance(): ReelsAccessibilityService? = instance

        /** True only when the service is connected and operational. */
        fun isRunning(): Boolean = instance != null
    }

    private lateinit var bridge: FlutterEventBridge
    private lateinit var manager: ReelTrackingManager
    private lateinit var processor: InstagramEventProcessor

    // ---------------------------------------------------------------------------
    // Lifecycle
    // ---------------------------------------------------------------------------

    override fun onServiceConnected() {
        instance = this

        bridge = FlutterEventBridge()
        val counterManager = ircmobile.app.ircmobile.counter.CounterManager.getInstance(this)
        val overlayService = ircmobile.app.ircmobile.overlay.OverlayService.getInstance(this)
        manager = ReelTrackingManager(bridge, counterManager, overlayService)
        processor = InstagramEventProcessor(manager)

        // Initialize tracking & overlay enabled state from persisted storage
        manager.isTrackingEnabled = counterManager.isTrackingEnabled()
        overlayService.setOverlayEnabled(counterManager.isOverlayEnabled())

        // Preserve and enhance service configuration
        val info = serviceInfo ?: AccessibilityServiceInfo()
        info.eventTypes = (AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED
                or AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED
                or AccessibilityEvent.TYPE_VIEW_SCROLLED)
        info.feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
        info.flags = info.flags or (AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS
                or AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS
                or AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS)
        info.notificationTimeout = 100L
        info.packageNames = arrayOf("com.instagram.android")
        serviceInfo = info

        // Attach event bridge to MainActivity if it is already running.
        MainActivity.getInstance()?.onServiceConnected(bridge)

        Log.d(TAG, "ReelsAccessibilityService connected (trackingEnabled=${manager.isTrackingEnabled}, overlayEnabled=${counterManager.isOverlayEnabled()})")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        try {
            // Obtain the root of the current active window.
            // getRootInActiveWindow() can return null (e.g., during rapid navigation).
            val rootNode = try { getRootInActiveWindow() } catch (_: Exception) { null }
            processor.process(event, rootNode)
        } catch (e: Exception) {
            // Never crash the host app due to a detection failure.
            Log.e(TAG, "Error processing accessibility event: ${e.message}")
        }
    }

    override fun onInterrupt() {
        Log.d(TAG, "ReelsAccessibilityService interrupted")
    }

    override fun onDestroy() {
        instance = null
        Log.d(TAG, "ReelsAccessibilityService destroyed")
        super.onDestroy()
    }

    // ---------------------------------------------------------------------------
    // Called by MainActivity to attach / detach the EventChannel sink
    // ---------------------------------------------------------------------------

    fun attachEventSink(sink: EventChannel.EventSink?) {
        bridge.setEventSink(sink)
    }

    // ---------------------------------------------------------------------------
    // Tracking control (called via MethodChannel from Flutter Settings)
    // ---------------------------------------------------------------------------

    fun setTrackingEnabled(enabled: Boolean) {
        manager.isTrackingEnabled = enabled
        ircmobile.app.ircmobile.counter.CounterManager.getInstance(this).setTrackingEnabled(enabled)
        Log.d(TAG, "Tracking ${if (enabled) "enabled" else "disabled"} by user")
    }

    fun isTrackingEnabled(): Boolean = manager.isTrackingEnabled

    // ---------------------------------------------------------------------------
    // Debug introspection
    // ---------------------------------------------------------------------------

    fun getDebugInfo(): Map<String, String> = manager.getDebugInfo()
}
