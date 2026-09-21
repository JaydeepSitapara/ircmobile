package ircmobile.app.ircmobile.instagram

import android.util.Log
import android.view.accessibility.AccessibilityNodeInfo
import ircmobile.app.ircmobile.tracking.TrackingConfig

// ---------------------------------------------------------------------------
// Utility for extracting information from the Instagram accessibility tree.
//
// All low-level node traversal lives here so that the higher-level detectors
// remain readable and Instagram-version-specific logic is isolated.
// ---------------------------------------------------------------------------
object InstagramAccessibilityParser {

    // Android view classes that indicate a video surface is on screen.
    private val VIDEO_CLASS_NAMES = setOf(
        "android.view.SurfaceView",
        "android.view.TextureView"
    )

    // Text fragments that appear strictly on non-Reels Instagram screens.
    // Negative signals to disqualify non-Reels screens (e.g. profile edit, direct search).
    private val NON_REELS_NEGATIVE_SIGNALS = listOf(
        "search in direct", "edit profile", "accounts center",
        "change profile photo", "saved posts", "archived stories",
        "switch accounts"
    )

    // Text fragments that strongly suggest Reels screen.
    private val REELS_POSITIVE_SIGNALS = listOf(
        "reel", "reels", "audio", "original audio", "trending audio",
        "remix", "use audio", "clips", "double tap to like", "watch full reel",
        "suggested reel", "suggested reels"
    )

    // Text fragments that are volatile UI elements — excluded from fingerprinting.
    private val VOLATILE_PATTERNS = listOf(
        "liked by", "views", "view all", "ago", "add comment",
        "double tap to like", "see translation", "view more comments"
    )

    // ---------------------------------------------------------------------------
    // Text extraction
    // ---------------------------------------------------------------------------

    /** Returns all non-blank text strings in the tree, up to [maxDepth] levels. */
    fun extractAllTexts(root: AccessibilityNodeInfo, maxDepth: Int = TrackingConfig.MAX_NODE_TRAVERSE_DEPTH): List<String> {
        val texts = mutableListOf<String>()
        traverse(root, 0, maxDepth) { node, _ ->
            node.text?.toString()?.takeIf { it.isNotBlank() }?.let { texts.add(it) }
        }
        return texts
    }

    /** Returns all non-blank content descriptions in the tree. */
    fun extractAllDescriptions(root: AccessibilityNodeInfo, maxDepth: Int = TrackingConfig.MAX_NODE_TRAVERSE_DEPTH): List<String> {
        val descs = mutableListOf<String>()
        traverse(root, 0, maxDepth) { node, _ ->
            node.contentDescription?.toString()?.takeIf { it.isNotBlank() }?.let { descs.add(it) }
        }
        return descs
    }

    /**
     * Extracts text tokens that are likely stable for the duration of a single
     * Reel (creator name, caption, audio label) while filtering out volatile
     * elements (like counts, timestamps, action button labels).
     *
     * Returns at most [TrackingConfig.FINGERPRINT_NODE_LIMIT] tokens.
     */
    fun extractStableTexts(root: AccessibilityNodeInfo): List<String> {
        val tokens = mutableListOf<String>()
        traverse(root, 0, TrackingConfig.MAX_NODE_TRAVERSE_DEPTH) { node, _ ->
            extractStableToken(node.text?.toString())?.let { tokens.add(it) }
            extractStableToken(node.contentDescription?.toString())
                ?.let { tokens.add("d:$it") }
        }
        return tokens.distinct().take(TrackingConfig.FINGERPRINT_NODE_LIMIT)
    }

    private fun extractStableToken(raw: String?): String? {
        if (raw.isNullOrBlank()) return null
        val trimmed = raw.trim()
        if (trimmed.length < 2 || trimmed.length > 300) return null
        if (isVolatile(trimmed)) return null
        // Exclude pure numbers / simple counts (e.g. "12k", "1.5M")
        if (trimmed.all { it.isDigit() || it == ',' || it == '.' || it == 'K' || it == 'M' || it == 'k' || it == 'm' }) return null
        return trimmed.take(100)
    }

    private fun isVolatile(text: String): Boolean {
        val lower = text.lowercase()
        return VOLATILE_PATTERNS.any { lower.contains(it) }
    }

    // ---------------------------------------------------------------------------
    // Screen-type signals
    // ---------------------------------------------------------------------------

    /** Returns true if the tree contains any node class that represents video. */
    fun containsVideoNode(root: AccessibilityNodeInfo): Boolean {
        var found = false
        traverse(root, 0, TrackingConfig.MAX_NODE_TRAVERSE_DEPTH) { node, _ ->
            if (!found && VIDEO_CLASS_NAMES.any {
                node.className?.toString()?.contains(it.substringAfterLast('.')) == true
            }) {
                found = true
            }
        }
        return found
    }

    /**
     * Counts how many of the [REELS_POSITIVE_SIGNALS] appear anywhere in
     * the tree's text or content descriptions.
     */
    fun countReelsPositiveSignals(root: AccessibilityNodeInfo): Int {
        val allText = (extractAllTexts(root) + extractAllDescriptions(root))
            .joinToString(" ")
            .lowercase()
        return REELS_POSITIVE_SIGNALS.count { allText.contains(it) }
    }

    /**
     * Returns true if any [NON_REELS_NEGATIVE_SIGNALS] are found in the tree.
     * A single strong negative signal disqualifies the Reels screen.
     */
    fun hasNonReelsSignal(root: AccessibilityNodeInfo): Boolean {
        val allText = (extractAllTexts(root) + extractAllDescriptions(root))
            .joinToString(" ")
            .lowercase()
        return NON_REELS_NEGATIVE_SIGNALS.any { allText.contains(it) }
    }

    // ---------------------------------------------------------------------------
    // Tree traversal
    // ---------------------------------------------------------------------------

    /** Generic depth-limited accessibility tree traversal. */
    fun traverse(
        node: AccessibilityNodeInfo?,
        depth: Int,
        maxDepth: Int,
        visitor: (AccessibilityNodeInfo, Int) -> Unit
    ) {
        if (node == null || depth > maxDepth) return
        try {
            visitor(node, depth)
            for (i in 0 until node.childCount) {
                traverse(node.getChild(i), depth + 1, maxDepth, visitor)
            }
        } catch (_: Exception) {
            // Node may become invalid mid-traversal; skip silently.
        }
    }

    // ---------------------------------------------------------------------------
    // Debug helpers
    // ---------------------------------------------------------------------------

    /**
     * Prints a simplified accessibility tree to Logcat.
     * Only active when [TrackingConfig.DEBUG_LOGGING] is true.
     * Depth is capped at 4 to keep output readable.
     */
    fun printNodeTree(
        root: AccessibilityNodeInfo?,
        tag: String = TrackingConfig.DEBUG_LOG_TAG,
        maxDepth: Int = 4
    ) {
        if (!TrackingConfig.DEBUG_LOGGING || root == null) return
        Log.d(tag, "=== Accessibility Tree ===")
        printNode(root, 0, tag, maxDepth)
        Log.d(tag, "==========================")
    }

    private fun printNode(node: AccessibilityNodeInfo?, depth: Int, tag: String, maxDepth: Int) {
        if (node == null || depth > maxDepth) return
        val indent = "  ".repeat(depth)
        val cls = node.className?.toString()?.substringAfterLast('.') ?: "?"
        val text = node.text?.toString()?.take(60)?.let { "'$it'" } ?: ""
        val desc = node.contentDescription?.toString()?.take(60)?.let { "desc='$it'" } ?: ""
        Log.d(tag, "$indent[$cls] $text $desc".trimEnd())
        for (i in 0 until node.childCount) {
            try { printNode(node.getChild(i), depth + 1, tag, maxDepth) } catch (_: Exception) {}
        }
    }
}
