import Foundation
import Combine
import UserNotifications

enum DemoScenario {
    case mixed        // Mixed syncing states (some idle, some syncing)
    case allSynced    // Everything 100% synced - perfect for screenshots
    case highSpeed    // High/varying transfer speeds to test layout stability
}

enum NotificationCategory: String {
    case folderPaused
    case folderResumed
    case devicePaused
    case deviceResumed
    case allDevicesPaused
    case allDevicesResumed
    case folderStalled
}

enum NotificationAction: String {
    case resumeFolder
    case pauseFolder
    case resumeDevice
    case pauseDevice
    case resumeAllDevices
    case pauseAllDevices
    case openApp
}

enum SyncthingClientError: LocalizedError {
    case httpStatus(code: Int, endpoint: String)
    case missingAPIKey
    case configAccessDenied
    case configMissingKey
    case configReadFailed(message: String)
    case configNotFound

    var errorDescription: String? {
        switch self {
        case .httpStatus(let code, let endpoint):
            switch code {
            case 401, 403:
                return "API key rejected (HTTP \(code)) when calling \(endpoint)."
            default:
                return "Syncthing returned HTTP \(code) for \(endpoint)."
            }
        case .missingAPIKey:
            return "API key is missing."
        case .configAccessDenied:
            return "Access to Syncthing config.xml was denied. Please reselect the file in Settings."
        case .configMissingKey:
            return "Syncthing config.xml did not contain an API key."
        case .configReadFailed(let message):
            return "Could not read Syncthing config.xml: \(message)"
        case .configNotFound:
            return "Select Syncthing's config.xml in Settings or enter the API key manually."
        }
    }
}

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
@MainActor
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
    private let maxEvents = AppConstants.UI.maxSyncEvents

    // Transfer history for charts
    private var transferHistory: [String: DeviceTransferHistory] = [:] // deviceID -> history
    private var totalTransferHistory = DeviceTransferHistory() // Aggregate for all devices
    @Published var isRefreshing = false

    // Task management for cancellation
    private var activeRefreshTask: Task<Void, Never>?
    
    private struct StalledSyncTracker {
        var syncStart: Date
        var lastProgress: Date
        var lastNeedBytes: Int64
        var lastNeedFiles: Int
        var lastNotificationDate: Date?
    }
    private var stalledSyncTrackers: [String: StalledSyncTracker] = [:]

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
    @Published var syncthingVersion: String?
    @Published var lastGlobalSyncNotificationSentAt: Date?

    // Demo mode - shows realistic preview data for screenshots and testing
    @Published var demoMode = false
    @Published var demoDeviceCount = 0
    @Published var demoFolderCount = 0
    @Published var demoScenario: DemoScenario = .mixed  // mixed syncing states or all synced
    private var realDevices: [SyncthingDevice] = []
    private var realFolders: [SyncthingFolder] = []
    private var realConnections: [String: SyncthingConnection] = [:]
    private var realFolderStatuses: [String: SyncthingFolderStatus] = [:]
    private var realTransferHistory: [String: DeviceTransferHistory] = [:]
    private var realTotalTransferHistory = DeviceTransferHistory()
    
    init(settings: SyncthingSettings, session: URLSession? = nil) {
        self.settings = settings

        // Configure URLSession with appropriate timeouts if not provided
        if let session = session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = AppConstants.Network.requestTimeoutSeconds
            config.timeoutIntervalForResource = AppConstants.Network.resourceTimeoutSeconds
            config.waitsForConnectivity = false       // Fail fast
            self.session = URLSession(configuration: config)
        }

        observeSettings()
    }

    deinit {
        activeRefreshTask?.cancel()
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
        .dropFirst()
        .debounce(for: .milliseconds(AppConstants.Debounce.settingsChangeDelayMs), scheduler: RunLoop.main)
        .sink { [weak self] useAuto, _, _ in
            guard let self else { return }
            if useAuto {
                self.cachedAutomaticAPIKey = nil
            }
            Task { @MainActor [weak self] in
                await self?.refresh()
            }
        }
        .store(in: &cancellables)

        settings.$configBookmarkData
            .dropFirst()
            .debounce(for: .milliseconds(AppConstants.Debounce.settingsChangeDelayMs), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.cachedAutomaticAPIKey = nil
                guard self.settings.useAutomaticDiscovery else { return }
                Task { @MainActor [weak self] in
                    await self?.refresh()
                }
            }
            .store(in: &cancellables)
    }
    
    private func extractAPIKey(from data: Data) -> String? {
        let parser = XMLParser(data: data)
        let delegate = ApiKeyParserDelegate()
        parser.delegate = delegate

        guard parser.parse(), let key = delegate.apiKey else { return nil }
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func defaultConfigLocations() -> [URL] {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        return [
            homeDir.appendingPathComponent("Library/Application Support/Syncthing/config.xml"),
            homeDir.appendingPathComponent(".config/syncthing/config.xml")
        ]
    }

    private func loadAutomaticAPIKey() -> Result<String, SyncthingClientError> {
        if let bookmarkData = settings.configBookmarkData {
            do {
                var stale = false
                let url = try URL(resolvingBookmarkData: bookmarkData, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &stale)

                if stale {
                    try? settings.updateConfigBookmark(with: url)
                }

                let hasAccess = url.startAccessingSecurityScopedResource()
                guard hasAccess else {
                    return .failure(.configAccessDenied)
                }
                defer {
                    url.stopAccessingSecurityScopedResource()
                }

                do {
                    let data = try Data(contentsOf: url)
                    if let key = extractAPIKey(from: data) {
                        return .success(key)
                    } else {
                        return .failure(.configMissingKey)
                    }
                } catch {
                    return .failure(.configReadFailed(message: error.localizedDescription))
                }
            } catch {
                return .failure(.configReadFailed(message: "Bookmark resolution failed: \(error.localizedDescription)"))
            }
        }

        for url in defaultConfigLocations() {
            if let data = try? Data(contentsOf: url), let key = extractAPIKey(from: data) {
                return .success(key)
            }
        }

        return .failure(.configNotFound)
    }
    
    private func prepareCredentials() -> Bool {
        let trimmedBase = settings.trimmedBaseURL
        guard let resolvedBaseURL = URL(string: trimmedBase), !trimmedBase.isEmpty else {
            self.lastErrorMessage = "Syncthing base URL is invalid or empty."
            return false
        }
        baseURL = resolvedBaseURL
        
        if settings.useAutomaticDiscovery {
            if cachedAutomaticAPIKey == nil {
                switch loadAutomaticAPIKey() {
                case .success(let key):
                    cachedAutomaticAPIKey = key
                case .failure(let error):
                    switch error {
                    case .configAccessDenied:
                        self.lastErrorMessage = "Access to Syncthing config.xml was denied. Please reselect the file in Settings."
                    case .configMissingKey:
                        self.lastErrorMessage = "Syncthing config.xml did not contain an API key."
                    case .configReadFailed(let message):
                        self.lastErrorMessage = "Could not read Syncthing config.xml: \(message)"
                    case .configNotFound:
                        self.lastErrorMessage = "Select Syncthing's config.xml in Settings or enter the API key manually."
                    default:
                        self.lastErrorMessage = error.localizedDescription
                    }
                    cachedAutomaticAPIKey = nil
                    return false
                }
            }
            guard let key = cachedAutomaticAPIKey else { return false }
            apiKey = key
        } else {
            guard let manualKey = settings.resolvedManualAPIKey?.trimmingCharacters(in: .whitespacesAndNewlines), !manualKey.isEmpty else {
                self.lastErrorMessage = "Manual API key is empty."
                return false
            }
            apiKey = manualKey
        }
        
        return true
    }
    
    /// Builds an endpoint URL that preserves any custom base path (e.g., reverse-proxy subpaths).
    private func endpointURL(path: String, queryItems: [URLQueryItem]? = nil) -> URL? {
        guard var url = baseURL else { return nil }
        url.appendPathComponent("rest")
        for segment in path.split(separator: "/") {
            url.appendPathComponent(String(segment))
        }
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else { return nil }
        components.queryItems = queryItems
        return components.url
    }
    
    private func makeRequest<T: Codable>(endpoint: String, responseType: T.Type) async throws -> T {
        guard let url = endpointURL(path: endpoint) else { throw URLError(.badURL) }
        guard let apiKey else { throw SyncthingClientError.missingAPIKey }
        #if DEBUG
        print("SyncthingClient: using API key length \(apiKey.count)")
        #endif

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard httpResponse.statusCode == 200 else {
            print("Syncthing request to \(endpoint) failed with HTTP \(httpResponse.statusCode)")
            throw SyncthingClientError.httpStatus(code: httpResponse.statusCode, endpoint: endpoint)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }

    /// Makes a GET request with properly URL-encoded query parameters
    private func makeRequest<T: Codable>(path: String, queryItems: [URLQueryItem], responseType: T.Type) async throws -> T {
        guard let url = endpointURL(path: path, queryItems: queryItems) else { throw URLError(.badURL) }
        guard let apiKey else { throw SyncthingClientError.missingAPIKey }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard httpResponse.statusCode == 200 else {
            print("Syncthing request to \(path) failed with HTTP \(httpResponse.statusCode)")
            throw SyncthingClientError.httpStatus(code: httpResponse.statusCode, endpoint: path)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }
    
    private func postRequest(endpoint: String) async throws {
        guard let url = endpointURL(path: endpoint) else { throw URLError(.badURL) }
        guard let apiKey else { throw SyncthingClientError.missingAPIKey }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue("0", forHTTPHeaderField: "Content-Length")

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        // Accept 200 OK, 201 Created, and 204 No Content as successful responses
        guard (200...204).contains(httpResponse.statusCode) else {
            print("Syncthing POST request to \(endpoint) failed with HTTP \(httpResponse.statusCode).")
            throw SyncthingClientError.httpStatus(code: httpResponse.statusCode, endpoint: endpoint)
        }
    }

    /// Makes a POST request with properly URL-encoded query parameters
    private func postRequest(path: String, queryItems: [URLQueryItem]) async throws {
        guard let url = endpointURL(path: path, queryItems: queryItems) else { throw URLError(.badURL) }
        guard let apiKey else { throw SyncthingClientError.missingAPIKey }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue("0", forHTTPHeaderField: "Content-Length")

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        // Accept 200 OK, 201 Created, and 204 No Content as successful responses
        guard (200...204).contains(httpResponse.statusCode) else {
            print("Syncthing POST request to \(path) failed with HTTP \(httpResponse.statusCode).")
            throw SyncthingClientError.httpStatus(code: httpResponse.statusCode, endpoint: path)
        }
    }

    private func makeRawRequest(endpoint: String) async throws -> Data {
        guard let url = endpointURL(path: endpoint) else { throw URLError(.badURL) }
        guard let apiKey else { throw SyncthingClientError.missingAPIKey }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw SyncthingClientError.httpStatus(code: code, endpoint: endpoint)
        }

        return data
    }

    private func postRawRequest(endpoint: String, body: Data) async throws {
        guard let url = endpointURL(path: endpoint) else { throw URLError(.badURL) }
        guard let apiKey else { throw SyncthingClientError.missingAPIKey }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            print("Syncthing raw POST request to \(endpoint) failed with HTTP \(code).")
            throw SyncthingClientError.httpStatus(code: code, endpoint: endpoint)
        }
    }
    
    func fetchStatus() async {
        do {
            let status = try await makeRequest(endpoint: "system/status", responseType: SyncthingSystemStatus.self)
            self.systemStatus = status
                self.isConnected = true
                self.lastErrorMessage = nil
        } catch {
            self.isConnected = false
            self.systemStatus = nil

            let message: String
            if let clientError = error as? SyncthingClientError {
                message = clientError.localizedDescription
            } else if let urlError = error as? URLError {
                switch urlError.code {
                case .userAuthenticationRequired:
                    message = "API key missing or invalid."
                case .cannotFindHost, .cannotConnectToHost:
                    message = "Could not reach Syncthing at \(settings.trimmedBaseURL)."
                default:
                    message = urlError.localizedDescription
                }
            } else {
                message = error.localizedDescription
            }

            self.lastErrorMessage = "Failed to connect to Syncthing: \(message)"
        }
    }
    
    func fetchVersion() async {
        do {
            let versionInfo = try await makeRequest(endpoint: "system/version", responseType: SyncthingVersion.self)
            self.syncthingVersion = versionInfo.version
        } catch {
            print("Failed to fetch system/version: \(error)")
            self.syncthingVersion = nil
        }
    }
    
    func fetchConfig(localDeviceID: String) async {
        do {
            let config = try await makeRequest(endpoint: "system/config", responseType: SyncthingConfig.self)
            
            if let localDevice = config.devices.first(where: { $0.deviceID == localDeviceID }) {
                self.localDeviceName = localDevice.name
            }
            let remoteDevices = config.devices.filter { $0.deviceID != localDeviceID }
            
            // Always cache the real data
            self.realDevices = remoteDevices
            self.realFolders = config.folders
            
            // Only update the published properties if not in debug mode
            if !demoMode {
                self.devices = remoteDevices
                self.folders = config.folders
            }
        } catch {
            // Skip cancelled errors - these are transient and happen during refresh
            let errorDescription = error.localizedDescription
            guard !errorDescription.contains("cancelled") else { return }

            let errorMessage = "Failed to fetch config: \(errorDescription)"
            print(errorMessage)
            // Only update UI-facing properties if not in demo mode
            if !demoMode {
                self.lastErrorMessage = errorMessage
                if let clientError = error as? SyncthingClientError, case .httpStatus(let code, _) = clientError {
                    if code == 401 || code == 403 {
                        self.isConnected = false
                    }
                }
            }
        }
    }
    
    func fetchConnections() async {
        do {
            let connectionsResponse = try await makeRequest(endpoint: "system/connections", responseType: SyncthingConnections.self)
            
            // Always cache the real data
            self.realConnections = connectionsResponse.connections
            
            // Only update the published properties if not in debug mode
            if !demoMode {
                self.updateConnectionHistory(newConnections: connectionsResponse.connections)
                self.calculateTransferRates(newConnections: connectionsResponse.connections)
                self.connections = connectionsResponse.connections
            }
        } catch {
            // Skip cancelled errors - these are transient and happen during refresh
            let errorDescription = error.localizedDescription
            guard !errorDescription.contains("cancelled") else { return }

            let errorMessage = "Failed to fetch connections: \(errorDescription)"
            print(errorMessage)
            if !demoMode {
                self.lastErrorMessage = errorMessage
                if let clientError = error as? SyncthingClientError, case .httpStatus(let code, _) = clientError {
                    if code == 401 || code == 403 {
                        self.isConnected = false
                    }
                }
            }
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
        var updatedRates: [String: TransferRates] = [:]

        for (deviceID, newConnection) in newConnections {
            guard let oldConnection = previousConnections[deviceID],
                  newConnection.connected else {
                updatedRates[deviceID] = TransferRates()
                continue
            }

            let bytesReceived = max(0, newConnection.inBytesTotal - oldConnection.inBytesTotal)
            let bytesSent = max(0, newConnection.outBytesTotal - oldConnection.outBytesTotal)

            let downloadRate = Double(bytesReceived) / timeDelta
            let uploadRate = Double(bytesSent) / timeDelta

            let rates = TransferRates(
                downloadRate: max(0, downloadRate),
                uploadRate: max(0, uploadRate)
            )
            updatedRates[deviceID] = rates

            // Accumulate totals
            totalDownload += rates.downloadRate
            totalUpload += rates.uploadRate

            // Store historical data for charts
            if transferHistory[deviceID] == nil {
                transferHistory[deviceID] = DeviceTransferHistory()
            }
            transferHistory[deviceID]?.addDataPoint(downloadRate: rates.downloadRate, uploadRate: rates.uploadRate)
        }

        // Store aggregate total history
        totalTransferHistory.addDataPoint(downloadRate: totalDownload, uploadRate: totalUpload)
        totalTransferHistory_published = totalTransferHistory

        // Share the single dictionary reference instead of duplicating
        transferRates = updatedRates
        deviceTransferHistory = transferHistory
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
                    previousConnections.removeValue(forKey: deviceID)
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
        let foldersToFetch = self.realFolders // Always fetch status for real folders
        for folder in foldersToFetch {
            do {
                let status = try await makeRequest(path: "db/status", queryItems: [URLQueryItem(name: "folder", value: folder.id)], responseType: SyncthingFolderStatus.self)
                self.realFolderStatuses[folder.id] = status // Update the cache
                
                if !demoMode {
                    self.folderStatuses[folder.id] = status
                    self.trackSyncEvent(folder: folder, status: status)
                }
            } catch {
                // Skip cancelled errors - these are transient and happen during refresh
                let errorDescription = error.localizedDescription
                guard !errorDescription.contains("cancelled") else { continue }

                let errorMessage = "Failed to fetch folder status for \(folder.id): \(errorDescription)"
                print(errorMessage)
                if !demoMode {
                    self.lastErrorMessage = errorMessage
                    if let clientError = error as? SyncthingClientError, case .httpStatus(let code, _) = clientError {
                        if code == 401 || code == 403 {
                            self.isConnected = false
                        }
                    }
                }
            }
        }
    }

    private func trackSyncEvent(folder: SyncthingFolder, status: SyncthingFolderStatus) {
        let effectivelyComplete = status.needBytes <= settings.syncRemainingBytesThreshold
        let effectiveState = (status.state == "idle" || effectivelyComplete) ? "idle" : status.state

        let previousState = previousFolderStates[folder.id]

        // Track state changes
        if previousState != effectiveState {
            let folderName = folder.label.isEmpty ? folder.id : folder.label
            let event: SyncEvent?

            switch (previousState, effectiveState) {
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
            case ("syncing", "idle") where effectivelyComplete:
                // Sync completed successfully
                let remainingDescription: String
                if status.needBytes > 0 {
                    remainingDescription = "Within threshold (\(formatBytes(status.needBytes)) remaining)"
                } else {
                    remainingDescription = "All files synchronized"
                }

                event = SyncEvent(
                    folderID: folder.id,
                    folderName: folderName,
                    eventType: .syncCompleted,
                    timestamp: Date(),
                    details: remainingDescription
                )
            case (_, "idle") where previousState == "syncing":
                // Back to idle (may have paused or error)
                let details: String?
                if status.needBytes > 0 {
                    details = "\(formatBytes(status.needBytes)) remaining"
                } else if status.needFiles > 0 {
                    details = "\(status.needFiles) files pending"
                } else {
                    details = nil
                }

                event = SyncEvent(
                    folderID: folder.id,
                    folderName: folderName,
                    eventType: .idle,
                    timestamp: Date(),
                    details: details
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
                let folderNotificationsEnabled = settings.notificationEnabledFolderIDs.isEmpty ||
                    settings.notificationEnabledFolderIDs.contains(folder.id)
                
                if event.eventType == .syncCompleted && settings.showSyncNotifications && folderNotificationsEnabled {
                    sendSyncCompletionNotification(folderName: folderName)
                }
            }

            previousFolderStates[folder.id] = effectiveState
        }
        
        monitorStalledSyncIfNeeded(for: folder, status: status)
    }
    
    private func monitorStalledSyncIfNeeded(for folder: SyncthingFolder, status: SyncthingFolderStatus) {
        guard settings.showStalledSyncNotifications else {
            stalledSyncTrackers.removeValue(forKey: folder.id)
            return
        }

        let now = Date()
        let thresholdSeconds = max(60.0, settings.stalledSyncTimeoutMinutes * 60.0)

        if status.state == "syncing" {
            var tracker = stalledSyncTrackers[folder.id] ?? StalledSyncTracker(
                syncStart: now,
                lastProgress: now,
                lastNeedBytes: status.needBytes,
                lastNeedFiles: status.needFiles,
                lastNotificationDate: nil
            )

            let needBytesChanged = status.needBytes != tracker.lastNeedBytes
            let needFilesChanged = status.needFiles != tracker.lastNeedFiles

            if needBytesChanged || needFilesChanged {
                tracker.lastProgress = now
                if status.needBytes < tracker.lastNeedBytes || status.needFiles < tracker.lastNeedFiles {
                    tracker.lastNotificationDate = nil
                }
            }

            tracker.lastNeedBytes = status.needBytes
            tracker.lastNeedFiles = status.needFiles

            if now.timeIntervalSince(tracker.lastProgress) >= thresholdSeconds {
                if tracker.lastNotificationDate == nil {
                    let folderName = folder.label.isEmpty ? folder.id : folder.label
                    sendStalledSyncNotification(folderID: folder.id, folderName: folderName, lastProgress: tracker.lastProgress)
                    tracker.lastNotificationDate = now
                }
            }

            stalledSyncTrackers[folder.id] = tracker
        } else {
            stalledSyncTrackers.removeValue(forKey: folder.id)
        }
    }

    private enum PauseResumeNotificationTarget {
        case folder(id: String, name: String)
        case device(id: String, name: String)
        case allDevices
    }

    private func sendPauseResumeNotification(target: PauseResumeNotificationTarget, paused: Bool) {
        guard settings.showPauseResumeNotifications else { return }

        let content = UNMutableNotificationContent()
        let title: String
        let body: String
        var categoryIdentifier: String = ""
        var userInfo: [String: Any] = ["paused": paused]

        switch target {
        case .folder(let id, let name):
            title = paused ? "Folder Paused" : "Folder Resumed"
            body = paused
                ? "Folder '\(name)' paused. Resume it from syncthingStatus when you're ready."
                : "Folder '\(name)' resumed. Syncthing will pick up syncing shortly."
            categoryIdentifier = paused ? NotificationCategory.folderPaused.rawValue : NotificationCategory.folderResumed.rawValue
            userInfo["target"] = "folder"
            userInfo["id"] = id
        case .device(let id, let name):
            title = paused ? "Device Paused" : "Device Resumed"
            body = paused
                ? "Device '\(name)' paused. Resume it from syncthingStatus to continue syncing."
                : "Device '\(name)' resumed. Syncing will continue if it is online."
            categoryIdentifier = paused ? NotificationCategory.devicePaused.rawValue : NotificationCategory.deviceResumed.rawValue
            userInfo["target"] = "device"
            userInfo["id"] = id
        case .allDevices:
            title = paused ? "All Devices Paused" : "All Devices Resumed"
            body = paused
                ? "All devices paused. Use syncthingStatus to resume when you're ready."
                : "All devices resumed. Syncthing will continue syncing."
            categoryIdentifier = paused ? NotificationCategory.allDevicesPaused.rawValue : NotificationCategory.allDevicesResumed.rawValue
            userInfo["target"] = "allDevices"
        }

        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = categoryIdentifier
        content.userInfo = userInfo

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to send pause/resume notification: \(error)")
            }
        }
    }

    private func sendStalledSyncNotification(folderID: String, folderName: String, lastProgress: Date) {
        let elapsedMinutes = max(1, Int(Date().timeIntervalSince(lastProgress) / 60))

        let content = UNMutableNotificationContent()
        content.title = "Sync Stalled"
        content.body = "Folder '\(folderName)' has not made progress for \(elapsedMinutes) minute\(elapsedMinutes == 1 ? "" : "s")."
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.folderStalled.rawValue
        content.userInfo = [
            "target": "folder",
            "id": folderID
        ]

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to send stalled sync notification: \(error)")
            }
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

    private func sendGlobalSyncNotification() {
        let content = UNMutableNotificationContent()
        content.title = "All Synced"
        content.body = "All folders are up to date."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to send global sync notification: \(error)")
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
        let devicesToFetch = self.realDevices // Always fetch for real devices
        for device in devicesToFetch {
            do {
                let completion = try await makeRequest(path: "db/completion", queryItems: [URLQueryItem(name: "device", value: device.deviceID)], responseType: SyncthingDeviceCompletion.self)
                // No separate cache for completions, as they are keyed by real device IDs.
                // We can just update the main dictionary.
                if !demoMode {
                    self.deviceCompletions[device.deviceID] = completion
                }
            } catch {
                // Skip cancelled errors - these are transient and happen during refresh
                let errorDescription = error.localizedDescription
                guard !errorDescription.contains("cancelled") else { continue }

                let errorMessage = "Failed to fetch device completion for \(device.deviceID): \(errorDescription)"
                print(errorMessage)
                if !demoMode {
                    self.lastErrorMessage = errorMessage
                    if let clientError = error as? SyncthingClientError, case .httpStatus(let code, _) = clientError {
                        if code == 401 || code == 403 {
                            self.isConnected = false
                        }
                    }
                }
            }
        }
    }
    
    @MainActor
    private func handleDisconnectedState() {
        isConnected = false
        if !demoMode {
            devices = []
            folders = []
            connections = [:]
            folderStatuses = [:]
        }
        systemStatus = nil
        deviceCompletions = [:]
    }
    
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
            print("Refresh already in progress.")
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

    // MARK: - Control Functions
    func pauseDevice(deviceID: String) async {
        do {
            try await postRequest(path: "system/pause", queryItems: [URLQueryItem(name: "device", value: deviceID)])
            let deviceName = devices.first { $0.deviceID == deviceID }?.name ?? deviceID
            sendPauseResumeNotification(target: .device(id: deviceID, name: deviceName), paused: true)
            await refresh()
        } catch {
            print("Failed to pause device \(deviceID): \(error)")
        }
    }

    func resumeDevice(deviceID: String) async {
        do {
            try await postRequest(path: "system/resume", queryItems: [URLQueryItem(name: "device", value: deviceID)])
            let deviceName = devices.first { $0.deviceID == deviceID }?.name ?? deviceID
            sendPauseResumeNotification(target: .device(id: deviceID, name: deviceName), paused: false)
            await refresh()
        } catch {
            print("Failed to resume device \(deviceID): \(error)")
        }
    }

    func rescanFolder(folderID: String) async {
        do {
            try await postRequest(path: "db/scan", queryItems: [URLQueryItem(name: "folder", value: folderID)])
            // No immediate refresh needed as scanning is a background task
        } catch {
            print("Failed to rescan folder \(folderID): \(error)")
        }
    }

    func pauseAllDevices() async {
        do {
            try await postRequest(endpoint: "system/pause")
            sendPauseResumeNotification(target: .allDevices, paused: true)
            await refresh()
        } catch {
            print("Failed to pause all devices: \(error)")
        }
    }

    func resumeAllDevices() async {
        do {
            try await postRequest(endpoint: "system/resume")
            sendPauseResumeNotification(target: .allDevices, paused: false)
            await refresh()
        } catch {
            print("Failed to resume all devices: \(error)")
        }
    }

    func handleGlobalSyncComplete() {
        guard settings.showSyncNotifications else { return }

        let now = Date()
        let minimumInterval = max(settings.refreshInterval, 5.0)

        if let lastNotification = lastGlobalSyncNotificationSentAt,
           now.timeIntervalSince(lastNotification) < minimumInterval {
            return
        }

        lastGlobalSyncNotificationSentAt = now
        sendGlobalSyncNotification()
    }

    private func setFolderPausedState(folderID: String, paused: Bool) async {
        do {
            // 1. Get the current config as raw JSON data
            let configData = try await makeRawRequest(endpoint: "system/config")

            // 2. Deserialize to a dictionary
            guard var configJSON = try JSONSerialization.jsonObject(with: configData, options: []) as? [String: Any] else {
                print("Failed to deserialize config JSON.")
                return
            }

            // 3. Find and modify the folder
            guard var folders = configJSON["folders"] as? [[String: Any]],
                  let folderIndex = folders.firstIndex(where: { ($0["id"] as? String) == folderID }) else {
                print("Folder with ID \(folderID) not found in config JSON.")
                return
            }
            folders[folderIndex]["paused"] = paused
            configJSON["folders"] = folders

            // 4. Serialize the modified dictionary back to data
            let modifiedConfigData = try JSONSerialization.data(withJSONObject: configJSON, options: [])

            // 5. Post the modified config back
            try await postRawRequest(endpoint: "system/config", body: modifiedConfigData)

            // Capture name for notification
            let folderName = self.folders.first { $0.id == folderID }?.label ?? folderID
            sendPauseResumeNotification(target: .folder(id: folderID, name: folderName), paused: paused)

            // 6. Update local state immediately
            if let localIndex = self.folders.firstIndex(where: { $0.id == folderID }) {
                    self.folders[localIndex].paused = paused
                }

            // 7. Poll for Syncthing availability with exponential backoff
            await waitForSyncthingAvailability()

        } catch {
            print("Failed to set folder paused state for \(folderID): \(error)")
        }
    }

    private func waitForSyncthingAvailability() async {
        var attempt = 0
        let maxAttempts = AppConstants.Polling.maxPollingAttempts
        var delay: UInt64 = AppConstants.Polling.initialPollingDelayMs

        while attempt < maxAttempts {
            do {
                // Try to fetch system version to check if Syncthing is responding
                guard let url = endpointURL(path: "system/version"), let apiKey = apiKey else {
                    break
                }

                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")

                let (_, response) = try await session.data(for: request)
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    // Syncthing is available, do a full refresh
                    await refresh()
                    return
                }
            } catch {
                // Syncthing not ready yet, continue polling
            }

            // Wait before next attempt with exponential backoff
            try? await Task.sleep(nanoseconds: delay)
            delay = min(delay * 2, AppConstants.Polling.maxPollingDelayMs)
            attempt += 1
        }

        // If we exhausted all attempts, do a refresh anyway
        await refresh()
    }

    func pauseFolder(folderID: String) async {
        await setFolderPausedState(folderID: folderID, paused: true)
    }

    func resumeFolder(folderID: String) async {
        await setFolderPausedState(folderID: folderID, paused: false)
    }

    // MARK: - Demo Mode
    func enableDemoMode(deviceCount: Int, folderCount: Int, scenario: DemoScenario = .mixed) {
        // If both counts are 0, disable demo mode entirely
        if deviceCount == 0 && folderCount == 0 {
            disableDemoMode()
            return
        }

        let shouldSaveReal = !demoMode

        // Generate dummy data FIRST (before touching any state)
        let (dummyDevices, dummyFolders, dummyConnections, dummyFolderStatuses, dummyTransferRates, dummyTransferHistory, dummyTotalHistory) =
            generateDummyData(deviceCount: deviceCount, folderCount: folderCount, scenario: scenario)

        // Now update ALL state atomically
        if shouldSaveReal {
            realDevices = devices
            realFolders = folders
            realConnections = connections
            realFolderStatuses = folderStatuses
            realTransferHistory = transferHistory
            realTotalTransferHistory = totalTransferHistory
        }

        // Update all state together to minimize race condition window
        demoMode = true
        demoDeviceCount = deviceCount
        demoFolderCount = folderCount
        demoScenario = scenario
        devices = dummyDevices
        folders = dummyFolders
        connections = dummyConnections
        folderStatuses = dummyFolderStatuses

        // Set demo transfer rates and aggregate transfer history for charts
        transferRates = dummyTransferRates
        transferHistory = dummyTransferHistory
        deviceTransferHistory = dummyTransferHistory
        totalTransferHistory = dummyTotalHistory
        totalTransferHistory_published = dummyTotalHistory

        // Clear other states
        deviceCompletions = [:]
        deviceHistory = [:]
        recentSyncEvents = []
    }

    private func generateDummyData(
        deviceCount: Int,
        folderCount: Int,
        scenario: DemoScenario
    ) -> (
        devices: [SyncthingDevice],
        folders: [SyncthingFolder],
        connections: [String: SyncthingConnection],
        statuses: [String: SyncthingFolderStatus],
        transferRates: [String: TransferRates],
        histories: [String: DeviceTransferHistory],
        totalHistory: DeviceTransferHistory
    ) {

        // Generate dummy devices
        var dummyDevices: [SyncthingDevice] = []
        var dummyConnections: [String: SyncthingConnection] = [:]

        let deviceNames = [
            "MacStudio-Main", "MBPro-16-Work", "MBPro-14-Travel",
            "LinuxWorkstation-Dev", "WinTower-Gaming", "Thinkpad-T14s-Lab",
            "MacMini-Media", "SurfacePro-Test", "XPS-15-Graphics",
            "HP-ZBook-Render", "iMac-ProStudio", "Dell-Precision-CAD",
            "RaspberryPi-NAS", "Mac-Pro-Studio", "Framework-Laptop"
        ]

        if deviceCount > 0 {
            for i in 1...deviceCount {
                let deviceID = "DUMMY\(i)-AAAA-BBBB-CCCC-DDDDEEEEFFFFGGGG"
                let connected = i % 3 != 0 // 2/3 connected, 1/3 disconnected
                let deviceName = deviceNames[(i - 1) % deviceNames.count]

                dummyDevices.append(SyncthingDevice(
                    deviceID: deviceID,
                    name: deviceName,
                    addresses: ["tcp://192.168.1.\(i):22000"],
                    paused: false
                ))

                if connected {
                    dummyConnections[deviceID] = SyncthingConnection(
                        connected: true,
                        address: "192.168.1.\(i):22000",
                        clientVersion: "v1.27.0",
                        type: "tcp",
                        inBytesTotal: Int64.random(in: 1_000_000...1_000_000_000),
                        outBytesTotal: Int64.random(in: 1_000_000...1_000_000_000)
                    )
                } else {
                    dummyConnections[deviceID] = SyncthingConnection(
                        connected: false,
                        address: nil,
                        clientVersion: nil,
                        type: nil,
                        inBytesTotal: 0,
                        outBytesTotal: 0
                    )
                }
            }
        }

        let historyPointCount = min(30, AppConstants.UI.maxTransferDataPoints)
        var dummyTransferRates: [String: TransferRates] = [:]
        var dummyHistories: [String: DeviceTransferHistory] = [:]

        for (index, device) in dummyDevices.enumerated() {
            guard dummyConnections[device.deviceID]?.connected == true else {
                dummyHistories[device.deviceID] = DeviceTransferHistory()
                dummyTransferRates[device.deviceID] = TransferRates()
                continue
            }

            var history = DeviceTransferHistory()
            for point in 0..<historyPointCount {
                let profile = deterministicTransferProfile(for: scenario, deviceIndex: index, pointIndex: point)
                history.addDataPoint(downloadRate: profile.download, uploadRate: profile.upload)
            }
            dummyHistories[device.deviceID] = history

            if let lastPoint = history.dataPoints.last {
                dummyTransferRates[device.deviceID] = TransferRates(
                    downloadRate: lastPoint.downloadRate,
                    uploadRate: lastPoint.uploadRate
                )
            } else {
                dummyTransferRates[device.deviceID] = TransferRates()
            }
        }

        var aggregateHistory = DeviceTransferHistory()
        let maxHistoryCount = dummyHistories.values.map { $0.dataPoints.count }.max() ?? 0
        for pointIndex in 0..<maxHistoryCount {
            var totalDownload: Double = 0
            var totalUpload: Double = 0
            for history in dummyHistories.values {
                if pointIndex < history.dataPoints.count {
                    totalDownload += history.dataPoints[pointIndex].downloadRate
                    totalUpload += history.dataPoints[pointIndex].uploadRate
                }
            }
            aggregateHistory.addDataPoint(downloadRate: totalDownload, uploadRate: totalUpload)
        }

        // Generate dummy folders
        var dummyFolders: [SyncthingFolder] = []
        var dummyFolderStatuses: [String: SyncthingFolderStatus] = [:]

        let folderNames = [
            "Documents", "Projects", "Source-Code", "Photos-2025",
            "Raw-Footage", "Video-Edits", "Music-Beds", "CAD-Files",
            "Backups", "Scripts-Python", "Reference-Docs", "Receipts",
            "Travel-Content", "Syncthing-Test", "Downloads", "Tax-Data"
        ]

        let folderPaths = [
            "/Users/Shared/Documents", "/Users/Work/Projects", "/Developer/Source-Code",
            "/Media/Photos/2025", "/Media/Video/Raw-Footage", "/Media/Video/Edits",
            "/Audio/Music-Beds", "/Engineering/CAD-Files", "/Backups/System",
            "/Developer/Scripts/Python", "/Documents/Reference", "/Finance/Receipts",
            "/Media/Travel-Content", "/Test/Syncthing", "/Users/Downloads", "/Finance/Tax-Data"
        ]

        if folderCount > 0 {
            for i in 1...folderCount {
                let folderName = folderNames[(i - 1) % folderNames.count]
                let folderID = folderName.lowercased().replacingOccurrences(of: "-", with: "")
                let folderPath = folderPaths[(i - 1) % folderPaths.count]

                // Determine state based on scenario
                let state: String
                if scenario == .allSynced {
                    state = "idle"  // All folders are idle/synced
                } else if scenario == .highSpeed {
                    state = "syncing"  // All folders actively syncing at high speed
                } else {
                    let states = ["idle", "syncing", "syncing"]
                    state = states[i % states.count]
                }

                dummyFolders.append(SyncthingFolder(
                    id: folderID,
                    label: folderName,
                    path: folderPath,
                    devices: [],
                    paused: false
                ))

                if state == "syncing" {
                    let globalBytes = Int64.random(in: 10_000_000...1_000_000_000)
                    let globalFiles = Int.random(in: 100...1000)
                    dummyFolderStatuses[folderID] = SyncthingFolderStatus(
                        globalFiles: globalFiles,
                        globalBytes: globalBytes,
                        localFiles: globalFiles,
                        localBytes: globalBytes,
                        needFiles: Int.random(in: 1...100),
                        needBytes: Int64.random(in: 1_000_000...100_000_000),
                        state: state,
                        lastScan: nil
                    )
                } else {
                    let globalBytes = Int64.random(in: 10_000_000...1_000_000_000)
                    let globalFiles = Int.random(in: 100...1000)
                    dummyFolderStatuses[folderID] = SyncthingFolderStatus(
                        globalFiles: globalFiles,
                        globalBytes: globalBytes,
                        localFiles: globalFiles,
                        localBytes: globalBytes,
                        needFiles: 0,
                        needBytes: 0,
                        state: state,
                        lastScan: nil
                    )
                }
            }
        }

        return (
            dummyDevices,
            dummyFolders,
            dummyConnections,
            dummyFolderStatuses,
            dummyTransferRates,
            dummyHistories,
            aggregateHistory
        )
    }

    private func deterministicTransferProfile(for scenario: DemoScenario, deviceIndex: Int, pointIndex: Int) -> (download: Double, upload: Double) {
        switch scenario {
        case .allSynced:
            return (0, 0)
        case .highSpeed:
            let multiplier = 1.0 + Double(deviceIndex % 4) * 0.15
            let basePhase = Double(deviceIndex % 5) * 0.6
            let download = wave(base: 250_000_000 * multiplier, amplitude: 150_000_000, point: pointIndex, phase: basePhase)
            let upload = wave(base: 120_000_000 * multiplier, amplitude: 80_000_000, point: pointIndex, phase: basePhase + .pi / 3)
            return (download, upload)
        case .mixed:
            let idle = (deviceIndex + pointIndex) % 9 == 0
            guard !idle else { return (0, 0) }
            let multiplier = 1.0 + Double(deviceIndex % 3) * 0.2
            let basePhase = Double((deviceIndex * 3) % 7) * 0.45
            let download = wave(base: 6_000_000 * multiplier, amplitude: 5_000_000, point: pointIndex, phase: basePhase)
            let upload = wave(base: 2_000_000 * multiplier, amplitude: 1_500_000, point: pointIndex, phase: basePhase + .pi / 2)
            return (download, upload)
        }
    }

    private func wave(base: Double, amplitude: Double, point: Int, phase: Double) -> Double {
        let angle = (Double(point) / 4.0) + phase
        return max(0, base + sin(angle) * amplitude)
    }

    func disableDemoMode() {
        guard demoMode else { return }
        demoMode = false
        demoDeviceCount = 0
        demoFolderCount = 0
        demoScenario = .mixed  // Reset to default

        // Restore real data from the cache
        devices = realDevices
        folders = realFolders
        connections = realConnections
        folderStatuses = realFolderStatuses
        transferHistory = realTransferHistory
        totalTransferHistory = realTotalTransferHistory
        totalTransferHistory_published = realTotalTransferHistory
        deviceTransferHistory = realTransferHistory

        // Clear any lingering demo state and trigger a refresh for other data
        deviceCompletions = [:]
        transferRates = [:]
        deviceHistory = [:]

        Task { await refresh() }
    }
}
