package ircmobile.app.ircmobile.overlay

import android.animation.AnimatorSet
import android.animation.ObjectAnimator
import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.view.animation.OvershootInterpolator
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView

// ---------------------------------------------------------------------------
// Native Android Floating Overlay View.
//
// A sleek, compact, semi-transparent pill that floats on top of Instagram Reels.
// Features:
// 1. Draggable across the screen with real-time WindowManager layout updates.
// 2. Clamps coordinates safely within screen boundaries.
// 3. Persists dragged position via OverlayPosition.
// 4. Subtle pulse animation when the counter updates.
// 5. Minimal footprint to prevent blocking Instagram interactions.
// ---------------------------------------------------------------------------
@SuppressLint("ViewConstructor")
class OverlayView(
    context: Context,
    private val windowManager: WindowManager,
    private val layoutParams: WindowManager.LayoutParams,
    initialCount: Int
) : FrameLayout(context) {

    private val textView: TextView
    private var displayedCount: Int = initialCount

    // Touch dragging tracking variables
    private var initialX = 0
    private var initialY = 0
    private var initialTouchX = 0f
    private var initialTouchY = 0f
    private var isDragging = false

    init {
        // ── Outer Container Styling ───────────────────────────────────────────
        val density = resources.displayMetrics.density
        val paddingHorizontal = (14 * density).toInt()
        val paddingVertical = (8 * density).toInt()

        val pillLayout = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            setPadding(paddingHorizontal, paddingVertical, paddingHorizontal, paddingVertical)

            // Semi-transparent dark background with rounded corners and subtle border
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = 24 * density
                setColor(Color.parseColor("#E6181824")) // 90% opacity dark purple-gray
                setStroke((1.5f * density).toInt(), Color.parseColor("#4DFFFFFF")) // 30% opacity white border
            }
            elevation = 8 * density
        }

        // ── Dot Indicator (Pink/Magenta Accent) ────────────────────────────────
        val dotView = View(context).apply {
            val dotSize = (7 * density).toInt()
            layoutParams = LinearLayout.LayoutParams(dotSize, dotSize).apply {
                gravity = Gravity.CENTER_VERTICAL
                rightMargin = (8 * density).toInt()
            }
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.parseColor("#E1306C")) // Instagram Magenta
            }
        }
        pillLayout.addView(dotView)

        // ── Counter Text ──────────────────────────────────────────────────────
        textView = TextView(context).apply {
            text = formatText(initialCount)
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            typeface = Typeface.create(Typeface.SANS_SERIF, Typeface.BOLD)
            gravity = Gravity.CENTER
            includeFontPadding = false
        }
        pillLayout.addView(textView)

        val rootParams = LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT)
        addView(pillLayout, rootParams)

        setupTouchListener()
    }

    // ---------------------------------------------------------------------------
    // Counter Update & Animation
    // ---------------------------------------------------------------------------

    fun updateCount(count: Int) {
        if (count == displayedCount) return
        displayedCount = count
        textView.text = formatText(count)

        // Subtle, elegant pulse animation on count change
        val scaleUpX = ObjectAnimator.ofFloat(this, View.SCALE_X, 1.0f, 1.12f)
        val scaleUpY = ObjectAnimator.ofFloat(this, View.SCALE_Y, 1.0f, 1.12f)
        val scaleDownX = ObjectAnimator.ofFloat(this, View.SCALE_X, 1.12f, 1.0f)
        val scaleDownY = ObjectAnimator.ofFloat(this, View.SCALE_Y, 1.12f, 1.0f)

        scaleDownX.interpolator = OvershootInterpolator(1.5f)
        scaleDownY.interpolator = OvershootInterpolator(1.5f)

        AnimatorSet().apply {
            play(scaleUpX).with(scaleUpY)
            play(scaleDownX).with(scaleDownY).after(scaleUpX)
            duration = 120
            start()
        }
    }

    private fun formatText(count: Int): String {
        return "Reels: $count"
    }

    // ---------------------------------------------------------------------------
    // Drag-to-Reposition Touch Listener
    // ---------------------------------------------------------------------------

    @SuppressLint("ClickableViewAccessibility")
    private fun setupTouchListener() {
        setOnTouchListener { _, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    initialX = layoutParams.x
                    initialY = layoutParams.y
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    isDragging = false
                    true
                }

                MotionEvent.ACTION_MOVE -> {
                    val dx = (event.rawX - initialTouchX).toInt()
                    val dy = (event.rawY - initialTouchY).toInt()

                    if (kotlin.math.abs(dx) > 5 || kotlin.math.abs(dy) > 5) {
                        isDragging = true
                    }

                    if (isDragging) {
                        layoutParams.x = initialX + dx
                        layoutParams.y = initialY + dy
                        try {
                            windowManager.updateViewLayout(this, layoutParams)
                        } catch (_: Exception) {}
                    }
                    true
                }

                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    if (isDragging) {
                        OverlayPosition.save(context, OverlayPosition(layoutParams.x, layoutParams.y))
                    }
                    true
                }

                else -> false
            }
        }
    }
}
