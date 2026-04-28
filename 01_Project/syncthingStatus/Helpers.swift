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

func hasSignificantActivity(history: DeviceTransferHistory) -> Bool {
    // Only show chart if there's been meaningful transfer activity
    // Minimum threshold: 1 KB/s peak speed
    let maxDown = history.dataPoints.map { $0.downloadRate }.max() ?? 0
    let maxUp = history.dataPoints.map { $0.uploadRate }.max() ?? 0
    return max(maxDown, maxUp) >= AppConstants.Network.activityThresholdBytes
}

func isEffectivelySynced(completion: SyncthingDeviceCompletion, settings: SyncthingSettings) -> Bool {
    // Consider a device "synced" if:
    // 1. It's at 100%, OR
    // 2. It's >= threshold% complete AND has less than threshold bytes remaining
    // This handles the case where Syncthing shows 95%+ but with 0 bytes remaining
    return completion.completion >= 100.0 ||
           (completion.completion >= settings.syncCompletionThreshold &&
            completion.needBytes < settings.syncRemainingBytesThreshold)
}
