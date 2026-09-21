package ircmobile.app.ircmobile.counter

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import ircmobile.app.ircmobile.tracking.TrackingConfig
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

// ---------------------------------------------------------------------------
// Native Android Storage for Reel Counter & Tracking State.
//
// Responsibilities:
// 1. Persist today's count, total count, and daily history JSON in SharedPreferences.
// 2. Perform automatic calendar-day rollover archiving previous counts.
// 3. Store tracking and overlay preferences independently of the Flutter process.
// 4. Safe fallback for unit testing (in-memory mode when Context is null).
// ---------------------------------------------------------------------------
open class CounterStorage(context: Context?) {

    companion object {
        const val PREFS_NAME = "ircmobile_counter_prefs"
        const val KEY_TODAY_COUNT = "native_today_count"
        const val KEY_TOTAL_COUNT = "native_total_count"
        const val KEY_TODAY_DATE = "native_today_date"
        const val KEY_DAILY_HISTORY = "native_daily_history"
        const val KEY_TRACKING_ENABLED = "native_tracking_enabled"
        const val KEY_OVERLAY_ENABLED = "native_overlay_enabled"
        const val KEY_LAST_UPDATED = "native_last_updated"
    }

    private val prefs: SharedPreferences? = try {
        context?.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    } catch (_: Exception) {
        null
    }

    // In-memory fallback fields for unit testing without Android context
    private var memTodayCount: Int = 0
    private var memTotalCount: Int = 0
    private var memTodayDate: String = getTodayDateString()
    private var memDailyHistory: MutableMap<String, Int> = mutableMapOf()
    private var memTrackingEnabled: Boolean = false
    private var memOverlayEnabled: Boolean = false
    private var memLastUpdated: Long = System.currentTimeMillis()

    init {
        checkAndPerformDailyRollover()
    }

    // ---------------------------------------------------------------------------
    // Read APIs
    // ---------------------------------------------------------------------------

    @Synchronized
    open fun loadTodayCount(): Int {
        checkAndPerformDailyRollover()
        return prefs?.getInt(KEY_TODAY_COUNT, 0) ?: memTodayCount
    }

    @Synchronized
    open fun loadTotalCount(): Int {
        return prefs?.getInt(KEY_TOTAL_COUNT, 0) ?: memTotalCount
    }

    @Synchronized
    open fun loadTodayDate(): String {
        return prefs?.getString(KEY_TODAY_DATE, null) ?: memTodayDate
    }

    @Synchronized
    open fun loadDailyHistory(): Map<String, Int> {
        checkAndPerformDailyRollover()
        val jsonStr = prefs?.getString(KEY_DAILY_HISTORY, null)
        if (jsonStr.isNullOrEmpty()) {
            return memDailyHistory.toMap()
        }

        return try {
            val json = JSONObject(jsonStr)
            val result = mutableMapOf<String, Int>()
            val keys = json.keys()
            while (keys.hasNext()) {
                val key = keys.next()
                result[key] = json.getInt(key)
            }
            result
        } catch (e: Exception) {
            Log.e(TrackingConfig.DEBUG_LOG_TAG, "[CounterStorage] Error parsing daily history JSON: ${e.message}")
            emptyMap()
        }
    }

    @Synchronized
    open fun loadTrackingEnabled(): Boolean {
        return prefs?.getBoolean(KEY_TRACKING_ENABLED, false) ?: memTrackingEnabled
    }

    @Synchronized
    open fun loadOverlayEnabled(): Boolean {
        return prefs?.getBoolean(KEY_OVERLAY_ENABLED, false) ?: memOverlayEnabled
    }

    // ---------------------------------------------------------------------------
    // Write APIs
    // ---------------------------------------------------------------------------

    @Synchronized
    open fun saveTodayCount(count: Int) {
        memTodayCount = count
        memLastUpdated = System.currentTimeMillis()
        prefs?.edit()
            ?.putInt(KEY_TODAY_COUNT, count)
            ?.putString(KEY_TODAY_DATE, getTodayDateString())
            ?.putLong(KEY_LAST_UPDATED, memLastUpdated)
            ?.apply()
    }

    @Synchronized
    open fun saveTotalCount(count: Int) {
        memTotalCount = count
        memLastUpdated = System.currentTimeMillis()
        prefs?.edit()
            ?.putInt(KEY_TOTAL_COUNT, count)
            ?.putLong(KEY_LAST_UPDATED, memLastUpdated)
            ?.apply()
    }

    @Synchronized
    open fun saveDailyHistory(history: Map<String, Int>) {
        memDailyHistory = history.toMutableMap()
        val json = JSONObject()
        for ((k, v) in history) {
            json.put(k, v)
        }
        prefs?.edit()?.putString(KEY_DAILY_HISTORY, json.toString())?.apply()
    }

    @Synchronized
    open fun saveTrackingEnabled(enabled: Boolean) {
        memTrackingEnabled = enabled
        prefs?.edit()?.putBoolean(KEY_TRACKING_ENABLED, enabled)?.apply()
    }

    @Synchronized
    open fun saveOverlayEnabled(enabled: Boolean) {
        memOverlayEnabled = enabled
        prefs?.edit()?.putBoolean(KEY_OVERLAY_ENABLED, enabled)?.apply()
    }

    // ---------------------------------------------------------------------------
    // Daily Rollover Logic
    // ---------------------------------------------------------------------------

    @Synchronized
    open fun checkAndPerformDailyRollover(currentDate: String = getTodayDateString()) {
        val storedDate = prefs?.getString(KEY_TODAY_DATE, null) ?: memTodayDate

        if (storedDate != currentDate) {
            val storedTodayCount = prefs?.getInt(KEY_TODAY_COUNT, 0) ?: memTodayCount

            if (storedTodayCount > 0) {
                // Archive previous day into history map
                val currentHistory = loadDailyHistory().toMutableMap()
                currentHistory[storedDate] = storedTodayCount
                saveDailyHistory(currentHistory)
            }

            // Reset today's count for the new day
            memTodayCount = 0
            memTodayDate = currentDate
            prefs?.edit()
                ?.putString(KEY_TODAY_DATE, currentDate)
                ?.putInt(KEY_TODAY_COUNT, 0)
                ?.apply()

            if (TrackingConfig.DEBUG_LOGGING) {
                Log.d(TrackingConfig.DEBUG_LOG_TAG, "[CounterStorage] Rollover: archived $storedDate ($storedTodayCount), reset for $currentDate")
            }
        }
    }

    open fun getTodayDateString(): String {
        return SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
    }
}
