import Foundation

/// Provides shared UserDefaults access between the main app and the Finder Sync extension
/// via App Groups. Both targets must have the same App Group identifier configured.
enum SharedDefaults {

    /// The App Group suite name shared between the main app and the Finder Sync extension.
    /// IMPORTANT: Update this to match your actual App Group identifier in Xcode.
    static let suiteName = "group.com.findercut.shared"

    /// Keys used in the shared UserDefaults.
    enum Keys {
        static let pendingCutFiles = "pendingCutFiles"
        static let hasPendingCut = "hasPendingCut"
    }

    /// The shared UserDefaults instance. Falls back to standard if App Group is not configured.
    static var shared: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }
}
