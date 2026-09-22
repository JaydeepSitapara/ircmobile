package ircmobile.app.ircmobile.overlay

import android.content.Context
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import android.view.Gravity
import android.view.WindowManager
import ircmobile.app.ircmobile.counter.CounterManager
import ircmobile.app.ircmobile.tracking.TrackingConfig

// ---------------------------------------------------------------------------
// Native Android Floating Overlay Manager.
//
// Manages the lifecycle of the WindowManager overlay window:
// 1. Attaches / detaches the OverlayView safely.
// 2. Automatically coordinates visibility with the Reels screen active state.
// 3. Handles overlay permission checks before window attachment.
// 4. Ensures thread-safe execution on the Android UI thread.
// ---------------------------------------------------------------------------
class OverlayService private constructor(private val context: Context) {

    companion object {
        private const val TAG = TrackingConfig.DEBUG_LOG_TAG

        @Volatile
        private var instance: OverlayService? = null

        fun getInstance(context: Context): OverlayService {
            return instance ?: synchronized(this) {
                instance ?: OverlayService(context.applicationContext).also { instance = it }
            }
        }
    }

    private val windowManager: WindowManager =
        context.getSystemService(Context.WINDOW_SERVICE) as WindowManager

    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile
    private var overlayView: OverlayView? = null

    @Volatile
    private var isOverlayEnabled: Boolean = false

    @Volatile
    private var isInstagramActive: Boolean = false

    // ---------------------------------------------------------------------------
    // Public Control API
    // ---------------------------------------------------------------------------

    fun setOverlayEnabled(enabled: Boolean) {
        isOverlayEnabled = enabled
        if (TrackingConfig.DEBUG_LOGGING) {
            Log.d(TAG, "[OverlayService] Overlay setting changed: enabled=$enabled")
        }
        mainHandler.post {
            evaluateVisibility()
        }
    }

    fun isOverlayEnabled(): Boolean = isOverlayEnabled

    fun isOverlayShowing(): Boolean = overlayView != null

    /**
     * Called by ReelTrackingManager when Instagram comes to the foreground or goes away.
     * The overlay is shown as soon as Instagram is open — we don't wait for Reels detection.
     */
    fun onInstagramVisibilityChanged(active: Boolean) {
        isInstagramActive = active
        if (TrackingConfig.DEBUG_LOGGING) {
            Log.d(TAG, "[OverlayService] Instagram visibility changed: active=$active")
        }
        mainHandler.post {
            evaluateVisibility()
        }
    }

    /**
     * Legacy compatibility: called by ReelTrackingManager when Reels screen is detected.
     * Kept for any future use but no longer controls overlay visibility directly.
     */
    fun onReelsScreenVisibilityChanged(reelsActive: Boolean) {
        if (TrackingConfig.DEBUG_LOGGING) {
            Log.d(TAG, "[OverlayService] Reels screen visibility changed: active=$reelsActive")
        }
        // Overlay is already shown when Instagram is active — no extra action needed.
    }

    /**
     * Updates the counter on the visible overlay view.
     */
    fun updateCounter(count: Int) {
        mainHandler.post {
            overlayView?.updateCount(count)
        }
    }

    // ---------------------------------------------------------------------------
    // Internal Window Management
    // ---------------------------------------------------------------------------

    private fun evaluateVisibility() {
        val shouldShow = isOverlayEnabled && isInstagramActive && hasOverlayPermission()

        if (shouldShow && overlayView == null) {
            attachOverlay()
        } else if (!shouldShow && overlayView != null) {
            detachOverlay()
        }
    }

    private fun attachOverlay() {
        if (overlayView != null) return

        try {
            val savedPos = OverlayPosition.load(context)
            val windowType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            }

            val params = WindowManager.LayoutParams(
                WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.WRAP_CONTENT,
                windowType,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                        WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                        WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
                PixelFormat.TRANSLUCENT
            ).apply {
                gravity = Gravity.TOP or Gravity.START
                x = savedPos.x
                y = savedPos.y
            }

            val currentCount = CounterManager.getInstance(context).getTodayCount()
            val view = OverlayView(context, windowManager, params, currentCount)
            windowManager.addView(view, params)
            overlayView = view

            if (TrackingConfig.DEBUG_LOGGING) {
                Log.d(TAG, "[OverlayService] Overlay attached at ($params.x, $params.y), count=$currentCount")
            }
        } catch (e: Exception) {
            Log.e(TAG, "[OverlayService] Failed to attach overlay: ${e.message}")
            overlayView = null
        }
    }

    private fun detachOverlay() {
        val view = overlayView ?: return
        try {
            windowManager.removeView(view)
            if (TrackingConfig.DEBUG_LOGGING) {
                Log.d(TAG, "[OverlayService] Overlay detached successfully")
            }
        } catch (e: Exception) {
            Log.e(TAG, "[OverlayService] Failed to detach overlay: ${e.message}")
        } finally {
            overlayView = null
        }
    }

    fun hasOverlayPermission(): Boolean {
        return Settings.canDrawOverlays(context)
    }
}
