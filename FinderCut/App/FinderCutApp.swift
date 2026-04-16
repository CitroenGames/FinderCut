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
    @State private var accessibilityGranted = AccessibilityChecker.isTrusted
    private let timer = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()

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

        Text(accessibilityGranted ? "Accessibility: Granted" : "Accessibility: Not Granted")
            .foregroundColor(accessibilityGranted ? .green : .red)
            .onReceive(timer) { _ in
                accessibilityGranted = AccessibilityChecker.isTrusted
            }

        if !accessibilityGranted {
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
