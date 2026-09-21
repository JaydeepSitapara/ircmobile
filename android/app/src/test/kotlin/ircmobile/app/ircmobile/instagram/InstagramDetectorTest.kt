package ircmobile.app.ircmobile.instagram

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class InstagramDetectorTest {

    @Test
    fun `Instagram package returns true`() {
        assertTrue(InstagramDetector.isInstagramPackage("com.instagram.android"))
    }

    @Test
    fun `null package returns false`() {
        assertFalse(InstagramDetector.isInstagramPackage(null))
    }

    @Test
    fun `empty string returns false`() {
        assertFalse(InstagramDetector.isInstagramPackage(""))
    }

    @Test
    fun `Chrome package returns false`() {
        assertFalse(InstagramDetector.isInstagramPackage("com.android.chrome"))
    }

    @Test
    fun `WhatsApp package returns false`() {
        assertFalse(InstagramDetector.isInstagramPackage("com.whatsapp"))
    }

    @Test
    fun `own app package returns false`() {
        assertFalse(InstagramDetector.isInstagramPackage("ircmobile.app.ircmobile"))
    }

    @Test
    fun `Instagram Lite package returns false (not supported yet)`() {
        // Instagram Lite has a different package. Document this limitation.
        assertFalse(InstagramDetector.isInstagramPackage("com.instagram.lite"))
    }

    @Test
    fun `partial Instagram package returns false`() {
        assertFalse(InstagramDetector.isInstagramPackage("com.instagram"))
    }
}
