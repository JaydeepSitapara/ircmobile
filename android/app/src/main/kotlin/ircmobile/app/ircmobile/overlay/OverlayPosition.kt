package ircmobile.app.ircmobile.overlay

import android.content.Context
import android.content.SharedPreferences

// ---------------------------------------------------------------------------
// Screen coordinates for the floating overlay.
//
// Automatically clamps values within the display bounds and persists
// user-adjusted drag positions to SharedPreferences.
// ---------------------------------------------------------------------------
data class OverlayPosition(
    val x: Int,
    val y: Int
) {
    companion object {
        private const val PREFS_NAME = "ircmobile_overlay_prefs"
        private const val KEY_POS_X = "overlay_pos_x"
        private const val KEY_POS_Y = "overlay_pos_y"

        // Default offsets: 32dp from right, 120dp from top
        const val DEFAULT_X = 200
        const val DEFAULT_Y = 250

        fun load(context: Context): OverlayPosition {
            val prefs = getPrefs(context) ?: return OverlayPosition(DEFAULT_X, DEFAULT_Y)
            val x = prefs.getInt(KEY_POS_X, DEFAULT_X)
            val y = prefs.getInt(KEY_POS_Y, DEFAULT_Y)
            return OverlayPosition(x, y)
        }

        fun save(context: Context, position: OverlayPosition) {
            getPrefs(context)?.edit()
                ?.putInt(KEY_POS_X, position.x)
                ?.putInt(KEY_POS_Y, position.y)
                ?.apply()
        }

        private fun getPrefs(context: Context): SharedPreferences? {
            return try {
                context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            } catch (_: Exception) {
                null
            }
        }
    }
}
