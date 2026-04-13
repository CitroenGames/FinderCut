import CoreGraphics
import AppKit

/// Simulates keyboard shortcuts by creating and posting CGEvents.
/// Used to translate Cmd+X into Cmd+C, and Cmd+V into Option+Cmd+V.
enum KeySimulator {

    // MARK: - macOS Virtual Key Codes

    static let keyCodeC: CGKeyCode = 0x08
    static let keyCodeV: CGKeyCode = 0x09
    static let keyCodeX: CGKeyCode = 0x07

    /// Guard flag to prevent the event tap from intercepting our own simulated events.
    static var isSimulating = false

    // MARK: - Public Methods

    /// Simulates pressing Cmd+C (copy) by posting keyDown and keyUp events.
    static func simulateCopy() {
        postKeyEvent(keyCode: keyCodeC, flags: .maskCommand)
    }

    /// Simulates pressing Option+Cmd+V (move item here) by posting keyDown and keyUp events.
    /// This triggers Finder's native "Move Item Here" action.
    static func simulateMove() {
        postKeyEvent(keyCode: keyCodeV, flags: [.maskCommand, .maskAlternate])
    }

    // MARK: - Private

    private static func postKeyEvent(keyCode: CGKeyCode, flags: CGEventFlags) {
        // Use .privateState so simulated modifier flags are independent from
        // the physical keyboard state. With .hidSystemState, Finder can see
        // that Option isn't physically held and ignore the modifier.
        let source = CGEventSource(stateID: .privateState)

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            NSLog("FinderCut: Failed to create CGEvent for keyCode \(keyCode)")
            return
        }

        keyDown.flags = flags
        keyUp.flags = flags

        isSimulating = true

        keyDown.post(tap: .cghidEventTap)
        // Delay so Finder processes keyDown before keyUp arrives
        usleep(50_000)
        keyUp.post(tap: .cghidEventTap)
        usleep(10_000)

        isSimulating = false
    }
}
