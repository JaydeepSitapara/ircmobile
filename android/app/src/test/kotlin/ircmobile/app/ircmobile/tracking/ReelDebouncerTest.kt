package ircmobile.app.ircmobile.tracking

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/**
 * Tests for [ReelDebouncer].
 *
 * We subclass [ReelDebouncer] to override [currentTimeMs] so tests run
 * without actual Thread.sleep() calls.
 */
class ReelDebouncerTest {

    private var fakeTime = 0L

    // Subclass that uses our fake clock.
    private val debouncer: ReelDebouncer = object : ReelDebouncer() {
        override fun currentTimeMs(): Long = fakeTime
    }

    @Before
    fun setUp() {
        fakeTime = 1_000L
    }

    @Test
    fun `first call always allowed (no previous record)`() {
        assertTrue(debouncer.shouldProcess())
    }

    @Test
    fun `call immediately after recording is rejected`() {
        debouncer.recordProcessed()
        // Same fake time — 0 ms elapsed.
        assertFalse(debouncer.shouldProcess())
    }

    @Test
    fun `call just below threshold is rejected`() {
        debouncer.recordProcessed()
        fakeTime += TrackingConfig.MIN_REEL_TRANSITION_INTERVAL_MS - 1
        assertFalse(debouncer.shouldProcess())
    }

    @Test
    fun `call exactly at threshold is allowed`() {
        debouncer.recordProcessed()
        fakeTime += TrackingConfig.MIN_REEL_TRANSITION_INTERVAL_MS
        assertTrue(debouncer.shouldProcess())
    }

    @Test
    fun `call well after threshold is allowed`() {
        debouncer.recordProcessed()
        fakeTime += 5000L
        assertTrue(debouncer.shouldProcess())
    }

    @Test
    fun `reset allows immediate processing`() {
        debouncer.recordProcessed()
        debouncer.reset()
        // After reset, timer is 0 so any positive fakeTime satisfies threshold.
        assertTrue(debouncer.shouldProcess())
    }

    @Test
    fun `multiple records update the timer`() {
        debouncer.recordProcessed()
        fakeTime += TrackingConfig.MIN_REEL_TRANSITION_INTERVAL_MS + 100
        assertTrue(debouncer.shouldProcess())

        // Record again — now we're back to being throttled.
        debouncer.recordProcessed()
        assertFalse(debouncer.shouldProcess())
    }
}
