import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Check and request accessibility permission
        if !AccessibilityChecker.isTrusted {
            AccessibilityChecker.requestPermission()
        }

        // Start the event tap if enabled
        let isEnabled = UserDefaults.standard.bool(forKey: "isEnabled")
        // Default to enabled on first launch
        if !UserDefaults.standard.contains(key: "isEnabled") {
            UserDefaults.standard.set(true, forKey: "isEnabled")
            EventTapManager.shared.start()
        } else if isEnabled {
            EventTapManager.shared.start()
        }

        // Observe app activation changes to clear cut state when leaving Finder
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(activeAppChanged(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        EventTapManager.shared.stop()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    @objc private func activeAppChanged(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }

        // Clear pending cut state when user switches away from Finder
        if app.bundleIdentifier != FinderDetector.finderBundleID {
            CutStateManager.shared.clearPendingCut()
        }
    }
}

// MARK: - UserDefaults helper

extension UserDefaults {
    func contains(key: String) -> Bool {
        return object(forKey: key) != nil
    }
}

// MARK: - Launch at Login

enum LaunchAtLoginManager {
    static func openSettings() {
        // Open System Settings > Login Items (macOS 13+)
        if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    @available(macOS 13.0, *)
    static func register() {
        do {
            try SMAppService.mainApp.register()
        } catch {
            NSLog("FinderCut: Failed to register for launch at login: \(error)")
        }
    }

    @available(macOS 13.0, *)
    static func unregister() {
        do {
            try SMAppService.mainApp.unregister()
        } catch {
            NSLog("FinderCut: Failed to unregister from launch at login: \(error)")
        }
    }
}
