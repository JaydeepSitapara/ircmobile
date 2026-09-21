package ircmobile.app.ircmobile.counter

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class CounterStorageTest {

    private lateinit var storage: CounterStorage

    @Before
    fun setUp() {
        storage = CounterStorage(null) // in-memory mode
    }

    @Test
    fun `initial counts default to 0`() {
        assertEquals(0, storage.loadTodayCount())
        assertEquals(0, storage.loadTotalCount())
    }

    @Test
    fun `save and load todayCount works correctly`() {
        storage.saveTodayCount(55)
        assertEquals(55, storage.loadTodayCount())
    }

    @Test
    fun `save and load totalCount works correctly`() {
        storage.saveTotalCount(1200)
        assertEquals(1200, storage.loadTotalCount())
    }

    @Test
    fun `save and load trackingEnabled works correctly`() {
        assertFalse(storage.loadTrackingEnabled())
        storage.saveTrackingEnabled(true)
        assertTrue(storage.loadTrackingEnabled())
    }

    @Test
    fun `save and load overlayEnabled works correctly`() {
        assertFalse(storage.loadOverlayEnabled())
        storage.saveOverlayEnabled(true)
        assertTrue(storage.loadOverlayEnabled())
    }

    @Test
    fun `daily rollover archives previous day and resets todayCount`() {
        storage.saveTodayCount(75)
        storage.saveTotalCount(300)

        // Simulate new date rollover
        val oldDate = storage.loadTodayDate()
        val newDate = "2099-12-31"

        storage.checkAndPerformDailyRollover(newDate)

        // Today count should now be 0
        assertEquals(0, storage.loadTodayCount())
        // Total count should remain preserved
        assertEquals(300, storage.loadTotalCount())
        // History should contain the old date count
        val history = storage.loadDailyHistory()
        assertEquals(75, history[oldDate])
    }
}
