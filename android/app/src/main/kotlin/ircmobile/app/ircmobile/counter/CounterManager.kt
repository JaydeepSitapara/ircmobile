package ircmobile.app.ircmobile.counter

import android.content.Context
import android.util.Log
import ircmobile.app.ircmobile.tracking.TrackingConfig
import java.util.concurrent.CopyOnWriteArrayList

// ---------------------------------------------------------------------------
// Result of an authoritative Reel count increment.
// ---------------------------------------------------------------------------
data class ReelCountResult(
    val todayCount: Int,
    val totalCount: Int,
    val timestamp: Long
)

// ---------------------------------------------------------------------------
// Native Android Authoritative State Manager.
//
// Responsibilities:
// 1. Owns the live tracking state, counter value, and daily history.
// 2. Backed by CounterStorage (SharedPreferences).
// 3. Thread-safe mutations for AccessibilityService, OverlayService, and Flutter.
// 4. Coordinates listener notifications on state changes.
// ---------------------------------------------------------------------------
class CounterManager(private val storage: CounterStorage) {

    companion object {
        @Volatile
        private var instance: CounterManager? = null

        fun getInstance(context: Context? = null): CounterManager {
            return instance ?: synchronized(this) {
                instance ?: CounterManager(CounterStorage(context?.applicationContext)).also {
                    instance = it
                }
            }
        }
    }

    private val listeners = CopyOnWriteArrayList<(newCount: Int) -> Unit>()

    @Volatile
    private var todayCount: Int = storage.loadTodayCount()

    @Volatile
    private var totalCount: Int = storage.loadTotalCount()

    @Volatile
    private var trackingEnabled: Boolean = storage.loadTrackingEnabled()

    @Volatile
    private var overlayEnabled: Boolean = storage.loadOverlayEnabled()

    // ---------------------------------------------------------------------------
    // Counter Access & Mutation
    // ---------------------------------------------------------------------------

    @Synchronized
    fun getTodayCount(): Int {
        todayCount = storage.loadTodayCount()
        return todayCount
    }

    @Synchronized
    fun getTotalCount(): Int {
        totalCount = storage.loadTotalCount()
        return totalCount
    }

    @Synchronized
    fun getDailyHistory(): Map<String, Int> {
        return storage.loadDailyHistory()
    }

    @Synchronized
    fun getDailyHistoryList(): List<Map<String, Any>> {
        val history = storage.loadDailyHistory()
        return history.map { (date, count) ->
            mapOf("date" to date, "count" to count)
        }
    }

    @Synchronized
    fun setTodayCount(count: Int) {
        todayCount = count.coerceAtLeast(0)
        storage.saveTodayCount(todayCount)
        notifyListeners(todayCount)
    }

    @Synchronized
    fun setTotalCount(count: Int) {
        totalCount = count.coerceAtLeast(0)
        storage.saveTotalCount(totalCount)
    }

    @Synchronized
    fun increment(): ReelCountResult {
        todayCount = storage.loadTodayCount() + 1
        totalCount = storage.loadTotalCount() + 1
        val now = System.currentTimeMillis()

        storage.saveTodayCount(todayCount)
        storage.saveTotalCount(totalCount)

        if (TrackingConfig.DEBUG_LOGGING) {
            Log.d(TrackingConfig.DEBUG_LOG_TAG, "[CounterManager] Authoritative increment: today=$todayCount total=$totalCount")
        }

        notifyListeners(todayCount)
        return ReelCountResult(todayCount, totalCount, now)
    }

    @Synchronized
    fun resetToday(): Int {
        todayCount = 0
        storage.saveTodayCount(0)
        notifyListeners(0)
        if (TrackingConfig.DEBUG_LOGGING) {
            Log.d(TrackingConfig.DEBUG_LOG_TAG, "[CounterManager] Reset today's count to 0")
        }
        return 0
    }

    // ---------------------------------------------------------------------------
    // Preferences Access & Mutation
    // ---------------------------------------------------------------------------

    @Synchronized
    fun setTrackingEnabled(enabled: Boolean) {
        trackingEnabled = enabled
        storage.saveTrackingEnabled(enabled)
    }

    @Synchronized
    fun isTrackingEnabled(): Boolean {
        trackingEnabled = storage.loadTrackingEnabled()
        return trackingEnabled
    }

    @Synchronized
    fun setOverlayEnabled(enabled: Boolean) {
        overlayEnabled = enabled
        storage.saveOverlayEnabled(enabled)
    }

    @Synchronized
    fun isOverlayEnabled(): Boolean {
        overlayEnabled = storage.loadOverlayEnabled()
        return overlayEnabled
    }

    // ---------------------------------------------------------------------------
    // Full State Export for Flutter Initialization & Reconnection
    // ---------------------------------------------------------------------------

    @Synchronized
    fun getFullState(): Map<String, Any> {
        return mapOf(
            "todayCount" to getTodayCount(),
            "totalCount" to getTotalCount(),
            "todayDate" to storage.loadTodayDate(),
            "trackingEnabled" to isTrackingEnabled(),
            "overlayEnabled" to isOverlayEnabled(),
            "dailyHistory" to getDailyHistory()
        )
    }

    // ---------------------------------------------------------------------------
    // Listeners
    // ---------------------------------------------------------------------------

    fun addListener(listener: (newCount: Int) -> Unit) {
        listeners.add(listener)
    }

    fun removeListener(listener: (newCount: Int) -> Unit) {
        listeners.remove(listener)
    }

    private fun notifyListeners(newCount: Int) {
        for (listener in listeners) {
            try {
                listener(newCount)
            } catch (e: Exception) {
                Log.e(TrackingConfig.DEBUG_LOG_TAG, "[CounterManager] Listener error: ${e.message}")
            }
        }
    }
}
