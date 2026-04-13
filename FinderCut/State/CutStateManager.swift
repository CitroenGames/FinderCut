import AppKit

/// Manages the "pending cut" state shared between the main app (CGEventTap)
/// and the Finder Sync extension (context menu).
///
/// State is stored in shared UserDefaults (via App Groups) so both the main app
/// and extension can read/write the cut state and file paths.
final class CutStateManager {

    static let shared = CutStateManager()

    private let defaults = SharedDefaults.shared

    private init() {}

    // MARK: - Pending Cut Flag

    /// Returns true if there are files waiting to be moved (cut but not yet pasted).
    var hasPendingCut: Bool {
        defaults.bool(forKey: SharedDefaults.Keys.hasPendingCut)
    }

    /// Marks that Cmd+X was pressed in Finder. The actual file paths are
    /// on the system pasteboard (via the simulated Cmd+C).
    func setPendingCut() {
        defaults.set(true, forKey: SharedDefaults.Keys.hasPendingCut)

        // Also read the pasteboard to store file URLs for the extension's context menu
        storePasteboardFileURLs()
    }

    /// Clears the pending cut state after a successful paste/move or cancellation.
    func clearPendingCut() {
        defaults.set(false, forKey: SharedDefaults.Keys.hasPendingCut)
        defaults.removeObject(forKey: SharedDefaults.Keys.pendingCutFiles)
    }

    // MARK: - File Paths

    /// Returns the file paths that were "cut" (pending move), or nil if none.
    var pendingFilePaths: [String]? {
        defaults.stringArray(forKey: SharedDefaults.Keys.pendingCutFiles)
    }

    /// Stores specific file paths as the pending cut files.
    /// Called by the Finder Sync extension when "Cut" is selected from the context menu.
    func setPendingFiles(_ paths: [String]) {
        defaults.set(paths, forKey: SharedDefaults.Keys.pendingCutFiles)
        defaults.set(true, forKey: SharedDefaults.Keys.hasPendingCut)
    }

    // MARK: - Private

    /// Reads file URLs from the system pasteboard and stores them in shared defaults.
    /// This is called after simulating Cmd+C so the extension can also access the cut files.
    private func storePasteboardFileURLs() {
        let pasteboard = NSPasteboard.general

        // Small delay to allow the simulated Cmd+C to populate the pasteboard
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [
                .urlReadingFileURLsOnly: true
            ]) as? [URL] else {
                return
            }

            let paths = urls.map { $0.path }
            if !paths.isEmpty {
                self?.defaults.set(paths, forKey: SharedDefaults.Keys.pendingCutFiles)
            }
        }
    }
}
