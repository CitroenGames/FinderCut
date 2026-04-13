import CoreGraphics
import AppKit

/// Manages a CGEventTap that intercepts keyboard events system-wide.
/// When Finder is the frontmost app:
///   - Cmd+X is intercepted → simulates Cmd+C and sets a "pending cut" flag
///   - Cmd+V with pending cut → simulates Option+Cmd+V (Finder's native "Move Item Here")
///   - Cmd+V without pending cut → passes through normally (standard paste)
/// All events in non-Finder apps pass through unchanged.
final class EventTapManager {

    static let shared = EventTapManager()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isRunning = false

    private init() {}

    // MARK: - Public

    func start() {
        guard !isRunning else { return }

        guard AccessibilityChecker.isTrusted else {
            NSLog("FinderCut: Accessibility permission not granted. Cannot create event tap.")
            AccessibilityChecker.requestPermission()
            return
        }

        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

        // Pass a pointer to self so the C callback can access instance methods
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: EventTapManager.eventTapCallback,
            userInfo: selfPointer
        ) else {
            NSLog("FinderCut: Failed to create CGEvent tap. Check Accessibility permissions.")
            return
        }

        self.eventTap = tap

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source

        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        isRunning = true
        NSLog("FinderCut: Event tap started successfully.")
    }

    func stop() {
        guard isRunning, let tap = eventTap else { return }

        CGEvent.tapEnable(tap: tap, enable: false)

        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }

        eventTap = nil
        runLoopSource = nil
        isRunning = false

        NSLog("FinderCut: Event tap stopped.")
    }

    // MARK: - Event Tap Callback

    /// The C-function callback invoked by the CGEventTap for each keyDown event.
    /// Must return the event to pass it through, or nil to swallow it.
    private static let eventTapCallback: CGEventTapCallBack = {
        (proxy, type, event, userInfo) -> Unmanaged<CGEvent>? in

        // Handle tap being disabled by the system
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            NSLog("FinderCut: Event tap was disabled, re-enabling.")
            if let userInfo = userInfo {
                let manager = Unmanaged<EventTapManager>.fromOpaque(userInfo).takeUnretainedValue()
                if let tap = manager.eventTap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
            }
            return Unmanaged.passUnretained(event)
        }

        // Only process keyDown events
        guard type == .keyDown else {
            return Unmanaged.passUnretained(event)
        }

        // Only intercept when Finder is the frontmost app
        guard FinderDetector.isFinderFrontmost else {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags

        // Check for Command modifier (ignore if other modifiers like Shift/Control are also held)
        let commandOnly = flags.contains(.maskCommand)
            && !flags.contains(.maskControl)
            && !flags.contains(.maskAlternate)

        let commandAndOption = flags.contains(.maskCommand) && flags.contains(.maskAlternate)
            && !flags.contains(.maskControl)

        // Cmd+X → Intercept, simulate Cmd+C, set pending cut
        if commandOnly && keyCode == KeySimulator.keyCodeX {
            NSLog("FinderCut: Intercepted Cmd+X in Finder → simulating Cmd+C")

            // Simulate Cmd+C (copy to pasteboard)
            KeySimulator.simulateCopy()

            // Mark that we have a pending cut
            CutStateManager.shared.setPendingCut()

            // Play sound if enabled
            if UserDefaults.standard.bool(forKey: "playSoundOnCut") {
                DispatchQueue.main.async {
                    NSSound(named: .init("Funk"))?.play()
                }
            }

            // Swallow the original Cmd+X event
            return nil
        }

        // Cmd+V with pending cut → Intercept, simulate Option+Cmd+V (move)
        if commandOnly && keyCode == KeySimulator.keyCodeV && CutStateManager.shared.hasPendingCut {
            NSLog("FinderCut: Intercepted Cmd+V with pending cut → simulating Option+Cmd+V (move)")

            // Simulate Option+Cmd+V (Finder's native "Move Item Here")
            KeySimulator.simulateMove()

            // Clear the pending cut state
            CutStateManager.shared.clearPendingCut()

            // Swallow the original Cmd+V event
            return nil
        }

        // Cmd+Option+V (native move) → Clear pending cut if user triggers it manually
        if commandAndOption && keyCode == KeySimulator.keyCodeV {
            CutStateManager.shared.clearPendingCut()
        }

        // All other events pass through unchanged
        return Unmanaged.passUnretained(event)
    }
}
