package ircmobile.app.ircmobile

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import android.view.accessibility.AccessibilityManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import ircmobile.app.ircmobile.tracking.FlutterEventBridge

// ---------------------------------------------------------------------------
// Main Flutter activity.
//
// Responsibilities:
//   1. Register MethodChannel — answers Flutter's method calls (permission
//      queries, settings navigation, tracking control).
//   2. Register EventChannel — provides the stream sink to FlutterEventBridge
//      so native events reach Flutter in real time.
//   3. Coordinate between the FlutterEventBridge and the AccessibilityService
//      across the Activity ↔ Service lifecycle boundary.
// ---------------------------------------------------------------------------
class MainActivity : FlutterActivity() {

    companion object {
        private const val METHOD_CHANNEL = "reels_counter/native"
        private const val EVENT_CHANNEL = "reels_counter/events"

        @Volatile
        private var instance: MainActivity? = null

        /** Returns the current MainActivity, or null if not created. */
        fun getInstance(): MainActivity? = instance
    }

    /** Current EventChannel sink (non-null while Flutter is listening). */
    private var eventSink: EventChannel.EventSink? = null

    /** Holds the bridge reference so we can attach a new sink when the
     *  service connects after the activity is already running. */
    private var currentBridge: FlutterEventBridge? = null

    // ---------------------------------------------------------------------------
    // Flutter engine setup
    // ---------------------------------------------------------------------------

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        instance = this
        setupMethodChannel(flutterEngine)
        setupEventChannel(flutterEngine)
    }

    override fun onDestroy() {
        if (instance === this) instance = null
        super.onDestroy()
    }

    // ---------------------------------------------------------------------------
    // MethodChannel
    // ---------------------------------------------------------------------------

    private fun setupMethodChannel(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    "isAccessibilityServiceEnabled" ->
                        result.success(isAccessibilityServiceEnabled())

                    "openAccessibilitySettings" -> {
                        startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                        result.success(null)
                    }

                    "isOverlayPermissionGranted" ->
                        result.success(Settings.canDrawOverlays(this))

                    "openOverlaySettings" -> {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName")
                        )
                        startActivity(intent)
                        result.success(null)
                    }

                    "startTracking" -> {
                        ircmobile.app.ircmobile.counter.CounterManager.getInstance(this).setTrackingEnabled(true)
                        ReelsAccessibilityService.getInstance()?.setTrackingEnabled(true)
                        result.success(null)
                    }

                    "stopTracking" -> {
                        ircmobile.app.ircmobile.counter.CounterManager.getInstance(this).setTrackingEnabled(false)
                        ReelsAccessibilityService.getInstance()?.setTrackingEnabled(false)
                        result.success(null)
                    }

                    "setTrackingEnabled" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: true
                        ircmobile.app.ircmobile.counter.CounterManager.getInstance(this).setTrackingEnabled(enabled)
                        ReelsAccessibilityService.getInstance()?.setTrackingEnabled(enabled)
                        result.success(null)
                    }

                    "setOverlayEnabled" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: true
                        ircmobile.app.ircmobile.counter.CounterManager.getInstance(this).setOverlayEnabled(enabled)
                        ircmobile.app.ircmobile.overlay.OverlayService.getInstance(this).setOverlayEnabled(enabled)
                        result.success(null)
                    }

                    "getTrackingState", "getInitialState" -> {
                        val counter = ircmobile.app.ircmobile.counter.CounterManager.getInstance(this)
                        val service = ReelsAccessibilityService.getInstance()
                        val overlay = ircmobile.app.ircmobile.overlay.OverlayService.getInstance(this)
                        val state = counter.getFullState().toMutableMap()
                        state["serviceRunning"] = (service != null)
                        state["accessibilityEnabled"] = isAccessibilityServiceEnabled()
                        state["overlayPermissionGranted"] = Settings.canDrawOverlays(this)
                        state["overlayShowing"] = overlay.isOverlayShowing()
                        result.success(state)
                    }

                    "getTrackingStatus" -> {
                        val service = ReelsAccessibilityService.getInstance()
                        val counter = ircmobile.app.ircmobile.counter.CounterManager.getInstance(this)
                        result.success(
                            mapOf(
                                "serviceRunning" to (service != null),
                                "accessibilityEnabled" to isAccessibilityServiceEnabled(),
                                "trackingEnabled" to counter.isTrackingEnabled(),
                                "debugInfo" to (service?.getDebugInfo() ?: emptyMap<String, String>())
                            )
                        )
                    }

                    "startOverlay", "showOverlay" -> {
                        ircmobile.app.ircmobile.counter.CounterManager.getInstance(this).setOverlayEnabled(true)
                        ircmobile.app.ircmobile.overlay.OverlayService.getInstance(this).setOverlayEnabled(true)
                        result.success(null)
                    }

                    "stopOverlay", "hideOverlay" -> {
                        ircmobile.app.ircmobile.counter.CounterManager.getInstance(this).setOverlayEnabled(false)
                        ircmobile.app.ircmobile.overlay.OverlayService.getInstance(this).setOverlayEnabled(false)
                        result.success(null)
                    }

                    "syncCount" -> {
                        val count = call.argument<Int>("count") ?: 0
                        ircmobile.app.ircmobile.counter.CounterManager.getInstance(this).setTodayCount(count)
                        ircmobile.app.ircmobile.overlay.OverlayService.getInstance(this).updateCounter(count)
                        result.success(null)
                    }

                    "getCurrentCount", "getTodayCount" -> {
                        val count = ircmobile.app.ircmobile.counter.CounterManager.getInstance(this).getTodayCount()
                        result.success(count)
                    }

                    "getTotalCount" -> {
                        val count = ircmobile.app.ircmobile.counter.CounterManager.getInstance(this).getTotalCount()
                        result.success(count)
                    }

                    "getDailyHistory" -> {
                        val history = ircmobile.app.ircmobile.counter.CounterManager.getInstance(this).getDailyHistory()
                        result.success(history)
                    }

                    "resetTodayCount", "resetToday" -> {
                        val count = ircmobile.app.ircmobile.counter.CounterManager.getInstance(this).resetToday()
                        ircmobile.app.ircmobile.overlay.OverlayService.getInstance(this).updateCounter(0)
                        result.success(count)
                    }

                    "getOverlayStatus" -> {
                        val overlay = ircmobile.app.ircmobile.overlay.OverlayService.getInstance(this)
                        val pos = ircmobile.app.ircmobile.overlay.OverlayPosition.load(this)
                        result.success(
                            mapOf(
                                "overlayEnabled" to overlay.isOverlayEnabled(),
                                "overlayShowing" to overlay.isOverlayShowing(),
                                "permissionGranted" to overlay.hasOverlayPermission(),
                                "positionX" to pos.x,
                                "positionY" to pos.y
                            )
                        )
                    }

                    "setOverlayPosition" -> {
                        val x = call.argument<Int>("x") ?: 0
                        val y = call.argument<Int>("y") ?: 0
                        ircmobile.app.ircmobile.overlay.OverlayPosition.save(
                            this,
                            ircmobile.app.ircmobile.overlay.OverlayPosition(x, y)
                        )
                        result.success(null)
                    }

                    "getOverlayPosition" -> {
                        val pos = ircmobile.app.ircmobile.overlay.OverlayPosition.load(this)
                        result.success(mapOf("x" to pos.x, "y" to pos.y))
                    }

                    else -> result.notImplemented()
                }
            }
    }

    // ---------------------------------------------------------------------------
    // EventChannel
    // ---------------------------------------------------------------------------

    private fun setupEventChannel(engine: FlutterEngine) {
        EventChannel(engine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {

                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    // Attach to whatever bridge is currently active.
                    currentBridge?.setEventSink(events)
                    ReelsAccessibilityService.getInstance()?.attachEventSink(events)
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                    currentBridge?.setEventSink(null)
                }
            })
    }

    // ---------------------------------------------------------------------------
    // Called by ReelsAccessibilityService when it connects
    // ---------------------------------------------------------------------------

    /** The service calls this from onServiceConnected() to hand over its bridge. */
    fun onServiceConnected(bridge: FlutterEventBridge) {
        currentBridge = bridge
        // If Flutter is already listening, attach the sink immediately.
        bridge.setEventSink(eventSink)
    }

    // ---------------------------------------------------------------------------
    // Accessibility permission check
    // ---------------------------------------------------------------------------

    private fun isAccessibilityServiceEnabled(): Boolean {
        return try {
            val am = getSystemService(Context.ACCESSIBILITY_SERVICE) as AccessibilityManager
            if (!am.isEnabled) return false

            val enabled = Settings.Secure.getString(
                contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
            ) ?: return false

            val target = "$packageName/${ReelsAccessibilityService::class.java.name}"
            enabled.split(':').any { it.equals(target, ignoreCase = true) }
        } catch (_: Exception) {
            false
        }
    }
}
