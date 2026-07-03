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

struct SyncthingDevice: Codable, Identifiable, Equatable {
    let deviceID: String
    let name: String
    let addresses: [String]
    let paused: Bool

    var id: String { deviceID }
}

struct SyncthingFolder: Codable, Identifiable, Equatable {
    let id: String
    let label: String
    let path: String
    let devices: [SyncthingFolderDevice]
    var paused: Bool
}

struct SyncthingFolderDevice: Codable, Equatable {
    let deviceID: String
}

struct SyncthingConnection: Codable, Equatable {
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

struct SyncthingFolderStatus: Codable, Equatable {
    let globalFiles: Int
    let globalBytes: Int64
    let localFiles: Int
    let localBytes: Int64
    let needFiles: Int
    let needBytes: Int64
    /// Items the local node still needs to *delete* to be in sync. Stays > 0
    /// when Syncthing refuses to remove a directory containing `.stignore`-matched
    /// files (the "stuck deletes" failure mode). Defaults to 0 if the daemon
    /// omits the field, so the icon stays calm on partial responses.
    let needDeletes: Int
    /// Sum of all `need*` counters. Preferred over individual fields when present
    /// because it's the same value the WebUI uses to decide "Out of Sync".
    let needTotalItems: Int
    let state: String
    let lastScan: String?

    init(
        globalFiles: Int,
        globalBytes: Int64,
        localFiles: Int,
        localBytes: Int64,
        needFiles: Int,
        needBytes: Int64,
        needDeletes: Int,
        needTotalItems: Int,
        state: String,
        lastScan: String?
    ) {
        self.globalFiles = globalFiles
        self.globalBytes = globalBytes
        self.localFiles = localFiles
        self.localBytes = localBytes
        self.needFiles = needFiles
        self.needBytes = needBytes
        self.needDeletes = needDeletes
        self.needTotalItems = needTotalItems
        self.state = state
        self.lastScan = lastScan
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        globalFiles = (try? c.decode(Int.self, forKey: .globalFiles)) ?? 0
        globalBytes = (try? c.decode(Int64.self, forKey: .globalBytes)) ?? 0
        localFiles = (try? c.decode(Int.self, forKey: .localFiles)) ?? 0
        localBytes = (try? c.decode(Int64.self, forKey: .localBytes)) ?? 0
        needFiles = (try? c.decode(Int.self, forKey: .needFiles)) ?? 0
        needBytes = (try? c.decode(Int64.self, forKey: .needBytes)) ?? 0
        needDeletes = (try? c.decode(Int.self, forKey: .needDeletes)) ?? 0
        needTotalItems = (try? c.decode(Int.self, forKey: .needTotalItems)) ?? 0
        state = (try? c.decode(String.self, forKey: .state)) ?? "idle"
        lastScan = try? c.decode(String.self, forKey: .lastScan)
    }
}

struct SyncthingDeviceCompletion: Codable, Equatable {
    let completion: Double
    let globalBytes: Int64
    let needBytes: Int64
    let needDeletes: Int

    init(completion: Double, globalBytes: Int64, needBytes: Int64, needDeletes: Int = 0) {
        self.completion = completion
        self.globalBytes = globalBytes
        self.needBytes = needBytes
        self.needDeletes = needDeletes
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        completion = (try? c.decode(Double.self, forKey: .completion)) ?? 0
        globalBytes = (try? c.decode(Int64.self, forKey: .globalBytes)) ?? 0
        needBytes = (try? c.decode(Int64.self, forKey: .needBytes)) ?? 0
        needDeletes = (try? c.decode(Int.self, forKey: .needDeletes)) ?? 0
    }
}

// MARK: - /rest/db/need response
/// One item in Syncthing's `db/need` response — a file or directory the local
/// node still needs to act on to be in sync. Stuck deletes show up here as
/// `deleted: true` directory entries.
///
/// The official REST docs don't list `deleted` or `type` in the file objects,
/// but live diagnostics against real daemons confirm both are present (the
/// design doc author observed them). We decode defensively: a missing `deleted`
/// flag defaults to `false` and a missing `type` to `""`, both of which fail
/// the cleanup filter — so a future field rename in Syncthing v3 degrades to
/// "no candidates found" rather than offering up the wrong items for deletion.
struct RemoteNeedItem: Decodable, Identifiable, Equatable {
    let name: String
    let deleted: Bool
    let type: String
    let size: Int64

    var id: String { name }
    /// Syncthing reports `FILE_INFO_TYPE_DIRECTORY` for directories. The suffix
    /// match is robust to enum-prefix changes between API versions.
    var isDirectory: Bool { type.hasSuffix("DIRECTORY") }

    /// Explicit because Swift only synthesizes `CodingKeys` when it's also
    /// synthesizing one of `init(from:)` / `encode(to:)`. We provide our own
    /// `init(from:)` *and* the type is `Decodable`-only, so no synthesis runs.
    private enum CodingKeys: String, CodingKey {
        case name, deleted, type, size
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        deleted = (try? c.decode(Bool.self, forKey: .deleted)) ?? false
        type = (try? c.decode(String.self, forKey: .type)) ?? ""
        size = (try? c.decode(Int64.self, forKey: .size)) ?? 0
    }
}

/// Response shape for `GET /rest/db/need`. Three buckets:
/// - `progress`: items currently being processed
/// - `queued`: items committed for next processing
/// - `rest`: everything else still needed
///
/// Stuck deletes typically appear in `rest` (Syncthing isn't actively trying
/// them), but we merge all three buckets so a delete that briefly cycles
/// through `progress`/`queued` isn't missed.
struct DbNeedResponse: Decodable {
    let progress: [RemoteNeedItem]
    let queued: [RemoteNeedItem]
    let rest: [RemoteNeedItem]

    var allItems: [RemoteNeedItem] { progress + queued + rest }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        progress = (try? c.decode([RemoteNeedItem].self, forKey: .progress)) ?? []
        queued = (try? c.decode([RemoteNeedItem].self, forKey: .queued)) ?? []
        rest = (try? c.decode([RemoteNeedItem].self, forKey: .rest)) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case progress, queued, rest
    }
}

// MARK: - Transfer Rate Tracking
struct TransferRates: Equatable {
    var downloadRate: Double = 0  // bytes per second
    var uploadRate: Double = 0    // bytes per second
}

// MARK: - Connection History Tracking
struct ConnectionHistory: Equatable {
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

struct SyncEvent: Identifiable, Equatable {
    let id = UUID()
    let folderID: String
    let folderName: String
    let eventType: SyncEventType
    let timestamp: Date
    let details: String?

    // Custom Equatable implementation - compare everything except UUID
    static func == (lhs: SyncEvent, rhs: SyncEvent) -> Bool {
        lhs.folderID == rhs.folderID &&
        lhs.folderName == rhs.folderName &&
        lhs.eventType == rhs.eventType &&
        lhs.timestamp == rhs.timestamp &&
        lhs.details == rhs.details
    }
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