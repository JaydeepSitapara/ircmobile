package ircmobile.app.ircmobile.tracking

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

// ---------------------------------------------------------------------------
// Thread-safe bridge between the Kotlin tracking engine and the Flutter
// EventChannel.
//
// AccessibilityService callbacks arrive on the main thread, but we guard with
// Handler(Looper.getMainLooper()) to ensure EventSink writes always happen on
// the main thread even if a future refactor moves processing off it.
// ---------------------------------------------------------------------------
class FlutterEventBridge {

    @Volatile
    private var eventSink: EventChannel.EventSink? = null

    private val mainHandler = Handler(Looper.getMainLooper())

    /** Called by MainActivity when Flutter starts listening on the EventChannel. */
    fun setEventSink(sink: EventChannel.EventSink?) {
        eventSink = sink
    }

    // ---------------------------------------------------------------------------
    // Typed emission helpers
    // ---------------------------------------------------------------------------

    fun emitReelDetected(
        event: ReelDetectedEvent,
        todayCount: Int = 0,
        totalCount: Int = 0
    ) {
        emit(
            mapOf(
                "type" to "reelDetected",
                "timestamp" to event.timestamp,
                "packageName" to event.packageName,
                "fingerprint" to event.fingerprint,
                "confidence" to event.detectionConfidence,
                "todayCount" to todayCount,
                "totalCount" to totalCount
            )
        )
    }

    fun emitTrackingState(state: TrackingState) {
        emit(mapOf("type" to "trackingState", "state" to state.name))
    }

    fun emitInstagramStatus(detected: Boolean) {
        emit(mapOf("type" to if (detected) "instagramDetected" else "instagramClosed"))
    }

    fun emitReelsScreenStatus(active: Boolean) {
        emit(mapOf("type" to if (active) "reelsScreenActive" else "reelsScreenInactive"))
    }

    // ---------------------------------------------------------------------------
    // Internal
    // ---------------------------------------------------------------------------

    private fun emit(data: Map<String, Any>) {
        mainHandler.post {
            try {
                eventSink?.success(data)
            } catch (_: Exception) {
                // Sink may have been closed between the post() and the execution;
                // this is normal during app lifecycle transitions.
            }
        }
    }
}
