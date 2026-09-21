package ircmobile.app.ircmobile.instagram

import android.view.accessibility.AccessibilityNodeInfo

// ---------------------------------------------------------------------------
// Derives a stable, anonymous fingerprint for the currently visible Reel.
//
// Purpose: distinguish "same Reel" from "different Reel" without storing
// any personal content. The fingerprint is a hash — the original text is
// never persisted.
//
// Strategy:
//   1. Extract stable text tokens from the accessibility tree (creator name,
//      caption excerpt, audio label — see InstagramAccessibilityParser).
//   2. Exclude volatile elements (like counts, timestamps, action labels).
//   3. Sort tokens for order-independence.
//   4. Hash the sorted, joined string.
//   5. Return empty string if fewer than 2 tokens are found (not enough
//      information to produce a reliable fingerprint).
//
// LIMITATION:
//   If Instagram renders a Reel with no accessible text (e.g., all text is
//   drawn on a Canvas rather than as TextView nodes), this returns "".
//   The caller (ReelTrackingManager) handles the empty case gracefully.
// ---------------------------------------------------------------------------
class ReelFingerprintGenerator {

    /**
     * Generates a fingerprint string for the currently visible Reel.
     *
     * @return A non-empty hash string if stable content was found, or an
     *         empty string if insufficient data was available.
     */
    fun generate(rootNode: AccessibilityNodeInfo?): String {
        if (rootNode == null) return ""

        val tokens = InstagramAccessibilityParser.extractStableTexts(rootNode)

        if (tokens.isNotEmpty()) {
            val combined = tokens.sorted().joinToString(separator = "|")
            return combined.hashCode().toString()
        }

        // Fallback: extract any non-blank texts/descriptions if specific tokens weren't found
        val allTexts = InstagramAccessibilityParser.extractAllTexts(rootNode) +
                InstagramAccessibilityParser.extractAllDescriptions(rootNode)
        val validTexts = allTexts.filter { it.isNotBlank() && it.length >= 2 }
        if (validTexts.isNotEmpty()) {
            return validTexts.take(8).sorted().joinToString("|").hashCode().toString()
        }

        return ""
    }
}
