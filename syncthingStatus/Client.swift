import Foundation
import Combine
import UserNotifications

// MARK: - API Key XML Parser
class ApiKeyParserDelegate: NSObject, XMLParserDelegate {
    private var isApiKeyTag = false
    private var buffer = ""
    var apiKey: String?

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        if elementName == "apikey" {
            isApiKeyTag = true
            buffer = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard isApiKeyTag else { return }
        buffer.append(string)
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        guard elementName == "apikey", isApiKeyTag else { return }
        apiKey = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        isApiKeyTag = false
    }
}

// MARK: - Syncthing API Client
class SyncthingClient: ObservableObject {
    private let session: URLSession
    private let settings: SyncthingSettings
    private var baseURL: URL?
    private var apiKey: String?
    private var cachedAutomaticAPIKey: String?
    private var cancellables = Set<AnyCancellable>()

    // Transfer rate tracking
    private var previousConnections: [String: SyncthingConnection] = [:]
    private var lastUpdateTime: Date?

    // Connection history tracking
    private var connectionHistory: [String: ConnectionHistory] = [:]

    // Sync event tracking
    private var previousFolderStates: [String: String] = [:] // folderID -> state
    private var syncEvents: [SyncEvent] = []
    private let maxEvents = 50 // Keep last 50 events

    // Transfer history for charts
    private var transferHistory: [String: DeviceTransferHistory] = [:] // deviceID -> history
    private var totalTransferHistory = DeviceTransferHistory() // Aggregate for all devices
    @Published var isRefreshing = false

    @Published var isConnected = false
    @Published var devices: [SyncthingDevice] = []
    @Published var folders: [SyncthingFolder] = []
    @Published var connections: [String: SyncthingConnection] = [:]
    @Published var folderStatuses: [String: SyncthingFolderStatus] = [:]
    @Published var systemStatus: SyncthingSystemStatus?
    @Published var deviceCompletions: [String: SyncthingDeviceCompletion] = [:]
    @Published var transferRates: [String: TransferRates] = [:]
    @Published var deviceHistory: [String: ConnectionHistory] = [:]
    @Published var recentSyncEvents: [SyncEvent] = []
    @Published var deviceTransferHistory: [String: DeviceTransferHistory] = [:]
    @Published var totalTransferHistory_published = DeviceTransferHistory()
    @Published var localDeviceName: String = ""
    @Published var lastErrorMessage: String?
    
    init(settings: SyncthingSettings, session: URLSession = .shared) {
        self.settings = settings
        self.session = session
        observeSettings()
    }

    // MARK: - Computed Statistics
    var totalSyncedData: Int64 {
        folderStatuses.values.reduce(0) { $0 + $1.localBytes }
    }

    var totalGlobalData: Int64 {
        folderStatuses.values.reduce(0) { $0 + $1.globalBytes }
    }

    var totalDevicesConnected: Int {
        connections.values.filter { $0.connected }.count
    }

    var totalDataReceived: Int64 {
        connections.values.reduce(0) { $0 + $1.inBytesTotal }
    }

    var totalDataSent: Int64 {
        connections.values.reduce(0) { $0 + $1.outBytesTotal }
    }

    var currentDownloadSpeed: Double {
        transferRates.values.reduce(0) { $0 + $1.downloadRate }
    }

    var currentUploadSpeed: Double {
        transferRates.values.reduce(0) { $0 + $1.uploadRate }
    }

    var allDevicesPaused: Bool {
        !devices.isEmpty && devices.allSatisfy { $0.paused }
    }

    private func observeSettings() {
        Publishers.CombineLatest3(
            settings.$useAutomaticDiscovery,
            settings.$baseURLString,
            settings.$manualAPIKey
        )
        .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
        .sink { [weak self] useAuto, _, _ in
            guard let self else { return }
            if useAuto {
                self.cachedAutomaticAPIKey = nil
            }
            Task { await self.refresh() }
        }
        .store(in: &cancellables)
    }
    
    private func loadAutomaticAPIKey() -> String? {
        let fileManager = FileManager.default
        let homeDir = fileManager.homeDirectoryForCurrentUser
        let standardConfigPath = homeDir.appendingPathComponent("Library/Application Support/Syncthing/config.xml")
        let alternativeConfigPath = homeDir.appendingPathComponent(".config/syncthing/config.xml")
        
        let configPath: URL?
        if fileManager.fileExists(atPath: standardConfigPath.path) {
            configPath = standardConfigPath
        } else if fileManager.fileExists(atPath: alternativeConfigPath.path) {
            configPath = alternativeConfigPath
        } else {
            configPath = nil
        }
        
        guard let finalPath = configPath else { return nil }
        guard let xmlData = try? Data(contentsOf: finalPath) else { return nil }
        
        let parser = XMLParser(data: xmlData)
        let delegate = ApiKeyParserDelegate()
        parser.delegate = delegate
        
        guard parser.parse(), let key = delegate.apiKey else { return nil }
        return key.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func prepareCredentials() -> Bool {
        let trimmedBase = settings.trimmedBaseURL
        guard let resolvedBaseURL = URL(string: trimmedBase), !trimmedBase.isEmpty else {
            Task { await MainActor.run { self.lastErrorMessage = "Syncthing base URL is invalid or empty." } }
            return false
        }
        baseURL = resolvedBaseURL
        
        if settings.useAutomaticDiscovery {
            if cachedAutomaticAPIKey == nil {
                cachedAutomaticAPIKey = loadAutomaticAPIKey()
                if cachedAutomaticAPIKey == nil {
                    Task { await MainActor.run { self.lastErrorMessage = "API key could not be loaded from config.xml." } }
                }
            }
            guard let key = cachedAutomaticAPIKey else { return false }
            apiKey = key
        } else {
            guard let manualKey = settings.resolvedManualAPIKey?.trimmingCharacters(in: .whitespacesAndNewlines), !manualKey.isEmpty else {
                Task { await MainActor.run { self.lastErrorMessage = "Manual API key is empty." } }
                return false
            }
            apiKey = manualKey
        }
        
        return true
    }
    
    private func endpointURL(for endpoint: String) -> URL? {
        guard let baseURL else { return nil }
        return URL(string: "rest/\(endpoint)", relativeTo: baseURL)
    }
    
    private func makeRequest<T: Codable>(endpoint: String, responseType: T.Type) async throws -> T {
        guard let url = endpointURL(for: endpoint) else { throw URLError(.badURL) }
        guard let apiKey else { throw URLError(.userAuthenticationRequired) }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard httpResponse.statusCode == 200 else {
            print("Syncthing request to \(endpoint) failed with HTTP \(httpResponse.statusCode)")
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }
    
    private func postRequest(endpoint: String) async throws {
        guard let url = endpointURL(for: endpoint) else { throw URLError(.badURL) }
        guard let apiKey else { throw URLError(.userAuthenticationRequired) }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue("0", forHTTPHeaderField: "Content-Length")
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            print("Syncthing POST request to \(endpoint) failed.")
            throw URLError(.badServerResponse)
        }
    }
    
    func fetchStatus() async {
        do {
            let status = try await makeRequest(endpoint: "system/status", responseType: SyncthingSystemStatus.self)
            await MainActor.run {
                self.systemStatus = status
                self.isConnected = true
                self.lastErrorMessage = nil
            }
        } catch {
            await MainActor.run {
                self.isConnected = false
                self.systemStatus = nil
                self.lastErrorMessage = "Failed to connect to Syncthing: \(error.localizedDescription)"
            }
        }
    }
    
    func fetchConfig() async {
        guard let localDeviceID = await MainActor.run(body: { self.systemStatus?.myID }) else { return }
        do {
            let config = try await makeRequest(endpoint: "system/config", responseType: SyncthingConfig.self)
            await MainActor.run {
                // Find and store local device name
                if let localDevice = config.devices.first(where: { $0.deviceID == localDeviceID }) {
                    self.localDeviceName = localDevice.name
                }
                // Store only remote devices
                self.devices = config.devices.filter { $0.deviceID != localDeviceID }
                self.folders = config.folders
            }
        } catch {
            print("Failed to fetch system/config: \(error)")
        }
    }
    
    func fetchConnections() async {
        do {
            let connectionsResponse = try await makeRequest(endpoint: "system/connections", responseType: SyncthingConnections.self)
            await MainActor.run {
                self.calculateTransferRates(newConnections: connectionsResponse.connections)
                self.updateConnectionHistory(newConnections: connectionsResponse.connections)
                self.connections = connectionsResponse.connections
            }
        } catch {
            print("Failed to fetch system/connections: \(error)")
        }
    }

    private func calculateTransferRates(newConnections: [String: SyncthingConnection]) {
        let currentTime = Date()
        defer {
            previousConnections = newConnections
            lastUpdateTime = currentTime
        }

        guard let lastTime = lastUpdateTime else { return }

        let timeDelta = currentTime.timeIntervalSince(lastTime)
        guard timeDelta > 0 else { return }

        var totalDownload: Double = 0
        var totalUpload: Double = 0

        for (deviceID, newConnection) in newConnections {
            guard let oldConnection = previousConnections[deviceID],
                  newConnection.connected else {
                transferRates[deviceID] = TransferRates()
                continue
            }

            let bytesReceived = newConnection.inBytesTotal - oldConnection.inBytesTotal
            let bytesSent = newConnection.outBytesTotal - oldConnection.outBytesTotal

            let downloadRate = Double(bytesReceived) / timeDelta
            let uploadRate = Double(bytesSent) / timeDelta

            let rates = TransferRates(
                downloadRate: max(0, downloadRate),
                uploadRate: max(0, uploadRate)
            )
            transferRates[deviceID] = rates

            // Accumulate totals
            totalDownload += rates.downloadRate
            totalUpload += rates.uploadRate

            // Store historical data for charts
            var history = transferHistory[deviceID] ?? DeviceTransferHistory()
            history.addDataPoint(downloadRate: rates.downloadRate, uploadRate: rates.uploadRate)
            transferHistory[deviceID] = history
            deviceTransferHistory[deviceID] = history
        }

        // Store aggregate total history
        totalTransferHistory.addDataPoint(downloadRate: totalDownload, uploadRate: totalUpload)
        totalTransferHistory_published = totalTransferHistory
    }

    private func updateConnectionHistory(newConnections: [String: SyncthingConnection]) {
        let currentTime = Date()

        for (deviceID, newConnection) in newConnections {
            var history = connectionHistory[deviceID] ?? ConnectionHistory()
            let deviceName = devices.first { $0.deviceID == deviceID }?.name ?? deviceID

            if newConnection.connected {
                // Device is connected
                if !history.isCurrentlyConnected {
                    // Device just connected
                    history.connectedSince = currentTime
                    if settings.showDeviceConnectNotifications {
                        sendConnectionNotification(deviceName: deviceName, connected: true)
                    }
                }
                history.lastSeen = currentTime
                history.isCurrentlyConnected = true
            } else {
                // Device is disconnected
                if history.isCurrentlyConnected {
                    // Device just disconnected
                    history.lastSeen = currentTime
                    if settings.showDeviceDisconnectNotifications {
                        sendConnectionNotification(deviceName: deviceName, connected: false)
                    }
                }
                history.connectedSince = nil
                history.isCurrentlyConnected = false
            }

            connectionHistory[deviceID] = history
            deviceHistory[deviceID] = history
        }
    }

    func fetchFolderStatus() async {
        let foldersToFetch = await MainActor.run { self.folders }
        for folder in foldersToFetch {
            do {
                let status = try await makeRequest(endpoint: "db/status?folder=\(folder.id)", responseType: SyncthingFolderStatus.self)
                await MainActor.run {
                    self.trackSyncEvent(folder: folder, status: status)
                    self.folderStatuses[folder.id] = status
                }
            } catch {
                print("Failed to fetch db/status for folder \(folder.id): \(error)")
            }
        }
    }

    private func trackSyncEvent(folder: SyncthingFolder, status: SyncthingFolderStatus) {
        let currentState = status.state
        let previousState = previousFolderStates[folder.id]

        // Track state changes
        if previousState != currentState {
            let folderName = folder.label.isEmpty ? folder.id : folder.label
            let event: SyncEvent?

            switch (previousState, currentState) {
            case (_, "syncing") where previousState != "syncing":
                // Sync started
                let details = status.needFiles > 0 ? "\(status.needFiles) files to sync" : nil
                event = SyncEvent(
                    folderID: folder.id,
                    folderName: folderName,
                    eventType: .syncStarted,
                    timestamp: Date(),
                    details: details
                )
            case ("syncing", "idle") where status.needFiles == 0:
                // Sync completed successfully
                event = SyncEvent(
                    folderID: folder.id,
                    folderName: folderName,
                    eventType: .syncCompleted,
                    timestamp: Date(),
                    details: "All files synchronized"
                )
            case (_, "idle") where previousState == "syncing":
                // Back to idle (may have paused or error)
                event = SyncEvent(
                    folderID: folder.id,
                    folderName: folderName,
                    eventType: .idle,
                    timestamp: Date(),
                    details: status.needFiles > 0 ? "\(status.needFiles) files pending" : nil
                )
            default:
                event = nil
            }

            if let event = event {
                syncEvents.append(event)
                // Keep only the most recent events
                if syncEvents.count > maxEvents {
                    syncEvents.removeFirst(syncEvents.count - maxEvents)
                }
                recentSyncEvents = syncEvents.reversed()

                // Send notification for sync completion
                if event.eventType == .syncCompleted && settings.notificationEnabledFolderIDs.contains(folder.id) {
                    sendSyncCompletionNotification(folderName: folderName)
                }
            }

            previousFolderStates[folder.id] = currentState
        }
    }

    private func sendSyncCompletionNotification(folderName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Sync Complete"
        content.body = "Folder '\(folderName)' is now up to date"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Deliver immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to send notification: \(error)")
            }
        }
    }
    
    private func sendConnectionNotification(deviceName: String, connected: Bool) {
        let content = UNMutableNotificationContent()
        content.title = connected ? "Device Connected" : "Device Disconnected"
        content.body = "Device '\(deviceName)' is now \(connected ? "online" : "offline")."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to send connection notification: \(error)")
            }
        }
    }
    
    func fetchDeviceCompletions() async {
        let devicesToFetch = await MainActor.run { self.devices }
        for device in devicesToFetch {
            do {
                let completion = try await makeRequest(endpoint: "db/completion?device=\(device.deviceID)", responseType: SyncthingDeviceCompletion.self)
                await MainActor.run { self.deviceCompletions[device.deviceID] = completion }
            } catch {
                print("Failed to fetch db/completion for device \(device.deviceID): \(error)")
            }
        }
    }
    
    @MainActor
    private func handleDisconnectedState() {
        isConnected = false
        devices = []
        folders = []
        connections = [:]
        folderStatuses = [:]
        systemStatus = nil
        deviceCompletions = [:]
    }
    
    func refresh() async {
        guard !isRefreshing else {
            print("Refresh already in progress.")
            return
        }
        await MainActor.run { isRefreshing = true }
        defer { Task { await MainActor.run { isRefreshing = false } } }

        guard prepareCredentials() else {
            await MainActor.run { self.handleDisconnectedState() }
            return
        }
        
        await fetchStatus()
        
        if await MainActor.run(body: { self.isConnected }) {
            await fetchConfig()
            
            async let connectionsTask: () = fetchConnections()
            async let folderStatusTask: () = fetchFolderStatus()
            async let deviceCompletionTask: () = fetchDeviceCompletions()
            
            _ = await [connectionsTask, folderStatusTask, deviceCompletionTask]
        }
    }

    // MARK: - Control Functions
    func pauseDevice(deviceID: String) async {
        do {
            try await postRequest(endpoint: "system/pause?device=\(deviceID)")
            await refresh()
        } catch {
            print("Failed to pause device \(deviceID): \(error)")
        }
    }

    func resumeDevice(deviceID: String) async {
        do {
            try await postRequest(endpoint: "system/resume?device=\(deviceID)")
            await refresh()
        } catch {
            print("Failed to resume device \(deviceID): \(error)")
        }
    }

    func rescanFolder(folderID: String) async {
        do {
            try await postRequest(endpoint: "db/scan?folder=\(folderID)")
            // No immediate refresh needed as scanning is a background task
        } catch {
            print("Failed to rescan folder \(folderID): \(error)")
        }
    }

    func pauseAllDevices() async {
        do {
            try await postRequest(endpoint: "system/pause")
            await refresh()
        } catch {
            print("Failed to pause all devices: \(error)")
        }
    }

    func resumeAllDevices() async {
        do {
            try await postRequest(endpoint: "system/resume")
            await refresh()
        } catch {
            print("Failed to resume all devices: \(error)")
        }
    }

    func pauseFolder(folderID: String) async {
        do {
            try await postRequest(endpoint: "db/override?folder=\(folderID)&paused=true")
            await refresh()
        } catch {
            print("Failed to pause folder \(folderID): \(error)")
        }
    }

    func resumeFolder(folderID: String) async {
        do {
            try await postRequest(endpoint: "db/override?folder=\(folderID)&paused=false")
            await refresh()
        } catch {
            print("Failed to resume folder \(folderID): \(error)")
        }
    }
}