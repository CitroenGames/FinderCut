import AppKit
import ApplicationServices

/// Checks and requests macOS Accessibility permission, which is required
/// for CGEventTap to intercept and modify keyboard events.
enum AccessibilityChecker {

    /// Returns true if this app has been granted Accessibility permission.
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Prompts the user to grant Accessibility permission via the system dialog.
    /// Opens System Settings > Privacy & Security > Accessibility with the app pre-selected.
    @discardableResult
    static func requestPermission() -> Bool {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true
        ] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Opens the Accessibility settings pane directly.
    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
