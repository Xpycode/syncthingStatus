import Foundation

// MARK: - Syncthing Data Models (Corrected)
struct SyncthingSystemStatus: Codable {
    let myID: String
    let tilde: String?
    let uptime: Int
    let version: String?
}

struct SyncthingVersion: Codable {
    let version: String
}

struct SyncthingConfig: Codable {
    let devices: [SyncthingDevice]
    var folders: [SyncthingFolder]
}

struct SyncthingDevice: Codable, Identifiable {
    let deviceID: String
    let name: String
    let addresses: [String]
    let paused: Bool
    
    var id: String { deviceID }
}

struct SyncthingFolder: Codable, Identifiable {
    let id: String
    let label: String
    let path: String
    let devices: [SyncthingFolderDevice]
    var paused: Bool
}

struct SyncthingFolderDevice: Codable {
    let deviceID: String
}

struct SyncthingConnection: Codable {
    let connected: Bool
    let address: String?
    let clientVersion: String?
    let type: String?
    let inBytesTotal: Int64
    let outBytesTotal: Int64
}

struct SyncthingConnections: Codable {
    let connections: [String: SyncthingConnection]
    let total: SyncthingConnectionsTotal?
}

struct SyncthingConnectionsTotal: Codable {
    let connected: Int?
    let paused: Int?
    let inBytesTotal: Int64?
    let outBytesTotal: Int64?
}

struct SyncthingFolderStatus: Codable {
    let globalFiles: Int
    let globalBytes: Int64
    let localFiles: Int
    let localBytes: Int64
    let needFiles: Int
    let needBytes: Int64
    let state: String
    let lastScan: String?
}

struct SyncthingDeviceCompletion: Codable {
    let completion: Double
    let globalBytes: Int64
    let needBytes: Int64
}

// MARK: - Transfer Rate Tracking
struct TransferRates {
    var downloadRate: Double = 0  // bytes per second
    var uploadRate: Double = 0    // bytes per second
}

// MARK: - Connection History Tracking
struct ConnectionHistory {
    var connectedSince: Date?      // When device connected
    var lastSeen: Date?            // Last time device was connected
    var isCurrentlyConnected: Bool = false
}

// MARK: - Sync Event Tracking
enum SyncEventType {
    case syncStarted
    case syncCompleted
    case idle
}

struct SyncEvent: Identifiable {
    let id = UUID()
    let folderID: String
    let folderName: String
    let eventType: SyncEventType
    let timestamp: Date
    let details: String?
}

// MARK: - Time-Series Data for Charts
struct TransferDataPoint: Identifiable {
    let id = UUID()
    let timestamp: Date
    let downloadRate: Double  // bytes per second
    let uploadRate: Double    // bytes per second
}

struct DeviceTransferHistory {
    var dataPoints: [TransferDataPoint] = []
    let maxDataPoints = AppConstants.UI.maxTransferDataPoints

    // Cached max values to avoid recalculating on every render
    private(set) var maxDownloadRate: Double = 0
    private(set) var maxUploadRate: Double = 0

    mutating func addDataPoint(downloadRate: Double, uploadRate: Double) {
        let point = TransferDataPoint(
            timestamp: Date(),
            downloadRate: downloadRate,
            uploadRate: uploadRate
        )
        dataPoints.append(point)

        // Update max values incrementally
        maxDownloadRate = max(maxDownloadRate, downloadRate)
        maxUploadRate = max(maxUploadRate, uploadRate)

        // Remove old data points and recalculate max if needed
        if dataPoints.count > maxDataPoints {
            let removedCount = dataPoints.count - maxDataPoints
            let removedPoints = dataPoints.prefix(removedCount)

            // Only recalculate max if we're removing a point that was the maximum
            let removedMaxDownload = removedPoints.max(by: { $0.downloadRate < $1.downloadRate })?.downloadRate ?? 0
            let removedMaxUpload = removedPoints.max(by: { $0.uploadRate < $1.uploadRate })?.uploadRate ?? 0

            dataPoints.removeFirst(removedCount)

            // Recalculate max values if we removed the max
            if removedMaxDownload >= maxDownloadRate || removedMaxUpload >= maxUploadRate {
                recalculateMaxValues()
            }
        }
    }

    private mutating func recalculateMaxValues() {
        maxDownloadRate = dataPoints.max(by: { $0.downloadRate < $1.downloadRate })?.downloadRate ?? 0
        maxUploadRate = dataPoints.max(by: { $0.uploadRate < $1.uploadRate })?.uploadRate ?? 0
    }
}