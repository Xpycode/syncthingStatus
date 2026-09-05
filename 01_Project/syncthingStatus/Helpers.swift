import Foundation
import SwiftUI

// MARK: - Helper Functions
func formatUptime(_ seconds: Int) -> String {
    let duration = TimeInterval(seconds)
    let formatter = DateComponentsFormatter()
    formatter.unitsStyle = .abbreviated
    formatter.allowedUnits = [.day, .hour, .minute]
    return formatter.string(from: duration) ?? "0m"
}

// Corrected to handle Int64
func formatBytes(_ bytes: Int64) -> String {
    let bcf = ByteCountFormatter()
    bcf.allowedUnits = [.useAll]
    bcf.countStyle = .file
    return bcf.string(fromByteCount: bytes)
}

func formatTransferRate(_ bytesPerSecond: Double) -> String {
    if bytesPerSecond < 1 {
        return "0 B/s"
    }
    let bcf = ByteCountFormatter()
    bcf.allowedUnits = [.useAll]
    bcf.countStyle = .binary
    return bcf.string(fromByteCount: Int64(bytesPerSecond)) + "/s"
}

func formatRelativeTime(since date: Date) -> String {
    let now = Date()
    let interval = now.timeIntervalSince(date)

    if interval < 60 {
        return "Just now"
    } else if interval < 3600 {
        let minutes = Int(interval / 60)
        return "\(minutes)m ago"
    } else if interval < 86400 {
        let hours = Int(interval / 3600)
        return "\(hours)h ago"
    } else {
        let days = Int(interval / 86400)
        return "\(days)d ago"
    }
}

func formatConnectionDuration(since date: Date?) -> String {
    guard let date = date else { return "Not connected" }
    let interval = Date().timeIntervalSince(date)
    let formatter = DateComponentsFormatter()
    formatter.unitsStyle = .abbreviated
    formatter.allowedUnits = [.day, .hour, .minute]
    formatter.maximumUnitCount = 2
    return formatter.string(from: interval) ?? "0m"
}

func isEffectivelySynced(completion: SyncthingDeviceCompletion, settings: SyncthingSettings) -> Bool {
    SyncStatusPolicy.isComplete(completion)
}

// MARK: - Real-home path expansion

/// The user's *real* home directory (`/Users/<name>`), via `getpwuid`.
/// Under App Sandbox every Foundation home API — `NSHomeDirectory()`,
/// `FileManager.homeDirectoryForCurrentUser`, `NSString.expandingTildeInPath`,
/// `.standardizingPath` — resolves to the app's container instead. Syncthing's
/// config paths mean the real home, so those APIs must never touch them.
func realHomeDirectoryPath() -> String? {
    guard let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir else { return nil }
    // Copy immediately — pw_dir points at static per-thread storage.
    return FileManager.default.string(withFileSystemRepresentation: dir, length: strlen(dir))
}

/// Expands a leading `~` against the real home directory. Non-tilde paths
/// (and an unresolvable passwd entry) pass through unchanged.
func expandingTildeToRealHome(_ path: String) -> String {
    guard path == "~" || path.hasPrefix("~/") else { return path }
    guard let home = realHomeDirectoryPath() else { return path }
    return home + path.dropFirst(1)
}

extension SyncthingFolder {
    /// Folder root as a filesystem-usable absolute path — `~` expanded to the
    /// real home. `path` keeps Syncthing's literal spelling for display.
    var realPath: String { expandingTildeToRealHome(path) }
    /// `realPath` as a directory URL, for Finder reveals and open panels.
    var realURL: URL { URL(fileURLWithPath: realPath, isDirectory: true) }
}

extension SyncthingFolderStatus {
    var hasPendingWork: Bool { SyncStatusPolicy.hasPendingWork(self) }

    /// Individual counters explain work; the aggregate is only a fallback, not an extra count.
    var pendingSummary: String {
        var parts: [String] = []
        if needFiles > 0 { parts.append("\(needFiles) file\(needFiles == 1 ? "" : "s")") }
        if needDirectories > 0 { parts.append("\(needDirectories) director\(needDirectories == 1 ? "y" : "ies")") }
        if needSymlinks > 0 { parts.append("\(needSymlinks) symlink\(needSymlinks == 1 ? "" : "s")") }
        if needDeletes > 0 { parts.append("\(needDeletes) delete\(needDeletes == 1 ? "" : "s")") }
        // Max, not sum, also avoids overflow on inconsistent but nonnegative counters.
        let described = [needFiles, needDirectories, needSymlinks, needDeletes].reduce(0) { sum, count in
            let (next, overflow) = sum.addingReportingOverflow(count)
            return overflow ? Int.max : next
        }
        if needTotalItems > described {
            let other = needTotalItems - described
            parts.append("\(other) other item\(other == 1 ? "" : "s")")
        }
        if needBytes > 0 { parts.append(formatBytes(needBytes)) }
        return parts.joined(separator: ", ")
    }
}

extension SyncthingDeviceCompletion {
    var pendingSummary: String {
        var parts: [String] = []
        if needItems > 0 { parts.append("\(needItems) item\(needItems == 1 ? "" : "s")") }
        if needDeletes > 0 { parts.append("\(needDeletes) delete\(needDeletes == 1 ? "" : "s")") }
        if needBytes > 0 { parts.append(formatBytes(needBytes)) }
        return parts.isEmpty ? "Checking completion" : parts.joined(separator: ", ")
    }
}
