import Cocoa
import FinderSync

/// Finder Sync extension that adds "Cut" and "Paste Here (Move)" to Finder's
/// right-click context menu. Shares state with the main app via App Groups.
class FinderSync: FIFinderSync {

    private let sharedDefaults: UserDefaults

    // MARK: - App Group suite name (must match the main app's SharedDefaults.suiteName)
    private static let suiteName = "group.com.findercut.shared"

    private enum Keys {
        static let pendingCutFiles = "pendingCutFiles"
        static let hasPendingCut = "hasPendingCut"
    }

    // MARK: - Initialization

    override init() {
        self.sharedDefaults = UserDefaults(suiteName: FinderSync.suiteName) ?? .standard

        super.init()

        // Monitor all user-accessible directories so context menu appears everywhere
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]

        NSLog("FinderCutExtension: Initialized, monitoring all directories.")
    }

    // MARK: - Context Menu

    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        let menu = NSMenu(title: "FinderCut")

        switch menuKind {
        case .contextualMenuForItems:
            // User right-clicked on one or more files/folders
            let cutItem = NSMenuItem(
                title: NSLocalizedString("Cut", comment: "Context menu item to cut files"),
                action: #selector(cutSelectedFiles(_:)),
                keyEquivalent: ""
            )
            cutItem.image = NSImage(systemSymbolName: "scissors", accessibilityDescription: NSLocalizedString("Cut accessibility", comment: "Accessibility description for cut icon"))
            menu.addItem(cutItem)

            // Also show "Paste Here" if there are pending cut files
            addPasteItemIfNeeded(to: menu)

        case .contextualMenuForContainer:
            // User right-clicked on the folder background (empty space)
            addPasteItemIfNeeded(to: menu)

        case .contextualMenuForSidebar:
            // Sidebar right-click - show paste option if pending
            addPasteItemIfNeeded(to: menu)

        case .toolbarItemMenu:
            // Toolbar button click
            let cutItem = NSMenuItem(
                title: NSLocalizedString("Cut Selected", comment: "Toolbar menu item to cut files"),
                action: #selector(cutSelectedFiles(_:)),
                keyEquivalent: ""
            )
            menu.addItem(cutItem)
            addPasteItemIfNeeded(to: menu)

        @unknown default:
            break
        }

        return menu
    }

    // MARK: - Menu Actions

    @objc func cutSelectedFiles(_ sender: AnyObject?) {
        guard let selectedURLs = FIFinderSyncController.default().selectedItemURLs(),
              !selectedURLs.isEmpty else {
            NSLog("FinderCutExtension: No files selected for cut.")
            return
        }

        let paths = selectedURLs.map { $0.path }
        sharedDefaults.set(paths, forKey: Keys.pendingCutFiles)
        sharedDefaults.set(true, forKey: Keys.hasPendingCut)

        NSLog("FinderCutExtension: Cut \(paths.count) item(s): \(paths)")
    }

    @objc func pasteFiles(_ sender: AnyObject?) {
        guard let targetURL = FIFinderSyncController.default().targetedURL() else {
            NSLog("FinderCutExtension: No target directory for paste.")
            return
        }

        guard let paths = sharedDefaults.stringArray(forKey: Keys.pendingCutFiles),
              !paths.isEmpty else {
            NSLog("FinderCutExtension: No pending cut files to paste.")
            return
        }

        NSLog("FinderCutExtension: Pasting \(paths.count) item(s) to \(targetURL.path)")

        var errors: [(String, Error)] = []

        for path in paths {
            let sourceURL = URL(fileURLWithPath: path)
            let destinationURL = targetURL.appendingPathComponent(sourceURL.lastPathComponent)

            do {
                // Handle name collision
                let finalDestination = resolveNameCollision(for: destinationURL)
                try FileManager.default.moveItem(at: sourceURL, to: finalDestination)
                NSLog("FinderCutExtension: Moved \(sourceURL.lastPathComponent) → \(finalDestination.path)")
            } catch {
                NSLog("FinderCutExtension: Failed to move \(path): \(error.localizedDescription)")
                errors.append((path, error))
            }
        }

        // Clear pending state
        sharedDefaults.removeObject(forKey: Keys.pendingCutFiles)
        sharedDefaults.set(false, forKey: Keys.hasPendingCut)

        // Show alert if there were errors
        if !errors.isEmpty {
            logMoveErrors(errors)
        }
    }

    // MARK: - Toolbar Item (optional)

    override var toolbarItemName: String {
        return "FinderCut"
    }

    override var toolbarItemToolTip: String {
        return NSLocalizedString("Cut and paste files", comment: "Toolbar tooltip")
    }

    override var toolbarItemImage: NSImage {
        return NSImage(systemSymbolName: "scissors", accessibilityDescription: "FinderCut") ?? NSImage()
    }

    // MARK: - Private Helpers

    private func addPasteItemIfNeeded(to menu: NSMenu) {
        let hasPending = sharedDefaults.bool(forKey: Keys.hasPendingCut)
        let paths = sharedDefaults.stringArray(forKey: Keys.pendingCutFiles)

        if hasPending, let paths = paths, !paths.isEmpty {
            let count = paths.count
            let format = NSLocalizedString("Paste Here (Move %d items)", comment: "Paste menu item with file count")
            let title = String.localizedStringWithFormat(format, count)

            let pasteItem = NSMenuItem(
                title: title,
                action: #selector(pasteFiles(_:)),
                keyEquivalent: ""
            )
            pasteItem.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: NSLocalizedString("Paste accessibility", comment: "Accessibility description for paste icon"))
            menu.addItem(pasteItem)
        }
    }

    /// Resolves file name collisions by appending a number suffix.
    /// e.g., "file.txt" → "file 2.txt" → "file 3.txt"
    private func resolveNameCollision(for url: URL) -> URL {
        var destinationURL = url
        var counter = 2

        while FileManager.default.fileExists(atPath: destinationURL.path) {
            let name = url.deletingPathExtension().lastPathComponent
            let ext = url.pathExtension

            let newName = ext.isEmpty
                ? "\(name) \(counter)"
                : "\(name) \(counter).\(ext)"

            destinationURL = url.deletingLastPathComponent().appendingPathComponent(newName)
            counter += 1
        }

        return destinationURL
    }

    /// Logs failed file moves. Finder Sync extensions run as XPC processes
    /// and cannot present modal alerts (NSAlert.runModal won't work).
    private func logMoveErrors(_ errors: [(String, Error)]) {
        for (path, error) in errors {
            let name = URL(fileURLWithPath: path).lastPathComponent
            NSLog("FinderCutExtension: Failed to move \(name): \(error.localizedDescription)")
        }
        NSLog("FinderCutExtension: \(errors.count) file(s) could not be moved.")
    }
}
