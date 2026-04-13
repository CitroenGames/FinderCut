import AppKit
import ApplicationServices

/// Checks and requests macOS Accessibility permission, which is required
/// for CGEventTap to intercept and modify keyboard events.
enum AccessibilityChecker {

    /// Returns true if this app has been granted Accessibility permission.
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    private static var pollTimer: Timer?

    /// Prompts the user to grant Accessibility permission via the system dialog.
    /// Opens System Settings > Privacy & Security > Accessibility with the app pre-selected.
    @discardableResult
    static func requestPermission() -> Bool {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true
        ] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Polls `AXIsProcessTrusted()` every second until permission is granted,
    /// then calls `onGranted` on the main thread. macOS provides no notification
    /// for accessibility permission changes, so polling is the standard approach.
    static func pollForPermission(onGranted: @escaping () -> Void) {
        stopPolling()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if AXIsProcessTrusted() {
                timer.invalidate()
                pollTimer = nil
                NSLog("FinderCut: Accessibility permission granted (detected by polling)")
                onGranted()
            }
        }
    }

    static func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    /// Opens the Accessibility settings pane directly.
    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
