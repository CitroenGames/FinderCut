import SwiftUI

@main
struct FinderCutApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("FinderCut", systemImage: "scissors") {
            MenuBarView()
        }
    }
}

struct MenuBarView: View {
    @AppStorage("isEnabled") private var isEnabled = true
    @AppStorage("playSoundOnCut") private var playSoundOnCut = true

    var body: some View {
        Toggle("Enabled", isOn: $isEnabled)
            .toggleStyle(.switch)
            .onChange(of: isEnabled) { _, newValue in
                if newValue {
                    EventTapManager.shared.start()
                } else {
                    EventTapManager.shared.stop()
                }
            }

        Toggle("Play Sound on Cut", isOn: $playSoundOnCut)

        Divider()

        Button("Launch at Login...") {
            LaunchAtLoginManager.openSettings()
        }

        Divider()

        Text("Accessibility: \(AccessibilityChecker.isTrusted ? "Granted" : "Not Granted")")
            .foregroundColor(AccessibilityChecker.isTrusted ? .green : .red)

        if !AccessibilityChecker.isTrusted {
            Button("Grant Accessibility Permission") {
                AccessibilityChecker.requestPermission()
            }
        }

        Divider()

        Button("Quit FinderCut") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
