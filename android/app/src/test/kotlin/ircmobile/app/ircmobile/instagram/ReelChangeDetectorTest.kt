package ircmobile.app.ircmobile.instagram

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class ReelChangeDetectorTest {

    private lateinit var detector: ReelChangeDetector

    @Before
    fun setUp() {
        detector = ReelChangeDetector()
    }

    // ---------------------------------------------------------------------------
    // Stability requirement: fingerprint must appear twice in a row
    // ---------------------------------------------------------------------------

    @Test
    fun `first event with fingerprint A is not stable yet`() {
        val result = detector.evaluate("fingerprint_A")
        assertEquals(false, result)
    }

    @Test
    fun `second consecutive event with same fingerprint A becomes stable and triggers count`() {
        detector.evaluate("fingerprint_A")          // first — not stable
        val result = detector.evaluate("fingerprint_A")  // second — stable, new
        assertEquals(true, result)
    }

    @Test
    fun `alternating fingerprints never stabilise`() {
        detector.evaluate("A")
        detector.evaluate("B")
        detector.evaluate("A")
        val result = detector.evaluate("B")
        assertEquals(false, result)  // never two consecutive same values
    }

    // ---------------------------------------------------------------------------
    // Duplicate prevention: same fingerprint after recordCounted() should not re-trigger
    // ---------------------------------------------------------------------------

    @Test
    fun `same fingerprint does not trigger after it has been counted`() {
        detector.evaluate("fingerprint_A")
        detector.evaluate("fingerprint_A")   // triggers, count this
        detector.recordCounted("fingerprint_A")

        // More events with same fingerprint
        detector.evaluate("fingerprint_A")
        val result = detector.evaluate("fingerprint_A")
        assertEquals(false, result)
    }

    @Test
    fun `new fingerprint triggers after previous was counted`() {
        detector.evaluate("A")
        detector.evaluate("A")
        detector.recordCounted("A")

        detector.evaluate("B")
        val result = detector.evaluate("B")
        assertEquals(true, result)
    }

    // ---------------------------------------------------------------------------
    // Reset behaviour
    // ---------------------------------------------------------------------------

    @Test
    fun `reset clears lastCounted allowing same fingerprint to count again`() {
        detector.evaluate("A")
        detector.evaluate("A")
        detector.recordCounted("A")
        detector.reset()

        detector.evaluate("A")
        val result = detector.evaluate("A")
        assertEquals(true, result)
    }

    // ---------------------------------------------------------------------------
    // Empty fingerprint handling
    // ---------------------------------------------------------------------------

    @Test
    fun `empty fingerprint always returns false`() {
        detector.evaluate("")
        val result = detector.evaluate("")
        assertEquals(false, result)
    }

    @Test
    fun `empty fingerprint resets pending state`() {
        detector.evaluate("A")   // pending = A
        detector.evaluate("")    // should reset
        val result = detector.evaluate("A")  // A again — not stable (reset by "")
        assertEquals(false, result)
    }
}
