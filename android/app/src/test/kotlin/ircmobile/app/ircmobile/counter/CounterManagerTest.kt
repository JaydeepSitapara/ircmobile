package ircmobile.app.ircmobile.counter

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class CounterManagerTest {

    private lateinit var storage: CounterStorage
    private lateinit var counterManager: CounterManager

    @Before
    fun setUp() {
        storage = CounterStorage(null)
        counterManager = CounterManager(storage)
        counterManager.resetToday()
        counterManager.setTotalCount(0)
    }

    @Test
    fun `initial todayCount defaults to 0`() {
        assertEquals(0, counterManager.getTodayCount())
    }

    @Test
    fun `increment returns ReelCountResult with updated todayCount and totalCount`() {
        val result = counterManager.increment()
        assertEquals(1, result.todayCount)
        assertEquals(1, result.totalCount)
        assertEquals(1, counterManager.getTodayCount())
        assertEquals(1, counterManager.getTotalCount())
    }

    @Test
    fun `multiple increments accumulate correctly`() {
        counterManager.increment()
        counterManager.increment()
        val result = counterManager.increment()
        assertEquals(3, result.todayCount)
        assertEquals(3, result.totalCount)
        assertEquals(3, counterManager.getTodayCount())
        assertEquals(3, counterManager.getTotalCount())
    }

    @Test
    fun `setTodayCount updates state and triggers listeners`() {
        var observedCount = -1
        val listener: (Int) -> Unit = { observedCount = it }
        counterManager.addListener(listener)

        counterManager.setTodayCount(42)
        assertEquals(42, counterManager.getTodayCount())
        assertEquals(42, observedCount)

        counterManager.removeListener(listener)
    }

    @Test
    fun `resetToday zeroes todayCount while preserving totalCount`() {
        counterManager.increment()
        counterManager.increment()
        assertEquals(2, counterManager.getTodayCount())
        assertEquals(2, counterManager.getTotalCount())

        counterManager.resetToday()
        assertEquals(0, counterManager.getTodayCount())
        assertEquals(2, counterManager.getTotalCount())
    }

    @Test
    fun `trackingEnabled and overlayEnabled getters and setters work`() {
        assertFalse(counterManager.isTrackingEnabled())
        assertFalse(counterManager.isOverlayEnabled())

        counterManager.setTrackingEnabled(true)
        counterManager.setOverlayEnabled(true)

        assertTrue(counterManager.isTrackingEnabled())
        assertTrue(counterManager.isOverlayEnabled())
    }

    @Test
    fun `getFullState returns all expected state entries`() {
        counterManager.setTodayCount(15)
        counterManager.setTotalCount(150)
        counterManager.setTrackingEnabled(true)

        val state = counterManager.getFullState()
        assertEquals(15, state["todayCount"])
        assertEquals(150, state["totalCount"])
        assertEquals(true, state["trackingEnabled"])
        assertTrue(state.containsKey("todayDate"))
        assertTrue(state.containsKey("dailyHistory"))
    }
}
