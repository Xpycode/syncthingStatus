import Foundation
struct SyncthingSettings { var syncCompletionThreshold: Double = 95; var syncRemainingBytesThreshold: Int64 = 1048576 }
enum AppConstants { enum Network { static let activityThresholdBytes: Double = 1024 }; enum UI { static let maxTransferDataPoints = 60 } }
func formatBytes(_ n: Int64) -> String { String(n) }
struct LoggerStub { func debug(_ s: String) {} }
let networkLog = LoggerStub()
@MainActor class SyncthingClient {
 var isConnected = true
 var folderStatuses: [String: SyncthingFolderStatus] = [:]
 var deviceCompletions: [String: SyncthingDeviceCompletion] = [:]
 var connections: [String: SyncthingConnection] = [:]
 var devices: [SyncthingDevice] = []
 var currentDownloadSpeed: Double = 0
 var currentUploadSpeed: Double = 0
 var activeRefreshTask: Task<Void, Never>?
 var isRefreshing = false
 var startedRequests = 0
 var finishedRequests = 0
 var systemStatus: SyncthingSystemStatus?
 func prepareCredentials() -> Bool { true }
 func handleDisconnectedState() {}
 func fetchStatus() async {
  startedRequests += 1
  do { try await Task.sleep(nanoseconds: 1_000_000_000); finishedRequests += 1 }
  catch { await Task.detached { try? await Task.sleep(nanoseconds: 100_000_000) }.value }
 }
 func fetchConfig(localDeviceID: String) async {}
 func fetchVersion() async {}
 func fetchConnections() async {}
 func fetchFolderStatus() async {}
 func fetchDeviceCompletions() async {}
    func refresh() async {
        // Cancel any previous refresh task
        activeRefreshTask?.cancel()

        activeRefreshTask = Task {
            await performRefresh()
        }
        await activeRefreshTask?.value
    }

    private func performRefresh() async {
        guard !isRefreshing else {
            networkLog.debug("Refresh already in progress")
            return
        }
        isRefreshing = true
        defer { isRefreshing = false }

        guard prepareCredentials() else {
            self.handleDisconnectedState()
            return
        }

        // Check for cancellation
        guard !Task.isCancelled else { return }

        await fetchStatus()

        // Check for cancellation
        guard !Task.isCancelled else { return }

        if let systemStatus = self.systemStatus {
            await fetchConfig(localDeviceID: systemStatus.myID)

            // Check for cancellation
            guard !Task.isCancelled else { return }

            async let versionTask: () = fetchVersion()
            async let connectionsTask: () = fetchConnections()
            async let folderStatusTask: () = fetchFolderStatus()
            async let deviceCompletionTask: () = fetchDeviceCompletions()

            _ = await [versionTask, connectionsTask, folderStatusTask, deviceCompletionTask]
        }
    }

}
@MainActor
struct StatusIconStateResolver {
    enum IconDisplayState {
        case error(tooltip: String)
        case upAndDown(isActivityBased: Bool)
        case uploading
        case downloading
        case paused
        case warning(tooltip: String)
        case inSync
        case outOfSync
    }

    /// Folder states Syncthing reports during normal operation that should not
    /// flag the icon as broken. "idle" is the canonical resting state; the
    /// remaining values are transient stops along the scan/sync pipeline.
    /// Treating only "idle" as healthy (as the previous resolver did) painted
    /// the icon red on every routine background scan.
    static let healthyFolderStates: Set<String> = [
        "idle",
        "scanning",
        "scan-waiting",
        "sync-preparing",
        "sync-waiting",
        "cleaning",
        "clean-waiting"
    ]

    func resolveState(client: SyncthingClient, settings: SyncthingSettings) -> IconDisplayState {
        let activityThreshold = AppConstants.Network.activityThresholdBytes

        // Rule 1: Not connected
        guard client.isConnected else {
            return .error(tooltip: "Disconnected")
        }

        // Rule 2: Folder error trumps everything else — this is a real problem.
        if client.folderStatuses.values.contains(where: { $0.state == "error" }) {
            return .error(tooltip: "Folder error")
        }

        // Rule 3: Network activity
        let totalDownload = client.currentDownloadSpeed
        let totalUpload = client.currentUploadSpeed
        let isDownloading = totalDownload > activityThreshold
        let isUploading = totalUpload > activityThreshold

        if isUploading && isDownloading {
            return .upAndDown(isActivityBased: true)
        } else if isUploading {
            return .uploading
        } else if isDownloading {
            return .downloading
        }

        // Rule 4: Active syncing (folder in "syncing" state, or a connected
        // non-paused device's completion is below threshold).
        let isActivelySyncing = client.folderStatuses.values.contains { $0.state == "syncing" } ||
            client.deviceCompletions.contains { deviceID, completion in
                guard let connection = client.connections[deviceID], connection.connected else { return false }
                return !isEffectivelySynced(completion: completion, settings: settings)
            }

        if isActivelySyncing {
            return .upAndDown(isActivityBased: false)
        }

        // Rule 5: All connected devices paused.
        let connectedDevices = client.devices.filter { client.connections[$0.deviceID]?.connected == true }
        let allConnectedDevicesArePaused = !connectedDevices.isEmpty && connectedDevices.allSatisfy { $0.paused }

        if allConnectedDevicesArePaused {
            return .paused
        }

        // Rule 6: Truly out of sync — folder at rest with non-trivial pending
        // work. Anything still in a healthy/transient state (scanning,
        // scan-waiting, etc.) is *not* counted as out-of-sync; only an idle
        // folder qualifies. Two qualifying conditions:
        //   a) remaining bytes exceed the user-configured threshold (the
        //      original 2026-04-28 rule for byte-pending desyncs);
        //   b) any pending deletes — covers the "stuck deletes" case where
        //      Syncthing refuses to remove a directory containing ignored
        //      files (.git, .build, etc.). `needDeletes > 0` produces zero
        //      remaining bytes but still leaves the folder out of sync, which
        //      is exactly what the WebUI shows.
        let trulyOutOfSync = client.folderStatuses.values.contains { status in
            guard status.state == "idle" else { return false }
            if status.needBytes > settings.syncRemainingBytesThreshold { return true }
            if status.needDeletes > 0 { return true }
            return false
        }
        if trulyOutOfSync {
            return .outOfSync
        }

        // Rule 7: Healthy, but worth a soft warning when the user has paused
        // remote devices configured. Folders shared with paused peers will
        // never converge until the peer is resumed — useful to surface in
        // traffic-light mode without crying wolf.
        let hasPausedConfiguredDevices = client.devices.contains { $0.paused }
        if hasPausedConfiguredDevices {
            return .warning(tooltip: "Some devices paused")
        }

        return .inSync
    }
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

extension SyncthingFolderStatus {
    /// True when the folder has any pending work — additions, deletes, or
    /// directory changes. Mirrors the WebUI's "Out of Sync" criterion. Falls
    /// back to a sum of the legacy fields when `needTotalItems` is absent.
    var hasPendingWork: Bool {
        needTotalItems > 0 || needFiles > 0 || needDeletes > 0 || needBytes > 0
    }

    /// Compact summary line for the popover row when work is pending.
    /// Examples: "5 files, 2 MB" / "10 deletes" / "3 files, 7 deletes, 1 MB".
    var pendingSummary: String {
        var parts: [String] = []
        if needFiles > 0 { parts.append("\(needFiles) file\(needFiles == 1 ? "" : "s")") }
        if needDeletes > 0 { parts.append("\(needDeletes) delete\(needDeletes == 1 ? "" : "s")") }
        if needBytes > 0 { parts.append(formatBytes(needBytes)) }
        return parts.joined(separator: ", ")
    }
}

@main struct ReviewHarness {
 @MainActor static func main() async throws {
 let settings = SyncthingSettings(); let resolver = StatusIconStateResolver(); let client = SyncthingClient()
 func check(_ label: String, json: String) throws {
  let status = try JSONDecoder().decode(SyncthingFolderStatus.self, from: Data(json.utf8))
  client.folderStatuses = ["fixture": status]
  print("\(label): rowPending=\(status.hasPendingWork), summary='\(status.pendingSummary)', icon=\(resolver.resolveState(client:client,settings:settings))")
 }
 try check("Pending small file",json:#"{"state":"idle","needFiles":1,"needBytes":512,"needTotalItems":1}"#)
 try check("Pending directory",json:#"{"state":"idle","needDirectories":1,"needTotalItems":1}"#)
 try check("Malformed empty response",json:"{}")
 client.folderStatuses = [:]
 print("Missing folder status: icon=\(resolver.resolveState(client:client,settings:settings))")
 let completion = SyncthingDeviceCompletion(completion: 95,globalBytes:1000000,needBytes:0,needDeletes:4)
 print("95 percent with four deletes: effectivelySynced=\(isEffectivelySynced(completion:completion,settings:settings))")
 let first = Task { await client.refresh() }
 while client.startedRequests == 0 { await Task.yield() }
 await client.refresh(); await first.value
 print("Two overlapping refreshes: started=\(client.startedRequests), completed=\(client.finishedRequests), refreshing=\(client.isRefreshing)")
 }
}
