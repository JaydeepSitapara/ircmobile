package ircmobile.app.ircmobile.instagram

// ---------------------------------------------------------------------------
// Single-responsibility detector: is this event from Instagram?
//
// All Instagram package-name checks must go through this class so that
// changing the package (e.g., for a beta build) only requires one edit.
// ---------------------------------------------------------------------------
object InstagramDetector {

    /** The production Instagram package name. */
    private const val INSTAGRAM_PACKAGE = "com.instagram.android"

    /**
     * Returns true if [packageName] belongs to the Instagram application.
     *
     * Only the known production package is matched. If you need to support
     * Instagram beta (com.instagram.android.lite, etc.) add them here.
     */
    fun isInstagramPackage(packageName: String?): Boolean {
        return packageName == INSTAGRAM_PACKAGE
    }

    /** Convenience accessor for the expected package name. */
    fun instagramPackageName(): String = INSTAGRAM_PACKAGE
}
