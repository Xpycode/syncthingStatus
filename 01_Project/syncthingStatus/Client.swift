import Foundation
import Combine
import UserNotifications
import OSLog

private let folderStatusLog = Logger(subsystem: "com.lucesumbrarum.syncthingStatus", category: "FolderStatus")
private let stuckDeletesLog = Logger(subsystem: "com.lucesumbrarum.syncthingStatus", category: "StuckDeletes")
private let networkLog = Logger(subsystem: "com.lucesumbrarum.syncthingStatus", category: "Network")
private let notificationsLog = Logger(subsystem: "com.lucesumbrarum.syncthingStatus", category: "Notifications")
private let configLog = Logger(subsystem: "com.lucesumbrarum.syncthingStatus", category: "Config")

/// True for task/URL-session cancellations. Checked by type and code, never by
/// matching `localizedDescription` substrings — those are locale-dependent and
/// silently stop matching on non-English systems.
func isCancellationError(_ error: Error) -> Bool {
    if error is CancellationError { return true }
    if (error as? URLError)?.code == .cancelled { return true }
    return false
}

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
    private var lastSyncNotificationDates: [String: Date] = [:] // folderID -> last sent
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

    /// Per-folder stuck-delete count. Populated when an idle folder has
    /// `needDeletes > 0` and no other pending work, sustained past the debounce
    /// window. Empty otherwise. Drives the popover alert row in Phase 2.
    @Published var stuckDeleteCounts: [String: Int] = [:]
    /// First-seen timestamp per folder for the stuck-delete debounce. Cleared
    /// when the fingerprint disappears.
    private var firstSeenStuckAt: [String: Date] = [:]
    /// Tracks the last announced state per folder so we only log on transitions.
    private var lastLoggedStuckState: [String: Bool] = [:]

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
                    do {
                        try settings.updateConfigBookmark(with: url)
                    } catch {
                        configLog.error("Failed to refresh stale config.xml bookmark: \(error.localizedDescription, privacy: .public)")
                    }
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
    
    private func makeRequest<T: Decodable>(endpoint: String, responseType: T.Type) async throws -> T {
        guard let url = endpointURL(path: endpoint) else { throw URLError(.badURL) }
        guard let apiKey else { throw SyncthingClientError.missingAPIKey }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard httpResponse.statusCode == 200 else {
            networkLog.error("GET \(endpoint, privacy: .public) failed with HTTP \(httpResponse.statusCode, privacy: .public)")
            throw SyncthingClientError.httpStatus(code: httpResponse.statusCode, endpoint: endpoint)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }

    /// Makes a GET request with properly URL-encoded query parameters
    private func makeRequest<T: Decodable>(path: String, queryItems: [URLQueryItem], responseType: T.Type) async throws -> T {
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
            networkLog.error("GET \(path, privacy: .public) failed with HTTP \(httpResponse.statusCode, privacy: .public)")
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
            networkLog.error("POST \(endpoint, privacy: .public) failed with HTTP \(httpResponse.statusCode, privacy: .public)")
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
            networkLog.error("POST \(path, privacy: .public) failed with HTTP \(httpResponse.statusCode, privacy: .public)")
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
            networkLog.error("Raw POST \(endpoint, privacy: .public) failed with HTTP \(code, privacy: .public)")
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
            // A cancelled refresh is not a lost connection — a newer refresh
            // superseded this one. Mutating state here would flash a false
            // "Disconnected" icon between the cancel and the fresh result.
            guard !isCancellationError(error) else { return }

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
            networkLog.error("Failed to fetch system/version: \(error.localizedDescription, privacy: .public)")
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

                // Prune cached status for folders/devices no longer in config.
                // Without this, removing a folder or device would leave its
                // last-known status forever and could keep the resolver in a
                // wrong state.
                let validFolderIDs = Set(config.folders.map { $0.id })
                self.folderStatuses = self.folderStatuses.filter { validFolderIDs.contains($0.key) }
                let validDeviceIDs = Set(remoteDevices.map { $0.deviceID })
                self.deviceCompletions = self.deviceCompletions.filter { validDeviceIDs.contains($0.key) }
            }
        } catch {
            // Skip cancelled errors - these are transient and happen during refresh
            guard !isCancellationError(error) else { return }

            let errorMessage = "Failed to fetch config: \(error.localizedDescription)"
            networkLog.error("\(errorMessage, privacy: .public)")
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
            guard !isCancellationError(error) else { return }

            let errorMessage = "Failed to fetch connections: \(error.localizedDescription)"
            networkLog.error("\(errorMessage, privacy: .public)")
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
                guard !isCancellationError(error) else { continue }

                let errorMessage = "Failed to fetch folder status for \(folder.id): \(error.localizedDescription)"
                folderStatusLog.error("\(errorMessage, privacy: .public)")
                if !demoMode {
                    self.lastErrorMessage = errorMessage
                    if let clientError = error as? SyncthingClientError, case .httpStatus(let code, _) = clientError {
                        if code == 401 || code == 403 {
                            self.isConnected = false
                        }
                    }
                    // Drop any cached status for this folder so a stale value
                    // (e.g. a transient "scanning" captured on an earlier
                    // refresh) cannot persist and force a false-red icon.
                    self.folderStatuses.removeValue(forKey: folder.id)
                }
            }
        }

        if !demoMode {
            updateStuckDeletesSignal()
        }
    }

    /// Computes the per-folder stuck-delete count and publishes it to
    /// `stuckDeleteCounts`. See Syncthing issue #7046 and
    /// `FEATURE-stuck-deletes-cleanup.md` for the full rationale.
    ///
    /// Two-stage state machine to avoid flapping during periodic rescans:
    /// - **Entry (debounced):** `state == idle && needDeletes > 0 && no other
    ///   pending work`, sustained for `stuckDeletesDebounceSeconds`. The idle
    ///   requirement keeps us from latching during a startup scan.
    /// - **Persist (latched):** once detected, stay detected as long as
    ///   `needDeletes > 0 && needFiles == 0 && needBytes == 0`. Transient state
    ///   churn (scanning / sync-waiting) without progress keeps the latch.
    /// - **Clear:** `needDeletes` drops to 0, real sync work appears, the
    ///   folder pauses, or the alert toggle flips off.
    ///
    /// Paused folders are excluded from both stages.
    private func updateStuckDeletesSignal() {
        guard settings.stuckDeletesAlertsEnabled else {
            if !stuckDeleteCounts.isEmpty {
                stuckDeleteCounts = [:]
                firstSeenStuckAt.removeAll()
                lastLoggedStuckState.removeAll()
            }
            return
        }

        let now = Date()
        var newCounts: [String: Int] = [:]
        let debounce = AppConstants.Sync.stuckDeletesDebounceSeconds

        for folder in folders where !folder.paused {
            guard let s = folderStatuses[folder.id] else {
                firstSeenStuckAt.removeValue(forKey: folder.id)
                continue
            }

            // Items are stuck-eligible whenever needDeletes is outstanding and
            // no real sync work is in flight. State (idle vs scanning vs
            // sync-waiting) is intentionally NOT in this check — rescan
            // transitions don't make the items un-stuck.
            let isStuckEligible =
                s.needDeletes > 0 &&
                s.needFiles == 0 &&
                s.needBytes == 0

            // For initial detection we additionally require state == idle so
            // the entry debounce only ticks during quiet windows.
            let isIdleStable = isStuckEligible && s.state == "idle"

            let alreadyDetected = lastLoggedStuckState[folder.id] == true

            if alreadyDetected, isStuckEligible {
                // Latched: keep the alert alive through state churn.
                newCounts[folder.id] = s.needDeletes
            } else if isIdleStable {
                // Entry debounce: tick only when idle.
                let firstSeen = firstSeenStuckAt[folder.id] ?? now
                if firstSeenStuckAt[folder.id] == nil { firstSeenStuckAt[folder.id] = now }
                if now.timeIntervalSince(firstSeen) >= debounce {
                    newCounts[folder.id] = s.needDeletes
                }
            } else {
                // Real work in flight, needDeletes resolved, or transient
                // pre-detection state — reset the entry debounce.
                firstSeenStuckAt.removeValue(forKey: folder.id)
            }
        }

        // Log only on actual transitions. Gate on the prior boolean so
        // "cleared" doesn't re-fire on every subsequent poll.
        for (folderID, count) in newCounts where lastLoggedStuckState[folderID] != true {
            stuckDeletesLog.notice("Stuck deletes detected on folder \(folderID, privacy: .public): \(count) item(s)")
            lastLoggedStuckState[folderID] = true
        }
        for (folderID, wasDetected) in lastLoggedStuckState
            where wasDetected && newCounts[folderID] == nil {
            stuckDeletesLog.notice("Stuck deletes cleared on folder \(folderID, privacy: .public)")
            lastLoggedStuckState[folderID] = false
        }

        stuckDeleteCounts = newCounts
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
                    // Per-folder cooldown: skip if we sent a sync-complete
                    // notification for this folder within the user-configured
                    // window. Avoids spam when a folder churns through many
                    // small syncs in quick succession.
                    let cooldown = max(0, settings.syncNotificationCooldownMinutes) * 60.0
                    let now = Date()
                    let lastSent = lastSyncNotificationDates[folder.id]
                    let withinCooldown = lastSent.map { now.timeIntervalSince($0) < cooldown } ?? false
                    if !withinCooldown {
                        lastSyncNotificationDates[folder.id] = now
                        sendSyncCompletionNotification(folderName: folderName)
                    }
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
                notificationsLog.error("Failed to send pause/resume notification: \(error.localizedDescription, privacy: .public)")
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
                notificationsLog.error("Failed to send stalled sync notification: \(error.localizedDescription, privacy: .public)")
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
                notificationsLog.error("Failed to send sync-completion notification: \(error.localizedDescription, privacy: .public)")
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
                notificationsLog.error("Failed to send global sync notification: \(error.localizedDescription, privacy: .public)")
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
                notificationsLog.error("Failed to send connection notification: \(error.localizedDescription, privacy: .public)")
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
                guard !isCancellationError(error) else { continue }

                let errorMessage = "Failed to fetch device completion for \(device.deviceID): \(error.localizedDescription)"
                networkLog.error("\(errorMessage, privacy: .public)")
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
        stuckDeleteCounts = [:]
        firstSeenStuckAt.removeAll()
        lastLoggedStuckState.removeAll()
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

    // MARK: - Control Functions
    func pauseDevice(deviceID: String) async {
        do {
            try await postRequest(path: "system/pause", queryItems: [URLQueryItem(name: "device", value: deviceID)])
            let deviceName = devices.first { $0.deviceID == deviceID }?.name ?? deviceID
            sendPauseResumeNotification(target: .device(id: deviceID, name: deviceName), paused: true)
            await refresh()
        } catch {
            networkLog.error("Failed to pause device \(deviceID, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    func resumeDevice(deviceID: String) async {
        do {
            try await postRequest(path: "system/resume", queryItems: [URLQueryItem(name: "device", value: deviceID)])
            let deviceName = devices.first { $0.deviceID == deviceID }?.name ?? deviceID
            sendPauseResumeNotification(target: .device(id: deviceID, name: deviceName), paused: false)
            await refresh()
        } catch {
            networkLog.error("Failed to resume device \(deviceID, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Fetches the items the local node still needs to process for a folder.
    /// Used by the stuck-deletes window to enumerate which directories
    /// Syncthing wants gone but can't remove. **Not** called from the poll loop:
    /// the Syncthing docs explicitly warn this endpoint is expensive
    /// ("increasing CPU and RAM usage on the device. Use sparingly.").
    func fetchDbNeed(folder: String) async throws -> DbNeedResponse {
        return try await makeRequest(
            path: "db/need",
            queryItems: [
                URLQueryItem(name: "folder", value: folder),
                URLQueryItem(name: "perpage", value: "1000")
            ],
            responseType: DbNeedResponse.self
        )
    }

    /// Triggers a full rescan of a folder via `POST /rest/db/scan?folder=X`.
    /// Used by the stuck-deletes window to nudge Syncthing to reconcile after
    /// the user manually clears the offending directories.
    func rescan(folder: String) async throws {
        try await postRequest(
            path: "db/scan",
            queryItems: [URLQueryItem(name: "folder", value: folder)]
        )
    }

    func rescanFolder(folderID: String) async {
        do {
            try await postRequest(path: "db/scan", queryItems: [URLQueryItem(name: "folder", value: folderID)])
            // No immediate refresh needed as scanning is a background task
        } catch {
            folderStatusLog.error("Failed to rescan folder \(folderID, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    func pauseAllDevices() async {
        do {
            try await postRequest(endpoint: "system/pause")
            sendPauseResumeNotification(target: .allDevices, paused: true)
            await refresh()
        } catch {
            networkLog.error("Failed to pause all devices: \(error.localizedDescription, privacy: .public)")
        }
    }

    func resumeAllDevices() async {
        do {
            try await postRequest(endpoint: "system/resume")
            sendPauseResumeNotification(target: .allDevices, paused: false)
            await refresh()
        } catch {
            networkLog.error("Failed to resume all devices: \(error.localizedDescription, privacy: .public)")
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
                configLog.error("Failed to deserialize config JSON")
                return
            }

            // 3. Find and modify the folder
            guard var folders = configJSON["folders"] as? [[String: Any]],
                  let folderIndex = folders.firstIndex(where: { ($0["id"] as? String) == folderID }) else {
                configLog.error("Folder with ID \(folderID, privacy: .public) not found in config JSON")
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
            configLog.error("Failed to set folder paused state for \(folderID, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    private func waitForSyncthingAvailability() async {
        var attempt = 0
        let maxAttempts = AppConstants.Polling.maxPollingAttempts
        var delay: UInt64 = AppConstants.Polling.initialPollingDelayNs

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
            delay = min(delay * 2, AppConstants.Polling.maxPollingDelayNs)
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
                    let needFiles = Int.random(in: 1...100)
                    dummyFolderStatuses[folderID] = SyncthingFolderStatus(
                        globalFiles: globalFiles,
                        globalBytes: globalBytes,
                        localFiles: globalFiles,
                        localBytes: globalBytes,
                        needFiles: needFiles,
                        needBytes: Int64.random(in: 1_000_000...100_000_000),
                        needDeletes: 0,
                        needTotalItems: needFiles,
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
                        needDeletes: 0,
                        needTotalItems: 0,
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

// MARK: - Stuck Deletes — Deletion Pipeline Types
/// Failure modes reported by `StuckDeletesController.deleteOne`. Each maps to
/// a one-line user-facing reason in the outcome banner.
enum DeletionError: Error, Equatable {
    /// Path failed the safety check (`..`, absolute, null bytes, escapes folder root).
    /// The most paranoid case — we never reached `removeItem`.
    case invalidPath
    /// Filesystem returned EACCES / NSFileWriteNoPermissionError. Usually means
    /// the user hasn't granted Full Disk Access for a TCC-protected path.
    case permissionDenied
    /// Anything else — generally a transient or niche I/O error. Carries the
    /// localized description so the user has something to act on.
    case osError(String)

    var humanReadable: String {
        switch self {
        case .invalidPath: return "Path rejected by safety check"
        case .permissionDenied: return "Permission denied — grant Full Disk Access"
        case .osError(let msg): return msg
        }
    }
}

/// Aggregate result of `StuckDeletesController.performDeletion`. The view
/// shows the outcome banner above the candidate list; failures stay in the
/// list (they weren't deleted) so the user can retry.
struct DeletionOutcome: Equatable {
    let succeededCount: Int
    let failed: [FailedItem]
    var hasFailures: Bool { !failed.isEmpty }

    struct FailedItem: Equatable {
        let name: String
        let reason: String
    }
}

// MARK: - Stuck Deletes Controller
/// Per-window controller for the stuck-deletes cleanup view. One instance is
/// constructed when the user clicks "Resolve…" on a folder; it owns the fetch
/// state, the candidate list, the deletion pipeline, and an FDA gate flag.
///
/// Threading: marked `@MainActor` for SwiftUI binding safety; FS-mutating work
/// runs on a detached background task using a fresh `FileManager()` instance
/// (the documented thread-safe choice — `FileManager.default` is per-thread).
@MainActor
final class StuckDeletesController: ObservableObject {
    @Published private(set) var candidates: [RemoteNeedItem] = []
    @Published private(set) var loading = false
    @Published private(set) var lastError: String?

    /// True while a deletion pass is in flight — disables UI interactions.
    @Published private(set) var deleting = false
    /// Result of the most recent `performDeletion` call. Cleared when a new
    /// one starts. Drives the outcome banner shown above the candidate list.
    @Published private(set) var lastOutcome: DeletionOutcome?
    /// True when the access pre-flight failed and we don't yet have a usable
    /// security-scoped bookmark for this folder root. Drives the grant-access
    /// gate view that replaces the candidate list. Reset by `recheckAccess()`
    /// once a bookmark resolves successfully.
    @Published private(set) var accessBlocked = false

    let folder: SyncthingFolder
    private let client: SyncthingClient
    private let bookmarks = FolderAccessBookmarks()
    /// Set by `StuckDeletesWindowController` after init so the SwiftUI Close
    /// button can dismiss the window without `Client.swift` needing AppKit.
    /// Captured weakly inside the closure to avoid retaining the window.
    var dismissAction: (() -> Void)?
    /// Set by `StuckDeletesWindowController`. Presents an `NSOpenPanel` so the
    /// user can grant the sandboxed app a security-scoped bookmark for the
    /// folder root. Behind a closure so the controller stays AppKit-free.
    var requestAccessAction: (() -> Void)?

    init(folder: SyncthingFolder, client: SyncthingClient) {
        self.folder = folder
        self.client = client
    }

    /// Fetches candidates from `db/need`, filters to deleted directory entries,
    /// sorts by name. Cancellation-safe: if the SwiftUI `.task` modifier
    /// cancels us (window closed mid-fetch), we silently return.
    func loadCandidates() async {
        loading = true
        defer { loading = false }
        lastError = nil

        do {
            let response = try await client.fetchDbNeed(folder: folder.id)
            try Task.checkCancellation()
            let dirs = response.allItems
                .filter { $0.deleted && $0.isDirectory && !$0.name.isEmpty }
                .sorted { $0.name < $1.name }
            candidates = dirs
            stuckDeletesLog.info("Loaded \(dirs.count, privacy: .public) stuck-delete candidate(s) for folder \(self.folder.id, privacy: .public)")
        } catch {
            if isCancellationError(error) { return }
            let desc = error.localizedDescription
            lastError = desc
            stuckDeletesLog.error("Failed db/need for folder \(self.folder.id, privacy: .public): \(desc, privacy: .public)")
        }
    }

    func close() {
        dismissAction?()
    }

    func requestAccess() {
        requestAccessAction?()
    }

    /// Validates a user-picked URL from `NSOpenPanel`, persists the resulting
    /// security-scoped bookmark, and re-runs the access probe. The picked URL
    /// must be the folder root itself or an ancestor — narrower selections
    /// don't grant access to the items we need to remove. Called by
    /// `StuckDeletesWindowController` from the panel completion handler;
    /// triggers an automatic candidate reload on success so the user lands
    /// directly in the cleanup view.
    func grantAccess(_ url: URL) {
        // realPath, not folder.path: any NSString standardization would expand
        // `~` against the sandbox container home and reject every valid pick.
        // Canonicalize both sides (symlinks, /private, firmlinks) — resolution
        // only needs metadata, which the sandbox allows even pre-grant.
        let chosenURL = url.standardizedFileURL.resolvingSymlinksInPath()
        let expectedURL = URL(fileURLWithPath: folder.realPath, isDirectory: true)
            .standardizedFileURL.resolvingSymlinksInPath()
        let chosenPath = chosenURL.path
        let expectedPath = expectedURL.path
        let isAtOrAbove = chosenPath == expectedPath
            || Self.isSameItem(chosenURL, expectedURL)
            || expectedPath.hasPrefix(chosenPath + "/")
        guard isAtOrAbove else {
            stuckDeletesLog.error("Bookmark grant rejected: \(chosenPath, privacy: .public) is not the folder root or an ancestor of \(expectedPath, privacy: .public)")
            lastError = "The selected folder doesn't grant access to \"\(expectedPath)\". Pick the folder root itself, or a parent of it."
            return
        }
        do {
            try bookmarks.save(url, for: folder.id)
            stuckDeletesLog.notice("Bookmark granted for folder \(self.folder.id, privacy: .public)")
            recheckAccess()
            if !accessBlocked {
                Task { await loadCandidates() }
            }
        } catch {
            stuckDeletesLog.error("Failed to save bookmark for folder \(self.folder.id, privacy: .public): \(error.localizedDescription, privacy: .public)")
            lastError = "Couldn't store the access grant: \(error.localizedDescription)"
        }
    }

    /// True when both URLs name the same on-disk item — survives APFS
    /// case-insensitivity (a panel pick returns on-disk casing, which may
    /// differ from Syncthing's configured spelling) and hard aliases.
    /// Metadata-only, so it works on paths without content access.
    private static func isSameItem(_ a: URL, _ b: URL) -> Bool {
        guard let ia = try? a.resourceValues(forKeys: [.fileResourceIdentifierKey]).fileResourceIdentifier,
              let ib = try? b.resourceValues(forKeys: [.fileResourceIdentifierKey]).fileResourceIdentifier
        else { return false }
        return ia.isEqual(ib)
    }

    /// Result of probing the folder root for accessibility. Each case maps to
    /// a distinct UI state, so the user gets an actionable message instead of
    /// being dead-ended in an access gate when the real issue is elsewhere.
    enum AccessProbeResult {
        /// Bookmark resolved and the folder is readable. Carries the
        /// security-scoped URL the caller should wrap subsequent work in via
        /// `startAccessingSecurityScopedResource()`.
        case granted(URL)
        /// No bookmark yet, or the bookmark resolved but the URL was
        /// unreadable (revoked, deleted, etc.). User must grant access via
        /// `NSOpenPanel`.
        case needsBookmark
        /// Folder root doesn't exist on this Mac. Requires proof: a stat that
        /// fails with ENOENT (sandbox permits metadata reads, so that's
        /// trustworthy even pre-grant), or a missing directory behind a
        /// resolved bookmark. A denied check reports `.needsBookmark` instead.
        case notFound(path: String)
        /// Path exists but isn't a directory (extremely unusual).
        case notADirectory(path: String)
        /// Anything else: I/O error, dead symlink, etc. Carries the localized
        /// description for the user.
        case other(message: String)
    }

    /// Re-runs the access probe. Called from the View when the user clicks
    /// "Try Again" after granting access. With security-scoped bookmarks the
    /// freshly-granted access is honored immediately — no quit-and-relaunch
    /// dance required (which is the whole point of this approach).
    func recheckAccess() {
        let result = probeFolderAccess()
        applyProbeResult(result)
        if case .granted = result {
            stuckDeletesLog.info("Access recheck: folder \(self.folder.id, privacy: .public) now readable")
        }
    }

    /// Resolves the stored security-scoped bookmark and verifies the folder
    /// root is readable. Distinguishes missing/stale bookmarks (need a fresh
    /// grant via `NSOpenPanel`) from genuine path problems (missing folder,
    /// non-directory, I/O errors) so the UI can show an actionable message.
    /// Stale-but-functional bookmarks are silently refreshed.
    private func probeFolderAccess() -> AccessProbeResult {
        let fm = FileManager()
        let path = folder.realPath
        stuckDeletesLog.debug("Probe: folder path \(self.folder.path, privacy: .public) resolved to \(path, privacy: .public)")

        // stat(2) instead of fileExists: the sandbox broadly allows metadata
        // reads (application.sb `file-read-metadata`), so ENOENT here is
        // provable absence — while EPERM only means "can't know", which must
        // never block the grant prompt. fileExists() conflates both as false.
        var st = stat()
        let statFailed = stat(path, &st) != 0
        let statErrno = statFailed ? errno : 0
        if !statFailed, (st.st_mode & S_IFMT) != S_IFDIR {
            stuckDeletesLog.error("Probe: path exists but is not a directory: \(path, privacy: .public)")
            return .notADirectory(path: path)
        }
        let provablyAbsent = statFailed && (statErrno == ENOENT || statErrno == ENOTDIR)

        switch bookmarks.resolve(for: folder.id) {
        case .missing:
            if provablyAbsent {
                stuckDeletesLog.error("Probe: folder root not found at \(path, privacy: .public)")
                return .notFound(path: path)
            }
            stuckDeletesLog.info("Probe: no bookmark for folder \(self.folder.id, privacy: .public) — needs grant")
            return .needsBookmark

        case .failed(let error):
            stuckDeletesLog.error("Probe: bookmark resolution failed for \(self.folder.id, privacy: .public) — \(error.localizedDescription, privacy: .public)")
            return .needsBookmark

        case .resolved(let url, let isStale):
            let started = url.startAccessingSecurityScopedResource()
            defer {
                if started { url.stopAccessingSecurityScopedResource() }
            }
            do {
                _ = try fm.contentsOfDirectory(atPath: url.path)
                if isStale {
                    bookmarks.refresh(url, for: folder.id)
                    stuckDeletesLog.info("Probe: bookmark refreshed for folder \(self.folder.id, privacy: .public)")
                }
                return .granted(url)
            } catch let e as CocoaError where e.code == .fileReadNoPermission {
                stuckDeletesLog.error("Probe: bookmark unusable for \(self.folder.id, privacy: .public) — \(e.localizedDescription, privacy: .public)")
                return .needsBookmark
            } catch let e as CocoaError where e.code == .fileReadNoSuchFile {
                // Bookmark resolved but the directory is gone — with access
                // held this IS provable absence, unlike the pre-grant stat.
                stuckDeletesLog.error("Probe: folder root missing at \(url.path, privacy: .public) — \(e.localizedDescription, privacy: .public)")
                return .notFound(path: url.path)
            } catch {
                let nsError = error as NSError
                stuckDeletesLog.error("Probe: unexpected error on \(url.path, privacy: .public) — domain=\(nsError.domain, privacy: .public) code=\(nsError.code, privacy: .public) desc=\(nsError.localizedDescription, privacy: .public)")
                return .other(message: nsError.localizedDescription)
            }
        }
    }

    /// Translates a probe result into the controller's published state. Only
    /// `.needsBookmark` flips `accessBlocked = true`; other failures surface
    /// through `lastError` so the user gets an actionable message instead of
    /// a misleading grant-access gate.
    private func applyProbeResult(_ result: AccessProbeResult) {
        switch result {
        case .granted:
            accessBlocked = false
            // Clear any previous access error from a prior failed probe.
            if let err = lastError,
               err.hasPrefix("Folder root") || err.hasPrefix("Couldn't access") || err.hasPrefix("Path exists") {
                lastError = nil
            }
        case .needsBookmark:
            accessBlocked = true
        case .notFound(let path):
            accessBlocked = false
            lastError = "Folder root not found on this Mac: \(path). Check Syncthing's folder configuration — the path may differ between peers."
        case .notADirectory(let path):
            accessBlocked = false
            lastError = "Path exists but isn't a directory: \(path)."
        case .other(let msg):
            accessBlocked = false
            lastError = "Couldn't access folder root: \(msg)"
        }
    }

    /// Deletes the user-selected candidates. Steps:
    ///   1. Per-item: validate path, then `removeItem` on a detached task.
    ///   2. Trigger Syncthing rescan (`POST /rest/db/scan`).
    ///   3. Wait briefly for the daemon to ingest the FS change.
    ///   4. Reload candidates so the UI reflects the new state — failed items
    ///      stay in the list (they weren't deleted), succeeded items disappear.
    ///
    /// Access pre-flight runs first; if it fails (no bookmark / stale / I/O
    /// error), we surface the gate UI instead of attempting any deletes. The
    /// security-scoped URL from a successful probe wraps the whole delete
    /// loop so each per-item operation runs inside the granted access.
    /// Idempotent on ENOENT (treat already-gone as success, so concurrent
    /// windows / concurrent Finder cleanups don't produce spurious "failed"
    /// entries).
    func performDeletion(selected: Set<String>) async {
        guard !deleting else { return }
        let toDelete = candidates.filter { selected.contains($0.id) }
        guard !toDelete.isEmpty else { return }

        // Pre-flight: only block when there's no usable bookmark. Other errors
        // (path missing, etc.) get surfaced through `lastError` so the user
        // sees the real problem instead of a misleading grant-access gate.
        let probe = probeFolderAccess()
        applyProbeResult(probe)
        guard case .granted(let folderRoot) = probe else { return }

        deleting = true
        defer { deleting = false }
        lastOutcome = nil

        stuckDeletesLog.notice("Deletion start: \(toDelete.count, privacy: .public) candidate(s) on folder \(self.folder.id, privacy: .public)")

        // Security-scoped access spans the whole delete loop. Sub-paths
        // constructed via appendingPathComponent inherit the parent scope, so
        // detached per-item tasks work without re-acquiring access.
        let started = folderRoot.startAccessingSecurityScopedResource()
        defer {
            if started { folderRoot.stopAccessingSecurityScopedResource() }
        }

        var succeededCount = 0
        var failed: [DeletionOutcome.FailedItem] = []

        for item in toDelete {
            switch await deleteOne(item: item, folderRoot: folderRoot) {
            case .success:
                succeededCount += 1
                stuckDeletesLog.notice("Deleted: \(item.name, privacy: .public)")
            case .failure(let err):
                failed.append(.init(name: item.name, reason: err.humanReadable))
                stuckDeletesLog.error("Deletion failed for \(item.name, privacy: .public): \(err.humanReadable, privacy: .public)")
            }
        }

        lastOutcome = DeletionOutcome(succeededCount: succeededCount, failed: failed)
        stuckDeletesLog.info("Deletion complete: \(succeededCount, privacy: .public) ok, \(failed.count, privacy: .public) failed")

        // Nudge Syncthing to reconcile; rescan is fire-and-forget.
        do {
            try await client.rescan(folder: folder.id)
            stuckDeletesLog.info("Rescan triggered for folder \(self.folder.id, privacy: .public)")
        } catch {
            stuckDeletesLog.error("Rescan request failed: \(error.localizedDescription, privacy: .public)")
        }

        // Give Syncthing 2 s to ingest filesystem changes, then refresh the
        // candidate list. Successful deletions disappear; failed items remain
        // and the user can retry without reopening the window.
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        await loadCandidates()
    }

    private func deleteOne(item: RemoteNeedItem, folderRoot: URL) async -> Result<Void, DeletionError> {
        guard let target = Self.validatePath(item.name, folderRoot: folderRoot) else {
            return .failure(.invalidPath)
        }

        return await Task.detached(priority: .userInitiated) {
            let fm = FileManager()  // fresh instance: thread-safe per Apple guidance

            // Probe attributes without following symlinks. `attributesOfItem`
            // queries the symlink itself, not its target — important for the
            // "directory containing a symlink to /" defense. We don't actually
            // *use* the type here; the call is a sanity probe whose error path
            // tells us whether the file is missing/permission-denied.
            do {
                _ = try fm.attributesOfItem(atPath: target.path)
            } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
                // Already gone — treat as success (idempotent).
                return .success(())
            } catch let error as CocoaError where error.code == .fileReadNoPermission {
                return .failure(.permissionDenied)
            } catch {
                return .failure(.osError(error.localizedDescription))
            }

            // Recursive removal. Foundation's removeItem unlinks symlinks for
            // the *top-level* item without following, and unlinks (not follows)
            // any nested symlinks during recursion. Documented POSIX behavior.
            do {
                try fm.removeItem(at: target)
                return .success(())
            } catch let error as CocoaError where
                error.code == .fileNoSuchFile || error.code == .fileReadNoSuchFile {
                return .success(())  // Race: deleted between probe and removal.
            } catch let error as CocoaError where
                error.code == .fileWriteNoPermission || error.code == .fileReadNoPermission {
                return .failure(.permissionDenied)
            } catch {
                return .failure(.osError(error.localizedDescription))
            }
        }.value
    }

    /// Validates a Syncthing-reported relative path against the folder root.
    /// `nonisolated static` so the detached deletion task can call it without
    /// awaiting the main actor (the function only reads its arguments, no
    /// shared state).
    ///
    /// Rejects:
    ///   - empty / null-byte-containing names
    ///   - leading `/` (absolute path)
    ///   - any `..` or `.` path component (not just leading)
    ///   - paths whose resolved-symlinks form is not a strict descendant of
    ///     the folder root
    ///
    /// Returns the *unresolved* candidate URL on success, so deletion targets
    /// the literal path Syncthing reported — the resolved form is used only
    /// for the safety check.
    nonisolated static func validatePath(_ name: String, folderRoot: URL) -> URL? {
        guard !name.isEmpty else { return nil }
        guard !name.contains("\0") else { return nil }
        guard !name.hasPrefix("/") else { return nil }

        let components = name.split(separator: "/")
        guard !components.contains(".."), !components.contains(".") else { return nil }

        let candidate = folderRoot.appendingPathComponent(name, isDirectory: true)
        let resolvedTarget = candidate.standardizedFileURL.resolvingSymlinksInPath()
        let resolvedRoot = folderRoot.standardizedFileURL.resolvingSymlinksInPath()

        let targetPath = resolvedTarget.path
        let rootPath = resolvedRoot.path
        let rootPrefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        guard targetPath.hasPrefix(rootPrefix) else { return nil }

        return candidate
    }
}

