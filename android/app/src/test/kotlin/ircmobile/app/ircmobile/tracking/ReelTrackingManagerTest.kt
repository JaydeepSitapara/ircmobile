package ircmobile.app.ircmobile.tracking

import io.mockk.every
import io.mockk.mockk
import io.mockk.slot
import io.mockk.verify
import ircmobile.app.ircmobile.instagram.InstagramDetector
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test

/**
 * Unit tests for [ReelTrackingManager] state machine.
 *
 * Uses MockK to simulate AccessibilityEvents and FlutterEventBridge.
 *
 * NOTE: AccessibilityEvent and AccessibilityNodeInfo are Android framework
 * classes. In JVM unit tests they are stubs (all methods return null/0).
 * We mock the objects that our code calls directly.
 */
class ReelTrackingManagerTest {

    private lateinit var bridge: FlutterEventBridge
    private lateinit var manager: ReelTrackingManager

    // Fake accessible event helper
    private fun fakeEvent(
        packageName: String = InstagramDetector.instagramPackageName(),
        eventType: Int = android.view.accessibility.AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED
    ): android.view.accessibility.AccessibilityEvent {
        val event = mockk<android.view.accessibility.AccessibilityEvent>(relaxed = true)
        every { event.packageName } returns packageName
        every { event.eventType } returns eventType
        every { event.text } returns mutableListOf()
        return event
    }

    @Before
    fun setUp() {
        bridge = mockk(relaxed = true)
        manager = ReelTrackingManager(bridge)
    }

    // ---------------------------------------------------------------------------
    // Initial state
    // ---------------------------------------------------------------------------

    @Test
    fun `initial state is NOT_INSTAGRAM`() {
        assertEquals(TrackingState.NOT_INSTAGRAM, manager.getCurrentState())
    }

    // ---------------------------------------------------------------------------
    // Non-Instagram events
    // ---------------------------------------------------------------------------

    @Test
    fun `non-Instagram event keeps state at NOT_INSTAGRAM`() {
        manager.process(fakeEvent(packageName = "com.android.chrome"), null)
        assertEquals(TrackingState.NOT_INSTAGRAM, manager.getCurrentState())
    }

    @Test
    fun `non-Instagram event after Instagram open emits instagramClosed`() {
        // First get to INSTAGRAM_OPEN
        manager.process(fakeEvent(), null)
        assertEquals(TrackingState.INSTAGRAM_OPEN, manager.getCurrentState())

        // Now a non-Instagram event
        manager.process(fakeEvent(packageName = "com.android.chrome"), null)
        assertEquals(TrackingState.NOT_INSTAGRAM, manager.getCurrentState())
        verify { bridge.emitInstagramStatus(false) }
    }

    // ---------------------------------------------------------------------------
    // Instagram detected
    // ---------------------------------------------------------------------------

    @Test
    fun `Instagram event transitions from NOT_INSTAGRAM to INSTAGRAM_OPEN`() {
        manager.process(fakeEvent(), null)
        assertEquals(TrackingState.INSTAGRAM_OPEN, manager.getCurrentState())
        verify { bridge.emitInstagramStatus(true) }
    }

    // ---------------------------------------------------------------------------
    // Tracking enabled/disabled
    // ---------------------------------------------------------------------------

    @Test
    fun `disabling tracking resets to NOT_INSTAGRAM`() {
        manager.process(fakeEvent(), null)  // reach INSTAGRAM_OPEN
        manager.isTrackingEnabled = false
        assertEquals(TrackingState.NOT_INSTAGRAM, manager.getCurrentState())
    }

    @Test
    fun `events ignored when tracking disabled`() {
        manager.isTrackingEnabled = false
        manager.process(fakeEvent(), null)
        // Should still be NOT_INSTAGRAM since tracking is off.
        assertEquals(TrackingState.NOT_INSTAGRAM, manager.getCurrentState())
        verify(exactly = 0) { bridge.emitInstagramStatus(any()) }
    }

    // ---------------------------------------------------------------------------
    // Debug info
    // ---------------------------------------------------------------------------

    @Test
    fun `getDebugInfo returns map with expected keys`() {
        val info = manager.getDebugInfo()
        assert(info.containsKey("state"))
        assert(info.containsKey("confidence"))
        assert(info.containsKey("lastFingerprint"))
        assert(info.containsKey("trackingEnabled"))
    }
}
