package ircmobile.app.ircmobile.overlay

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Test

class OverlayPositionTest {

    @Test
    fun `default positions match expected constants`() {
        val defaultPos = OverlayPosition(OverlayPosition.DEFAULT_X, OverlayPosition.DEFAULT_Y)
        assertEquals(200, defaultPos.x)
        assertEquals(250, defaultPos.y)
    }

    @Test
    fun `custom position stores values accurately`() {
        val customPos = OverlayPosition(450, 780)
        assertEquals(450, customPos.x)
        assertEquals(780, customPos.y)
    }

    @Test
    fun `equality works correctly for data class`() {
        val pos1 = OverlayPosition(100, 300)
        val pos2 = OverlayPosition(100, 300)
        val pos3 = OverlayPosition(100, 301)

        assertEquals(pos1, pos2)
        assertNotEquals(pos1, pos3)
    }
}
