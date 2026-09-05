import Foundation

enum SyncState: Equatable {
    case normal, warning, error, uploading, downloading, upAndDown
}

/// One semantic decision for rows, the menu-bar resolver and completion events.
/// Threshold preferences affect neither pending counters nor proof of completion.
enum SyncStatusPolicy {
    enum FolderState: Equatable {
        case upToDate, pending, paused, unavailable, error
        case active(String)

        var title: String {
            switch self {
            case .upToDate: return "Up to date"
            case .pending: return "Out of sync"
            case .paused: return "Paused"
            case .unavailable: return "Status unavailable"
            case .error: return "Folder error"
            case .active(let state): return state.replacingOccurrences(of: "-", with: " ").capitalized
            }
        }
    }

    enum DeviceState: Equatable {
        case upToDate, pending, paused, unavailable, offline
    }

    static let activeFolderStates: Set<String> = [
        "starting", "syncing", "scanning", "scan-waiting", "sync-preparing", "sync-waiting",
        "cleaning", "clean-waiting"
    ]

    static func hasPendingWork(_ status: SyncthingFolderStatus) -> Bool {
        status.needBytes > 0 || status.needTotalItems > 0 || status.needFiles > 0 ||
        status.needDirectories > 0 || status.needSymlinks > 0 || status.needDeletes > 0
    }

    static func folder(_ folder: SyncthingFolder, status: SyncthingFolderStatus?) -> FolderState {
        if folder.paused { return .paused }
        guard let status, status.hasValidCounters else { return .unavailable }
        if status.state == "error" { return .error }
        if activeFolderStates.contains(status.state) { return .active(status.state) }
        guard status.state == "idle" else { return .unavailable }
        return hasPendingWork(status) ? .pending : .upToDate
    }

    static func isComplete(_ completion: SyncthingDeviceCompletion) -> Bool {
        completion.isValid && completion.completion == 100 && completion.needBytes == 0 &&
        completion.needItems == 0 && completion.needDeletes == 0
    }

    static func device(_ device: SyncthingDevice, connection: SyncthingConnection?,
                       completion: SyncthingDeviceCompletion?) -> DeviceState {
        if device.paused { return .paused }
        guard let connection else { return .unavailable }
        guard connection.connected else { return .offline }
        guard let completion, completion.isValid else { return .unavailable }
        return isComplete(completion) ? .upToDate : .pending
    }
}

// Kept outside App.swift so hostless tests exercise the exact app resolver.
@MainActor
struct StatusIconStateResolver {
    enum IconDisplayState: Equatable {
        case error(tooltip: String)
        case upAndDown(isActivityBased: Bool)
        case uploading, downloading, paused
        case warning(tooltip: String)
        case unavailable(tooltip: String)
        case inSync, outOfSync

        func iconState(for mode: IconColorMode) -> SyncState {
            switch self {
            case .error, .outOfSync: return .error
            case .unavailable: return .warning
            case .warning, .paused: return mode == .traffic ? .warning : .normal
            case .upAndDown: return .upAndDown
            case .uploading: return .uploading
            case .downloading: return .downloading
            case .inSync: return .normal
            }
        }
    }

    func resolveState(client: SyncthingClient, settings: SyncthingSettings) -> IconDisplayState {
        guard client.isConnected else { return .error(tooltip: "Disconnected") }
        guard client.configurationAvailable || client.demoMode else { return .unavailable(tooltip: "Configuration unavailable") }
        guard !client.folders.isEmpty else { return .warning(tooltip: "No folders") }
        let folders = client.folders.map { SyncStatusPolicy.folder($0, status: client.folderStatuses[$0.id]) }
        let peers = client.devices.map {
            SyncStatusPolicy.device($0, connection: client.connections[$0.id], completion: client.deviceCompletions[$0.id])
        }
        if folders.contains(.error) { return .error(tooltip: "Folder error") }
        if folders.contains(.unavailable) { return .unavailable(tooltip: "Folder status unavailable") }
        if peers.contains(.unavailable) { return .unavailable(tooltip: "Device status unavailable") }
        if folders.allSatisfy({ $0 == .paused }) { return .paused }

        let threshold = AppConstants.Network.activityThresholdBytes
        let downloading = client.currentDownloadSpeed > threshold
        let uploading = client.currentUploadSpeed > threshold
        if uploading && downloading { return .upAndDown(isActivityBased: true) }
        if uploading { return .uploading }
        if downloading { return .downloading }
        if folders.contains(where: { if case .active = $0 { return true }; return false }) || peers.contains(.pending) {
            return .upAndDown(isActivityBased: false)
        }
        if folders.contains(.pending) { return .outOfSync }
        if folders.contains(.paused) { return .warning(tooltip: "Some folders paused") }
        if peers.contains(.paused) { return .warning(tooltip: "Some devices paused") }
        if peers.contains(.offline) { return .warning(tooltip: "Local folders up to date; some devices offline") }
        return .inSync
    }
}

/// The app's completion latch, separated from AppDelegate for transition tests.
struct GlobalSyncCompletionTracker {
    private var pending = false

    mutating func observe(_ state: StatusIconStateResolver.IconDisplayState,
                          hasPendingWork: Bool, isRefreshing: Bool) -> Bool {
        switch state {
        case .error, .unavailable, .warning, .paused:
            pending = false
        case .outOfSync:
            pending = true
        case .upAndDown, .uploading, .downloading:
            pending = pending || hasPendingWork
        case .inSync where !isRefreshing:
            let completed = pending
            pending = false
            return completed
        default:
            break
        }
        return false
    }
}
