import AppKit

/// Detects whether macOS Finder is the currently active (frontmost) application.
enum FinderDetector {

    static let finderBundleID = "com.apple.finder"

    /// Returns true if Finder is currently the frontmost application.
    static var isFinderFrontmost: Bool {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier == finderBundleID
    }

    /// Returns the bundle identifier of the currently frontmost application.
    static var frontmostBundleID: String? {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }
}
