import Foundation
import os.log

private let bookmarksLog = Logger(subsystem: "com.lucesumbrarum.syncthingStatus", category: "FolderAccess")

/// Persists security-scoped bookmarks for Syncthing folder roots so the
/// sandboxed app can read and delete inside them without Full Disk Access.
///
/// One bookmark per Syncthing folder ID. Stored in `UserDefaults` under
/// `FolderAccessBookmark.<folderID>`. Resolution surfaces stale bookmarks to
/// the caller; `refresh(_:for:)` re-saves bookmark data while inside an active
/// security-scoped access scope.
struct FolderAccessBookmarks {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private static func key(for folderID: String) -> String {
        "FolderAccessBookmark.\(folderID)"
    }

    enum ResolutionResult {
        case resolved(URL, isStale: Bool)
        case missing
        case failed(Error)
    }

    func resolve(for folderID: String) -> ResolutionResult {
        guard let data = defaults.data(forKey: Self.key(for: folderID)) else {
            return .missing
        }
        var stale = false
        do {
            let url = try URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            )
            return .resolved(url, isStale: stale)
        } catch {
            bookmarksLog.error("Bookmark resolve failed for \(folderID, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return .failed(error)
        }
    }

    /// Persists a security-scoped bookmark for the given folder. The URL must
    /// be one obtained from `NSOpenPanel` (or one currently inside an active
    /// `startAccessingSecurityScopedResource()` scope, e.g. when refreshing
    /// a stale bookmark).
    func save(_ url: URL, for folderID: String) throws {
        let data = try url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        defaults.set(data, forKey: Self.key(for: folderID))
        bookmarksLog.info("Bookmark saved for \(folderID, privacy: .public) at \(url.path, privacy: .public)")
    }

    /// Re-saves bookmark data for a stale bookmark. Caller must already have
    /// called `startAccessingSecurityScopedResource()` on the URL. Failures
    /// are logged but not thrown — a stale-but-functional URL is still usable.
    func refresh(_ url: URL, for folderID: String) {
        do {
            try save(url, for: folderID)
        } catch {
            bookmarksLog.error("Bookmark refresh failed for \(folderID, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    func clear(for folderID: String) {
        defaults.removeObject(forKey: Self.key(for: folderID))
    }
}
