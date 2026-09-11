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

// MARK: - Server Trust

/// Accepts Syncthing's self-signed GUI certificate, but only on loopback.
///
/// Syncthing's `<gui tls="true">` setting ("Use HTTPS for GUI") serves the REST
/// API with a self-signed certificate from `https-cert.pem`, which URLSession
/// rejects as `NSURLErrorServerCertificateUntrusted` — surfacing to the user as
/// Apple's alarming "a server that is pretending to be" text. That setting also
/// redirects plain HTTP to HTTPS, so users hit this even with the default
/// `http://127.0.0.1:8384` base URL untouched.
///
/// Trust is granted only for loopback hosts, where the traffic never leaves the
/// machine and there is no network path for an impostor to sit on. A self-signed
/// certificate from a *remote* host is indistinguishable from a real
/// interception, so those fall through to default handling and stay a hard
/// failure rather than a silent trust.
final class SyncthingServerTrustDelegate: NSObject, URLSessionDelegate {

    /// True for hosts that resolve to this machine. Covers all of `127.0.0.0/8`
    /// — Syncthing defaults to `127.0.0.1`, but the GUI can be bound anywhere in
    /// the loopback range.
    static func isLoopback(_ host: String) -> Bool {
        let host = host.lowercased()
        if host == "localhost" || host == "localhost." { return true }
        if host == "::1" || host == "[::1]" { return true }

        let octets = host.split(separator: ".", omittingEmptySubsequences: false)
        guard octets.count == 4, octets[0] == "127" else { return false }
        return octets.allSatisfy { UInt8($0) != nil }
    }

    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let host = challenge.protectionSpace.host

        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust,
              Self.isLoopback(host) else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        networkLog.notice("Accepting self-signed certificate from loopback host \(host, privacy: .public)")
        completionHandler(.useCredential, URLCredential(trust: serverTrust))
    }
}

// MARK: - Syncthing API Client
@MainActor
class SyncthingClient: ObservableObject {
    typealias NotificationDelivery = (UNNotificationRequest, @escaping @Sendable (Error?) -> Void) -> Void
    typealias RequestData = (URLRequest) async throws -> (Data, URLResponse)

    private let session: URLSession
    private let requestData: RequestData?
    private let deliverNotification: NotificationDelivery
    private let settings: SyncthingSettings
    private var baseURL: URL?
    private var apiKey: String?
    private var cachedAutomaticAPIKey: String?
    /// Changes immediately on connection settings edits, before the refresh debounce.
    @Published private(set) var cleanupConnectionRevision = UUID()
    private var cancellables = Set<AnyCancellable>()

    // Transfer rate tracking
    private var previousConnections: [String: SyncthingConnection] = [:]
    private var lastUpdateTime: Date?

    // Connection history tracking
    private var connectionHistory: [String: ConnectionHistory] = [:]

    // Sync event tracking
    private var globalSyncCompletion = GlobalSyncCompletionTracker()
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
    private var refreshWorker: Task<Void, Never>?
    private var refreshRequested = false
    private var refreshWaiters: [() -> Void] = []
    private var refreshGeneration = UUID()
    private var isShutdown = false
    private var monitoring = false
    private var monitoringTimer: AnyCancellable?
    private var timerRevision = UUID()
    typealias TimerFactory = (TimeInterval, @escaping @MainActor () -> Void) -> AnyCancellable
    private let makeTimer: TimerFactory
    private var requestSequence = 0
    private var inFlightRequests = 0
    
    private struct StalledSyncTracker {
        var syncStart: Date
        var lastProgress: Date
        var lastNeedBytes: Int64
        var lastNeedFiles: Int
        var lastNotificationDate: Date?
    }
    private var stalledSyncTrackers: [String: StalledSyncTracker] = [:]

    @Published var configurationAvailable = false
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
    
    init(settings: SyncthingSettings, session: URLSession? = nil,
         requestData: RequestData? = nil,
         makeTimer: @escaping TimerFactory = { interval, fire in
             let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
                 Task { @MainActor in fire() }
             }
             return AnyCancellable { timer.invalidate() }
         },
         deliverNotification: @escaping NotificationDelivery = { request, completion in
             UNUserNotificationCenter.current().add(request, withCompletionHandler: completion)
         }) {
        self.settings = settings
        self.requestData = requestData
        self.makeTimer = makeTimer
        self.deliverNotification = deliverNotification

        // Configure URLSession with appropriate timeouts if not provided
        if let session = session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = AppConstants.Network.requestTimeoutSeconds
            config.timeoutIntervalForResource = AppConstants.Network.resourceTimeoutSeconds
            config.waitsForConnectivity = false       // Fail fast
            // Delegate trusts Syncthing's self-signed GUI cert on loopback only.
            self.session = URLSession(configuration: config,
                                      delegate: SyncthingServerTrustDelegate(),
                                      delegateQueue: nil)
        }

        observeSettings()
    }

    deinit {
        activeRefreshTask?.cancel()
    }

    // MARK: - Computed Statistics
    var hasCurrentConfiguration: Bool { configurationAvailable || demoMode }

    var folderStatisticsAvailable: Bool {
        hasCurrentConfiguration && folders.allSatisfy { folderStatuses[$0.id] != nil }
    }

    var hasPendingSyncWork: Bool {
        guard hasCurrentConfiguration else { return false }
        return folders.contains { folder in
            guard !folder.paused, let status = folderStatuses[folder.id] else { return false }
            return status.hasPendingWork || status.state == "syncing"
        } || devices.contains {
            SyncStatusPolicy.device($0, connection: connections[$0.id], completion: deviceCompletions[$0.id]) == .pending
        }
    }

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
        Publishers.CombineLatest4(settings.$useAutomaticDiscovery, settings.$baseURLString,
                                  settings.$manualAPIKey, settings.$configBookmarkData)
            .dropFirst()
            .sink { [weak self] _ in
                guard let self else { return }
                // @Published emits before assignment. Invalidate now; the drain
                // task prepares credentials on a later actor turn.
                self.cleanupConnectionRevision = UUID()
                self.cachedAutomaticAPIKey = nil
                self.invalidateRefresh()
                self.clearConnectionState()
                if self.monitoring || self.refreshWorker != nil { self.requestRefresh() }
            }
            .store(in: &cancellables)

        settings.$refreshInterval
            .dropFirst()
            .sink { [weak self] interval in self?.installMonitoringTimer(interval: interval) }
            .store(in: &cancellables)
    }

    func startMonitoring() {
        guard !isShutdown, !monitoring else { return }
        monitoring = true
        installMonitoringTimer(interval: settings.refreshInterval)
        requestRefresh()
    }

    private func installMonitoringTimer(interval: TimeInterval) {
        timerRevision = UUID()
        monitoringTimer = nil
        guard monitoring, !isShutdown, !demoMode else { return }
        let revision = timerRevision
        monitoringTimer = makeTimer(max(1, interval)) { [weak self] in
            guard let self, self.timerRevision == revision else { return }
            self.requestRefresh()
        }
    }

    /// Terminal shutdown: no queued timer/settings callback may restart work.
    func stopMonitoring() {
        isShutdown = true
        monitoring = false
        installMonitoringTimer(interval: settings.refreshInterval)
        invalidateRefresh()
        refreshRequested = false
        let waiters = refreshWaiters
        refreshWaiters.removeAll()
        waiters.forEach { $0() }
    }

    func waitForRefreshToFinish() async { await refreshWorker?.value }

    private func invalidateRefresh() {
        globalSyncCompletion = GlobalSyncCompletionTracker()
        refreshGeneration = UUID()
        activeRefreshTask?.cancel()
    }

    private func canPublish(_ generation: UUID) -> Bool {
        generation == refreshGeneration && !Task.isCancelled && !isShutdown && !demoMode
    }

    private func clearConnectionState() {
        realDevices = []
        realFolders = []
        realConnections = [:]
        realFolderStatuses = [:]
        realTransferHistory = [:]
        realTotalTransferHistory = DeviceTransferHistory()
        previousConnections = [:]
        lastUpdateTime = nil
        connectionHistory = [:]
        previousFolderStates = [:]
        stalledSyncTrackers = [:]
        lastSyncNotificationDates = [:]
        lastGlobalSyncNotificationSentAt = nil
        syncEvents = []
        // Demo owns a complete synthetic presentation, including its metrics.
        // Settings invalidate only the real cache until demo exits.
        guard !demoMode else { return }
        handleDisconnectedState()
        lastErrorMessage = nil
        localDeviceName = ""
        syncthingVersion = nil
        deviceHistory = [:]
        transferRates = [:]
        transferHistory = [:]
        totalTransferHistory = DeviceTransferHistory()
        totalTransferHistory_published = DeviceTransferHistory()
        deviceTransferHistory = [:]
        recentSyncEvents = []
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
    
    /// On-demand safety preflight; never trusts the monitoring cache for deletion.
    func fetchCleanupFolder(id: String, revision: UUID, deviceID: String) async throws -> SyncthingFolder {
        guard cleanupConnectionRevision == revision, !demoMode, prepareCredentials() else {
            throw CleanupSafetyError.obsolete
        }
        let status = try await makeRequest(endpoint: "system/status", responseType: SyncthingSystemStatus.self,
                                           requiresFreshResponse: true)
        try Task.checkCancellation()
        guard cleanupConnectionRevision == revision, !demoMode, status.myID == deviceID else {
            throw CleanupSafetyError.obsolete
        }
        let folder = try await makeRequest(endpoint: "config/folders", responseType: SyncthingFolder.self,
                                           lastPathComponent: id, requiresFreshResponse: true)
        try Task.checkCancellation()
        guard cleanupConnectionRevision == revision, !demoMode, folder.id == id else {
            throw CleanupSafetyError.obsolete
        }
        return folder
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
    
    private func loadData(for request: URLRequest) async throws -> (Data, URLResponse) {
        try Task.checkCancellation()
        requestSequence += 1
        let sequence = requestSequence
        // Only endpoint families are logged: no URL, query, key, identifier or body.
        let parts = request.url?.pathComponents ?? []
        let rest = parts.lastIndex(of: "rest")
        let endpoint = rest.map { parts.dropFirst($0 + 1).prefix(2).joined(separator: "/") } ?? "request"
        let start = ProcessInfo.processInfo.systemUptime
        inFlightRequests += 1
        networkLog.info("Request \(sequence) started \(endpoint, privacy: .public), active=\(self.inFlightRequests)")
        var outcome = "failed"
        defer {
            inFlightRequests -= 1
            let elapsed = ProcessInfo.processInfo.systemUptime - start
            networkLog.info("Request \(sequence) finished \(endpoint, privacy: .public), outcome=\(outcome, privacy: .public), seconds=\(elapsed), active=\(self.inFlightRequests)")
        }
        do {
            let result: (Data, URLResponse)
            if let requestData { result = try await requestData(request) }
            else { result = try await session.data(for: request) }
            try Task.checkCancellation()
            let code = (result.1 as? HTTPURLResponse)?.statusCode ?? -1
            outcome = "http-\(code)"
            return result
        } catch {
            if isCancellationError(error) { outcome = "cancelled" }
            throw error
        }
    }

    private func makeRequest<T: Decodable>(endpoint: String, responseType: T.Type,
                                           lastPathComponent: String? = nil,
                                           requiresFreshResponse: Bool = false) async throws -> T {
        guard var url = endpointURL(path: endpoint) else { throw URLError(.badURL) }
        if let lastPathComponent {
            let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
            guard let encoded = lastPathComponent.addingPercentEncoding(withAllowedCharacters: allowed),
                  var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                throw URLError(.badURL)
            }
            components.percentEncodedPath += "/" + encoded
            guard let resolved = components.url else { throw URLError(.badURL) }
            url = resolved
        }
        guard let apiKey else { throw SyncthingClientError.missingAPIKey }

        var request = URLRequest(url: url)
        if requiresFreshResponse {
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        }
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")

        let (data, response) = try await loadData(for: request)

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

        let (data, response) = try await loadData(for: request)

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

        let (_, response) = try await loadData(for: request)

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

        let (_, response) = try await loadData(for: request)

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

        let (data, response) = try await loadData(for: request)

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

        let (_, response) = try await loadData(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            networkLog.error("Raw POST \(endpoint, privacy: .public) failed with HTTP \(code, privacy: .public)")
            throw SyncthingClientError.httpStatus(code: code, endpoint: endpoint)
        }
    }
    
    func fetchStatus(generation: UUID? = nil) async {
        let generation = generation ?? refreshGeneration
        guard canPublish(generation) else { return }
        do {
            let status = try await makeRequest(endpoint: "system/status", responseType: SyncthingSystemStatus.self)
            guard canPublish(generation) else { return }
            self.systemStatus = status
            self.isConnected = true
            self.lastErrorMessage = nil
        } catch {
            guard canPublish(generation), !isCancellationError(error) else { return }
            handleDisconnectedState()

            let message: String
            if let clientError = error as? SyncthingClientError {
                message = clientError.localizedDescription
            } else if let urlError = error as? URLError {
                switch urlError.code {
                case .userAuthenticationRequired:
                    message = "API key missing or invalid."
                case .cannotFindHost, .cannotConnectToHost:
                    message = "Could not reach Syncthing at \(settings.trimmedBaseURL)."
                case .serverCertificateUntrusted, .serverCertificateHasUnknownRoot,
                     .serverCertificateHasBadDate, .serverCertificateNotYetValid:
                    // Loopback self-signed certs are accepted by
                    // SyncthingServerTrustDelegate, so reaching here means a
                    // remote host — where an untrusted cert cannot safely be
                    // waved through. Point at the fix instead of showing
                    // Apple's "server that is pretending to be" wording.
                    message = "Syncthing's HTTPS certificate isn't trusted by macOS. Turn off \"Use HTTPS for GUI\" in Syncthing's Settings → GUI, or give it a certificate from a trusted authority."
                default:
                    message = urlError.localizedDescription
                }
            } else {
                message = error.localizedDescription
            }

            self.lastErrorMessage = "Failed to connect to Syncthing: \(message)"
        }
    }
    

    func fetchVersion(generation: UUID? = nil) async {
        let generation = generation ?? refreshGeneration
        guard canPublish(generation) else { return }
        do {
            let versionInfo = try await makeRequest(endpoint: "system/version", responseType: SyncthingVersion.self)
            guard canPublish(generation) else { return }
            self.syncthingVersion = versionInfo.version
        } catch {
            guard canPublish(generation), !isCancellationError(error) else { return }
            networkLog.error("Failed to fetch system/version: \(error.localizedDescription, privacy: .public)")
            self.syncthingVersion = nil
        }
    }
    

    func fetchConfig(localDeviceID: String, generation: UUID? = nil) async {
        let generation = generation ?? refreshGeneration
        guard canPublish(generation) else { return }
        do {
            let config = try await makeRequest(endpoint: "system/config", responseType: SyncthingConfig.self)
            guard canPublish(generation) else { return }
            
            if let localDevice = config.devices.first(where: { $0.deviceID == localDeviceID }) {
                self.localDeviceName = localDevice.name
            }
            let remoteDevices = config.devices.filter { $0.deviceID != localDeviceID }
            
            let unchangedFolderIDs = Set(config.folders.filter { realFolders.contains($0) }.map(\.id))
            realFolderStatuses = realFolderStatuses.filter { unchangedFolderIDs.contains($0.key) }
            previousFolderStates = previousFolderStates.filter { unchangedFolderIDs.contains($0.key) }

            // Always cache the real data
            self.realDevices = remoteDevices
            self.realFolders = config.folders

            // Only update the published properties if not in debug mode
            if !demoMode {
                self.configurationAvailable = true
                self.devices = remoteDevices
                self.folders = config.folders

                // Prune cached status for folders/devices no longer in config.
                // Without this, removing a folder or device would leave its
                // last-known status forever and could keep the resolver in a
                // wrong state.
                let validFolderIDs = unchangedFolderIDs
                self.folderStatuses = self.folderStatuses.filter { validFolderIDs.contains($0.key) }
                let validDeviceIDs = Set(remoteDevices.map { $0.deviceID })
                self.deviceCompletions = self.deviceCompletions.filter { validDeviceIDs.contains($0.key) }
            }
        } catch {
            guard canPublish(generation), !isCancellationError(error) else { return }
            realFolderStatuses = [:]
            previousFolderStates.removeAll()
            if !demoMode {
                configurationAvailable = false
                folderStatuses = [:]
                deviceCompletions = [:]
            }
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
    

    func fetchConnections(generation: UUID? = nil) async {
        let generation = generation ?? refreshGeneration
        guard canPublish(generation) else { return }
        do {
            let connectionsResponse = try await makeRequest(endpoint: "system/connections", responseType: SyncthingConnections.self)
            guard canPublish(generation) else { return }
            
            // Always cache the real data
            self.realConnections = connectionsResponse.connections
            
            // Only update the published properties if not in debug mode
            if !demoMode {
                self.updateConnectionHistory(newConnections: connectionsResponse.connections)
                self.calculateTransferRates(newConnections: connectionsResponse.connections)
                self.connections = connectionsResponse.connections
            }
        } catch {
            guard canPublish(generation), !isCancellationError(error) else { return }
            realConnections = [:]
            if !demoMode {
                connections = [:]
                transferRates = [:]
            }
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

    func fetchFolderStatus(generation: UUID? = nil) async {
        let generation = generation ?? refreshGeneration
        guard canPublish(generation), configurationAvailable else { return }
        await forEachMonitoringEntry(realFolders, generation: generation) { folder in
            await self.fetchFolderStatus(folder: folder, generation: generation)
        }
        guard canPublish(generation) else { return }
        updateStuckDeletesSignal()
    }

    private func fetchFolderStatus(folder: SyncthingFolder, generation: UUID) async {
        guard canPublish(generation) else { return }
        do {
            let status = try await makeRequest(path: "db/status", queryItems: [URLQueryItem(name: "folder", value: folder.id)], responseType: SyncthingFolderStatus.self)
            guard canPublish(generation) else { return }
            if configurationAvailable { self.realFolderStatuses[folder.id] = status }

            if !demoMode && configurationAvailable {
                self.folderStatuses[folder.id] = status
                self.trackSyncEvent(folder: folder, status: status)
            }
        } catch {
            guard canPublish(generation), !isCancellationError(error) else { return }
            // A genuine failed observation invalidates cached success.
            // Obsolete or cancelled passes returned before touching state.
            realFolderStatuses.removeValue(forKey: folder.id)
            if !demoMode {
                folderStatuses.removeValue(forKey: folder.id)
                previousFolderStates.removeValue(forKey: folder.id)
            }
            let errorMessage = "Failed to fetch folder status for \(folder.id): \(error.localizedDescription)"
            folderStatusLog.error("\(errorMessage, privacy: .public)")
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

    /// Two requests per entry kind, four expensive requests in a full pass.
    /// Refill a completed slot without waiting for its slow sibling. The
    /// production URLSession resource timeout bounds occupied slots.
    private func forEachMonitoringEntry<Entry: Sendable>(
        _ entries: [Entry], generation: UUID,
        operation: @escaping @MainActor (Entry) async -> Void
    ) async {
        await withTaskGroup(of: Void.self) { group in
            var next = 0
            for entry in entries.prefix(AppConstants.Network.monitoringRequestsPerKind) {
                guard canPublish(generation) else { return }
                group.addTask { await operation(entry) }
                next += 1
            }
            while await group.next() != nil {
                guard canPublish(generation) else { group.cancelAll(); return }
                if next < entries.count {
                    let entry = entries[next]
                    next += 1
                    group.addTask { await operation(entry) }
                }
            }
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
        var unavailableFolderIDs: Set<String> = []
        let debounce = AppConstants.Sync.stuckDeletesDebounceSeconds

        for folder in folders where !folder.paused {
            guard configurationAvailable, let s = folderStatuses[folder.id] else {
                firstSeenStuckAt.removeValue(forKey: folder.id)
                // Hide stale counts without claiming that an unobserved problem resolved.
                unavailableFolderIDs.insert(folder.id)
                continue
            }

            // Items are stuck-eligible whenever needDeletes is outstanding and
            // no real sync work is in flight. State (idle vs scanning vs
            // sync-waiting) is intentionally NOT in this check — rescan
            // transitions don't make the items un-stuck.
            let isStuckEligible =
                s.needDeletes > 0 &&
                s.needFiles == 0 &&
                s.needDirectories == 0 && s.needSymlinks == 0 &&
                s.needTotalItems <= s.needDeletes && s.needBytes == 0

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
            where wasDetected && newCounts[folderID] == nil && !unavailableFolderIDs.contains(folderID) {
            stuckDeletesLog.notice("Stuck deletes cleared on folder \(folderID, privacy: .public)")
            lastLoggedStuckState[folderID] = false
        }

        stuckDeleteCounts = newCounts
    }

    private func trackSyncEvent(folder: SyncthingFolder, status: SyncthingFolderStatus) {
        let policy = SyncStatusPolicy.folder(folder, status: status)
        let effectivelyComplete = policy == .upToDate
        let previousState = previousFolderStates[folder.id]
        let effectiveState: String
        switch policy {
        case .upToDate: effectiveState = "idle"
        case .pending: effectiveState = "syncing"
        case .active(let state):
            effectiveState = (state == "syncing" || previousState == "syncing") ? "syncing" : state
        case .paused, .unavailable, .error:
            previousFolderStates.removeValue(forKey: folder.id)
            return
        }

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
                let remainingDescription = "All files synchronized"

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

        deliverNotification(request) { error in
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

        deliverNotification(request) { error in
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

        deliverNotification(request) { error in
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

        deliverNotification(request) { error in
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

        deliverNotification(request) { error in
            if let error = error {
                notificationsLog.error("Failed to send connection notification: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
    
    func fetchDeviceCompletions(generation: UUID? = nil) async {
        let generation = generation ?? refreshGeneration
        guard canPublish(generation), configurationAvailable else { return }
        await forEachMonitoringEntry(realDevices, generation: generation) { device in
            await self.fetchDeviceCompletion(device: device, generation: generation)
        }
    }

    private func fetchDeviceCompletion(device: SyncthingDevice, generation: UUID) async {
        guard canPublish(generation) else { return }
        do {
            let completion = try await makeRequest(path: "db/completion", queryItems: [URLQueryItem(name: "device", value: device.deviceID)], responseType: SyncthingDeviceCompletion.self)
            guard canPublish(generation) else { return }
            // No separate cache for completions, as they are keyed by real device IDs.
            // We can just update the main dictionary.
            if !demoMode && configurationAvailable {
                self.deviceCompletions[device.deviceID] = completion
            }
        } catch {
            guard canPublish(generation), !isCancellationError(error) else { return }
            if !demoMode { deviceCompletions.removeValue(forKey: device.deviceID) }
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

    private func handleDisconnectedState() {
        globalSyncCompletion = GlobalSyncCompletionTracker()
        previousFolderStates.removeAll()
        realFolderStatuses.removeAll()
        configurationAvailable = false
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
    
    /// Timer and action triggers share one pending pass. Completions belong to
    /// that pass, so manual callers need not wait for an endless timer drain.
    func requestRefresh(completion: (() -> Void)? = nil) {
        guard !isShutdown, !demoMode else { completion?(); return }
        refreshRequested = true
        if let completion { refreshWaiters.append(completion) }
        guard refreshWorker == nil else { return }
        isRefreshing = true
        refreshWorker = Task { [weak self] in
            guard let self else { return }
            while self.refreshRequested && !self.isShutdown && !self.demoMode {
                self.refreshRequested = false
                let waiters = self.refreshWaiters
                self.refreshWaiters.removeAll()
                let generation = self.refreshGeneration
                let pass = Task { await self.performRefresh(generation: generation) }
                self.activeRefreshTask = pass
                await pass.value
                self.activeRefreshTask = nil
                if generation != self.refreshGeneration && !self.isShutdown && !self.demoMode {
                    self.refreshWaiters.insert(contentsOf: waiters, at: 0)
                    self.refreshRequested = true
                } else {
                    waiters.forEach { $0() }
                }
            }
            self.refreshWorker = nil
            self.isRefreshing = false
            let waiters = self.refreshWaiters
            self.refreshWaiters.removeAll()
            waiters.forEach { $0() }
        }
    }

    func refresh() async {
        await withCheckedContinuation { continuation in
            requestRefresh { continuation.resume() }
        }
    }

    private func performRefresh(generation: UUID) async {
        guard canPublish(generation) else { return }
        let prepared = prepareCredentials()
        // Refreshing a stale bookmark can itself invalidate this generation.
        guard canPublish(generation) else { return }
        guard prepared else { handleDisconnectedState(); return }

        await fetchStatus(generation: generation)
        guard canPublish(generation), let systemStatus else { return }
        await fetchConfig(localDeviceID: systemStatus.myID, generation: generation)
        guard canPublish(generation) else { return }

        async let versionTask: () = fetchVersion(generation: generation)
        async let connectionsTask: () = fetchConnections(generation: generation)
        async let folderStatusTask: () = fetchFolderStatus(generation: generation)
        async let deviceCompletionTask: () = fetchDeviceCompletions(generation: generation)
        _ = await [versionTask, connectionsTask, folderStatusTask, deviceCompletionTask]
        guard canPublish(generation) else { return }
        // A completed pass is observable even if the next timer pass is queued.
        // Notification ownership follows data publication, not icon rendering.
        let state = StatusIconStateResolver().resolveState(client: self, settings: settings)
        if globalSyncCompletion.observe(state, hasPendingWork: hasPendingSyncWork, isRefreshing: false) {
            deliverGlobalCompletionIfAllowed()
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
            guard !isCancellationError(error), !demoMode else { return }
            let deviceName = devices.first { $0.deviceID == deviceID }?.name ?? deviceID
            lastErrorMessage = "Failed to pause \(deviceName): \(error.localizedDescription)"
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
            guard !isCancellationError(error), !demoMode else { return }
            let deviceName = devices.first { $0.deviceID == deviceID }?.name ?? deviceID
            lastErrorMessage = "Failed to resume \(deviceName): \(error.localizedDescription)"
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
            guard !isCancellationError(error), !demoMode else { return }
            lastErrorMessage = "Failed to pause all devices: \(error.localizedDescription)"
        }
    }

    func resumeAllDevices() async {
        do {
            try await postRequest(endpoint: "system/resume")
            sendPauseResumeNotification(target: .allDevices, paused: false)
            await refresh()
        } catch {
            networkLog.error("Failed to resume all devices: \(error.localizedDescription, privacy: .public)")
            guard !isCancellationError(error), !demoMode else { return }
            lastErrorMessage = "Failed to resume all devices: \(error.localizedDescription)"
        }
    }

    func handleGlobalSyncComplete() {
        guard !isRefreshing else { return }
        deliverGlobalCompletionIfAllowed()
    }

    private func deliverGlobalCompletionIfAllowed() {
        guard settings.showSyncNotifications, !demoMode, !isShutdown,
              StatusIconStateResolver().resolveState(client: self, settings: settings) == .inSync else { return }

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
            guard !isCancellationError(error), !demoMode else { return }
            let folderName = folders.first { $0.id == folderID }?.label ?? folderID
            lastErrorMessage = "Failed to \(paused ? "pause" : "resume") \(folderName): \(error.localizedDescription)"
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

                let (_, response) = try await loadData(for: request)
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

        invalidateRefresh()
        refreshRequested = false
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
        installMonitoringTimer(interval: settings.refreshInterval)
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

        // Explicit synthetic completion keeps demo status subject to the same policy.
        deviceCompletions = Dictionary(uniqueKeysWithValues: dummyDevices.map { device in
            let rates = dummyTransferRates[device.id] ?? TransferRates()
            let active = rates.downloadRate > 0 || rates.uploadRate > 0
            return (device.id, SyncthingDeviceCompletion(completion: active ? 50 : 100,
                globalBytes: 1000, needBytes: active ? 500 : 0, needItems: active ? 1 : 0))
        })
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
        invalidateRefresh()
        demoMode = false
        demoDeviceCount = 0
        demoFolderCount = 0
        demoScenario = .mixed  // Reset to default

        // Cached pre-demo observations are no longer current. Reconnect before
        // restoring real rows or completion/notification baselines.
        clearConnectionState()
        installMonitoringTimer(interval: settings.refreshInterval)
        requestRefresh()
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
    /// the folder grant is missing or no longer permits this operation.
    case permissionDenied
    /// Anything else — generally a transient or niche I/O error. Carries the
    /// localized description so the user has something to act on.
    case osError(String)

    var humanReadable: String {
        switch self {
        case .invalidPath: return "Path rejected by safety check"
        case .permissionDenied: return "Permission denied — grant folder access again and check filesystem permissions"
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

// MARK: - Cleanup target and confirmation identity
private enum CleanupSafetyError: LocalizedError {
    case obsolete
    var errorDescription: String? {
        "The folder or connection changed. Close this cleanup window, reopen it from the current folder, and review the selection again."
    }
}

/// Captures both the canonical location and the filesystem object present at review.
/// Metadata is readable under the sandbox even before content access is granted.
private struct CleanupRootIdentity: Sendable {
    let url: URL
    let device: dev_t?
    let inode: ino_t?

    init(_ url: URL) {
        self.url = url.standardizedFileURL.resolvingSymlinksInPath()
        var info = stat()
        let exists = stat(self.url.path, &info) == 0 && (info.st_mode & S_IFMT) == S_IFDIR
        device = exists ? info.st_dev : nil
        inode = exists ? info.st_ino : nil
    }

    func matches(_ candidate: URL) -> Bool {
        let other = CleanupRootIdentity(candidate)
        guard let device, let inode, other.device == device, other.inode == inode else { return false }
        // File identity accommodates case/firmlink aliases. The old captured path
        // must still refer to the reviewed object (rename/replacement is obsolete).
        var info = stat()
        return stat(url.path, &info) == 0 && info.st_dev == device && info.st_ino == inode
    }
}

/// Cancellation reaches detached filesystem work without reading actor state there.
private final class CleanupPermit: @unchecked Sendable {
    private let lock = NSLock()
    private var valid = true
    var isValid: Bool { lock.lock(); defer { lock.unlock() }; return valid }
    func invalidate() { lock.lock(); valid = false; lock.unlock() }
}

struct CleanupConfirmation: Identifiable, Equatable {
    let id: UUID
    let rootPath: String
    let names: [String]
    fileprivate let revision: UUID
    fileprivate let authorizationToken: Data?
}

@MainActor
final class StuckDeletesController: ObservableObject {
    @Published private(set) var candidates: [RemoteNeedItem] = []
    @Published private(set) var loading = false
    @Published private(set) var lastError: String?
    @Published private(set) var deleting = false
    @Published private(set) var lastOutcome: DeletionOutcome?
    @Published private(set) var accessBlocked = false
    @Published private(set) var confirmation: CleanupConfirmation?
    @Published private(set) var obsolete = false

    let folder: SyncthingFolder
    private let client: SyncthingClient
    private let bookmarks: any FolderBookmarkStore
    private let securityScope: FolderSecurityScope
    private let waitForReconciliation: () async -> Void
    private let rootIdentity: CleanupRootIdentity
    private let connectionRevision: UUID
    private let deviceID: String?
    private var revision = UUID()
    private var loadRevision = UUID()
    private var permit: CleanupPermit?
    private var subscriptions = Set<AnyCancellable>()
    var dismissAction: (() -> Void)?
    var requestAccessAction: (() -> Void)?
    var requestConfirmationAction: ((CleanupConfirmation, @escaping (Bool) -> Void) -> Void)?

    init(folder: SyncthingFolder, client: SyncthingClient,
         bookmarks: any FolderBookmarkStore = FolderAccessBookmarks(),
         securityScope: FolderSecurityScope = .live,
         waitForReconciliation: @escaping () async -> Void = {
             try? await Task.sleep(nanoseconds: 2_000_000_000)
         }) {
        self.folder = folder
        self.client = client
        self.bookmarks = bookmarks
        self.securityScope = securityScope
        self.waitForReconciliation = waitForReconciliation
        rootIdentity = CleanupRootIdentity(folder.realURL)
        connectionRevision = client.cleanupConnectionRevision
        deviceID = client.systemStatus?.myID
        client.$cleanupConnectionRevision.dropFirst().sink { [weak self] _ in
            self?.invalidateIdentity()
        }.store(in: &subscriptions)
        client.$folders.dropFirst().sink { [weak self] folders in
            guard let self else { return }
            guard let current = folders.first(where: { $0.id == self.folder.id }),
                  self.rootIdentity.matches(current.realURL) else {
                self.invalidateIdentity()
                return
            }
        }.store(in: &subscriptions)
        client.$demoMode.dropFirst().sink { [weak self] _ in
            self?.invalidateIdentity()
        }.store(in: &subscriptions)
        client.$systemStatus.map { $0?.myID }.removeDuplicates().dropFirst().sink { [weak self] id in
            guard let self, id != self.deviceID else { return }
            self.invalidateIdentity()
        }.store(in: &subscriptions)
    }

    private func invalidateIdentity() {
        if !obsolete { stuckDeletesLog.notice("Cleanup invalidated: folder or connection changed") }
        obsolete = true
        invalidateConfirmation()
        permit?.invalidate()
        lastError = CleanupSafetyError.obsolete.localizedDescription
    }

    func invalidateConfirmation() {
        permit?.invalidate()
        revision = UUID()
        confirmation = nil
    }

    private func checkIdentity() throws {
        try Task.checkCancellation()
        guard !obsolete, !client.demoMode, connectionRevision == client.cleanupConnectionRevision,
              let deviceID, !deviceID.isEmpty, deviceID == client.systemStatus?.myID,
              let current = client.folders.first(where: { $0.id == folder.id }),
              rootIdentity.matches(current.realURL), rootIdentity.matches(folder.realURL) else {
            invalidateIdentity()
            throw CleanupSafetyError.obsolete
        }
    }

    func loadCandidates() async {
        guard !deleting else { return }
        await reloadCandidates()
    }

    private func reloadCandidates() async {
        invalidateConfirmation()
        let token = UUID()
        loadRevision = token
        loading = true
        defer { if loadRevision == token { loading = false } }
        do {
            try checkIdentity()
            lastError = nil
            let response = try await client.fetchDbNeed(folder: folder.id)
            try checkIdentity()
            guard token == loadRevision else { return }
            candidates = response.allItems
                .filter { $0.deleted && $0.isDirectory && !$0.name.isEmpty }
                .sorted { $0.name < $1.name }
            stuckDeletesLog.info("Loaded \(self.candidates.count, privacy: .public) cleanup candidates")
        } catch {
            guard token == loadRevision, !isCancellationError(error) else { return }
            lastError = error.localizedDescription
        }
    }

    func cancelPendingWork() {
        permit?.invalidate()
        invalidateConfirmation()
        loadRevision = UUID()
    }

    func close() {
        cancelPendingWork()
        dismissAction?()
    }

    func requestAccess() {
        invalidateConfirmation()
        requestAccessAction?()
    }

    func grantAccess(_ url: URL) {
        guard !deleting else { return }
        invalidateConfirmation()
        do {
            try checkIdentity()
            guard Self.covers(scope: url, root: rootIdentity.url) else {
                lastError = "Pick the configured folder root or a parent of it: \(rootIdentity.url.path)"
                return
            }
            try bookmarks.save(url, for: folder.id)
            recheckAccess()
            if !accessBlocked, lastError == nil { Task { await loadCandidates() } }
        } catch { lastError = error.localizedDescription }
    }

    private static func covers(scope: URL, root: URL) -> Bool {
        let chosen = scope.standardizedFileURL.resolvingSymlinksInPath().path
        let expected = root.standardizedFileURL.resolvingSymlinksInPath().path
        return chosen == expected || CleanupRootIdentity(scope).matches(root)
            || expected.hasPrefix(chosen.hasSuffix("/") ? chosen : chosen + "/")
    }

    struct AccessContext {
        let scopeURL: URL
        let configuredRoot: URL
    }

    enum AccessProbeResult {
        case granted(AccessContext)
        case needsBookmark
        case notFound(path: String)
        case notADirectory(path: String)
        case other(message: String)
    }

    func recheckAccess() {
        invalidateConfirmation()
        applyProbeResult(probeFolderAccess())
    }

    private func probeFolderAccess() -> AccessProbeResult {
        let path = folder.realPath
        var info = stat()
        let failed = stat(path, &info) != 0
        let code = failed ? errno : 0
        if !failed, (info.st_mode & S_IFMT) != S_IFDIR { return .notADirectory(path: path) }
        if failed, code == ENOENT || code == ENOTDIR { return .notFound(path: path) }
        switch bookmarks.resolve(for: folder.id) {
        case .missing, .failed: return .needsBookmark
        case .resolved(let scope, let stale):
            guard Self.covers(scope: scope, root: rootIdentity.url) else { return .needsBookmark }
            let started = securityScope.start(scope)
            defer { if started { securityScope.stop(scope) } }
            do {
                // Probe the configured root, never just the granted ancestor.
                _ = try FileManager().contentsOfDirectory(atPath: rootIdentity.url.path)
                if stale { bookmarks.refresh(scope, for: folder.id) }
                return .granted(AccessContext(scopeURL: scope, configuredRoot: rootIdentity.url))
            } catch let e as CocoaError where e.code == .fileReadNoPermission { return .needsBookmark
            } catch let e as CocoaError where e.code == .fileReadNoSuchFile { return .notFound(path: path)
            } catch { return .other(message: error.localizedDescription) }
        }
    }

    private func applyProbeResult(_ result: AccessProbeResult) {
        switch result {
        case .granted:
            accessBlocked = false
            if !obsolete { lastError = nil }
        case .needsBookmark:
            accessBlocked = true
        case .notFound(let path):
            accessBlocked = false
            lastError = "Folder root not found on this Mac: \(path). Check Syncthing's folder configuration."
        case .notADirectory(let path):
            accessBlocked = false
            lastError = "Path exists but isn't a directory: \(path)."
        case .other(let message):
            accessBlocked = false
            lastError = "Couldn't access folder root: \(message)"
        }
    }

    func prepareDeletion(selected: Set<String>) -> CleanupConfirmation? {
        guard !loading, !deleting, !selected.isEmpty else { return nil }
        do { try checkIdentity() } catch { return nil }
        let names = candidates.filter { selected.contains($0.id) }.map(\.name)
        guard Set(names) == selected else { return nil }
        let review = CleanupConfirmation(id: UUID(), rootPath: rootIdentity.url.path,
                                         names: names, revision: revision,
                                         authorizationToken: bookmarks.authorizationToken(for: folder.id))
        confirmation = review
        return review
    }

    /// Convenience entry point for callers that have already reviewed their selection.
    /// The window uses the explicit snapshot overload below so its sheet cannot drift.
    func performDeletion(selected: Set<String>) async {
        guard let review = prepareDeletion(selected: selected) else { return }
        await performDeletion(confirmation: review, selected: selected)
    }

    func performDeletion(confirmation review: CleanupConfirmation, selected: Set<String>) async {
        guard !deleting, !loading else { return }
        guard confirmation == review, review.revision == revision,
              selected == Set(review.names),
              Set(candidates.filter { selected.contains($0.id) }.map(\.name)) == selected else {
            invalidateConfirmation()
            lastError = "The selection changed. Review the selected folders again before deleting."
            return
        }
        do { try checkIdentity() } catch { return }
        guard bookmarks.authorizationToken(for: folder.id) == review.authorizationToken else {
            invalidateConfirmation()
            lastError = "Folder access changed. Review the selected folders again before deleting."
            return
        }
        let probe = probeFolderAccess()
        applyProbeResult(probe)
        guard case .granted(let context) = probe else { return }
        // A stale bookmark can be refreshed by our own probe. Subsequent changes
        // from another window/store must invalidate the in-flight authorization.
        let authorizationToken = bookmarks.authorizationToken(for: folder.id)
        let items = candidates.filter { selected.contains($0.id) }
        deleting = true
        let activePermit = CleanupPermit()
        permit = activePermit
        defer { deleting = false; permit = nil; confirmation = nil }
        lastOutcome = nil
        stuckDeletesLog.notice("Cleanup started: \(items.count, privacy: .public) reviewed candidates")
        let started = securityScope.start(context.scopeURL)
        defer { if started { securityScope.stop(context.scopeURL) } }
        var succeeded: Set<String> = []
        var failures: [DeletionOutcome.FailedItem] = []
        var interrupted = false
        for (index, item) in items.enumerated() {
            do {
                try checkIdentity()
                guard activePermit.isValid, revision == review.revision else { throw CleanupSafetyError.obsolete }
                // Both requests are checked across suspension. A cached folder is insufficient.
                let current = try await client.fetchCleanupFolder(id: folder.id, revision: connectionRevision,
                                                                  deviceID: deviceID!)
                try checkIdentity()
                guard rootIdentity.matches(current.realURL), activePermit.isValid else {
                    invalidateIdentity()
                    throw CleanupSafetyError.obsolete
                }
                // Detect cleared/replaced grants between items without silently inheriting them.
                guard bookmarks.authorizationToken(for: folder.id) == authorizationToken,
                      case .resolved(let scope, _) = bookmarks.resolve(for: folder.id),
                      scope.standardizedFileURL == context.scopeURL.standardizedFileURL else {
                    accessBlocked = true
                    throw CocoaError(.fileWriteNoPermission)
                }
                switch await deleteOne(item: item, folderRoot: context.configuredRoot, permit: activePermit) {
                case .success: succeeded.insert(item.id)
                case .failure(let error):
                    failures.append(.init(name: item.name, reason: error.humanReadable))
                    if error == .permissionDenied { accessBlocked = true }
                }
            } catch {
                let reason = isCancellationError(error) ? "Cleanup cancelled; review remaining folders before retrying." : error.localizedDescription
                lastError = reason
                failures += items[index...].map { .init(name: $0.name, reason: reason) }
                interrupted = true
                break
            }
        }
        lastOutcome = DeletionOutcome(succeededCount: succeeded.count, failed: failures)
        stuckDeletesLog.notice("Cleanup finished: \(succeeded.count, privacy: .public) succeeded, \(failures.count, privacy: .public) failed")
        // Preserve failed items and selections even if a subsequent reload fails.
        candidates.removeAll { succeeded.contains($0.id) }
        guard !interrupted else { return }
        do {
            try checkIdentity()
            try await client.rescan(folder: folder.id)
            try checkIdentity()
        } catch {
            stuckDeletesLog.error("Cleanup rescan failed: \(error.localizedDescription, privacy: .public)")
            lastError = "Cleanup finished, but Syncthing could not be rescanned: \(error.localizedDescription)"
            return
        }
        await waitForReconciliation()
        do { try checkIdentity() } catch { return }
        let failedItems = items.filter { !succeeded.contains($0.id) }
        await reloadCandidates()
        for item in failedItems where !candidates.contains(where: { $0.id == item.id }) { candidates.append(item) }
        candidates.sort { $0.name < $1.name }
    }

    private func deleteOne(item: RemoteNeedItem, folderRoot: URL, permit: CleanupPermit) async -> Result<Void, DeletionError> {
        let identity = rootIdentity
        return await withTaskCancellationHandler {
            await Task.detached(priority: .userInitiated) {
                guard permit.isValid, identity.matches(folderRoot),
                      let target = Self.validatePath(item.name, folderRoot: folderRoot) else {
                    return .failure(.invalidPath)
                }
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
                    guard permit.isValid, identity.matches(folderRoot),
                          Self.validatePath(item.name, folderRoot: folderRoot) == target else {
                        return .failure(.invalidPath)
                    }
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
        } onCancel: {
            permit.invalidate()
        }
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
