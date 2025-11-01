import Cocoa
import SwiftUI
import Foundation
import Combine
import Charts

// MARK: - Syncthing Data Models (Corrected)
struct SyncthingSystemStatus: Codable {
    let myID: String
    let tilde: String?
    let uptime: Int
    let version: String?
}

struct SyncthingConfig: Codable {
    let devices: [SyncthingDevice]
    let folders: [SyncthingFolder]
}

struct SyncthingDevice: Codable, Identifiable {
    let deviceID: String
    let name: String
    let addresses: [String]
    
    var id: String { deviceID }
}

struct SyncthingFolder: Codable, Identifiable {
    let id: String
    let label: String
    let path: String
    let devices: [SyncthingFolderDevice]
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

// MARK: - PreferenceKey for dynamic height
struct ViewHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
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
    let maxDataPoints = 60 // Keep 10 minutes of data (60 points at 10s intervals)

    mutating func addDataPoint(downloadRate: Double, uploadRate: Double) {
        let point = TransferDataPoint(
            timestamp: Date(),
            downloadRate: downloadRate,
            uploadRate: uploadRate
        )
        dataPoints.append(point)

        // Remove old data points
        if dataPoints.count > maxDataPoints {
            dataPoints.removeFirst(dataPoints.count - maxDataPoints)
        }
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
            print("Syncthing base URL is invalid or empty.")
            return false
        }
        baseURL = resolvedBaseURL
        
        if settings.useAutomaticDiscovery {
            if cachedAutomaticAPIKey == nil {
                cachedAutomaticAPIKey = loadAutomaticAPIKey()
                if cachedAutomaticAPIKey != nil {
                    print("Successfully loaded API key from config.")
                } else {
                    print("API key could not be loaded. Check Syncthing config.")
                }
            }
            guard let key = cachedAutomaticAPIKey else { return false }
            apiKey = key
        } else {
            guard let manualKey = settings.resolvedManualAPIKey?.trimmingCharacters(in: .whitespacesAndNewlines), !manualKey.isEmpty else {
                print("Manual API key is empty.")
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
    
    func fetchStatus() async {
        do {
            let status = try await makeRequest(endpoint: "system/status", responseType: SyncthingSystemStatus.self)
            await MainActor.run {
                self.systemStatus = status
                self.isConnected = true
            }
        } catch {
            print("Failed to fetch system/status: \(error)")
            await MainActor.run {
                self.isConnected = false
                self.systemStatus = nil
            }
        }
    }
    
    func fetchConfig() async {
        guard let localDeviceID = await MainActor.run(body: { self.systemStatus?.myID }) else { return }
        do {
            let config = try await makeRequest(endpoint: "system/config", responseType: SyncthingConfig.self)
            await MainActor.run {
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

            // Store historical data for charts
            var history = transferHistory[deviceID] ?? DeviceTransferHistory()
            history.addDataPoint(downloadRate: rates.downloadRate, uploadRate: rates.uploadRate)
            transferHistory[deviceID] = history
            deviceTransferHistory[deviceID] = history
        }
    }

    private func updateConnectionHistory(newConnections: [String: SyncthingConnection]) {
        let currentTime = Date()

        for (deviceID, newConnection) in newConnections {
            var history = connectionHistory[deviceID] ?? ConnectionHistory()

            if newConnection.connected {
                // Device is connected
                if !history.isCurrentlyConnected {
                    // Device just connected
                    history.connectedSince = currentTime
                }
                history.lastSeen = currentTime
                history.isCurrentlyConnected = true
            } else {
                // Device is disconnected
                if history.isCurrentlyConnected {
                    // Device just disconnected
                    history.lastSeen = currentTime
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
            }

            previousFolderStates[folder.id] = currentState
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
}

// MARK: - Window Controller
class MainWindowController: NSWindowController {
    convenience init(syncthingClient: SyncthingClient, appDelegate: AppDelegate) {
        let contentView = ContentView(appDelegate: appDelegate, syncthingClient: syncthingClient, isPopover: false)
            .frame(minWidth: 600, idealWidth: 700, minHeight: 500, idealHeight: 600)

        let hostingView = NSHostingView(rootView: contentView)

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: hostingView.intrinsicContentSize),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.title = "Syncthing Status"
        window.center()

        self.init(window: window)
    }
}

// MARK: - AppDelegate
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var windowController: MainWindowController?
    var settingsWindowController: NSWindowController?
    let settings: SyncthingSettings
    let syncthingClient: SyncthingClient
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    override init() {
        let settings = SyncthingSettings()
        self.settings = settings
        self.syncthingClient = SyncthingClient(settings: settings)
        super.init()
        bindClient()
    }
    
    init(settings: SyncthingSettings) {
        self.settings = settings
        self.syncthingClient = SyncthingClient(settings: settings)
        super.init()
        bindClient()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let statusButton = statusItem?.button {
            statusButton.image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: "Loading")?.withSymbolConfiguration(.init(pointSize: 16, weight: .regular))
            statusButton.image?.isTemplate = true
            statusButton.action = #selector(statusItemClicked)
            statusButton.target = self
        }
        
        setupPopover()
        NSApp.setActivationPolicy(.accessory) 
        startMonitoring()
    }
    
    func setupPopover() {
        popover = NSPopover()
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(
            rootView: ContentView(appDelegate: self, syncthingClient: syncthingClient, isPopover: true)
        )
    }

    func updatePopoverSize(height: CGFloat) {
        guard let popover else { return }
        
        let screenPadding: CGFloat = 100.0
        let maxHeight: CGFloat
        
        if let screen = statusItem?.button?.window?.screen {
            maxHeight = screen.visibleFrame.height - screenPadding
        } else if let mainScreen = NSScreen.main {
            maxHeight = mainScreen.visibleFrame.height - screenPadding
        } else {
            maxHeight = 700
        }
        
        let newHeight = min(height, maxHeight)
        let newSize = NSSize(width: 400, height: newHeight)
        
        if popover.contentSize != newSize {
            popover.contentSize = newSize
        }
    }
    
    private func startMonitoring() {
        Task {
            await syncthingClient.refresh()
            await MainActor.run { self.updateStatusIcon() }
        }
        
        timer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
            Task {
                await self.syncthingClient.refresh()
                await MainActor.run { self.updateStatusIcon() }
            }
        }
    }
    
    func updateStatusIcon() {
        guard let statusButton = statusItem?.button else { return }
        
        let iconName: String
        let accessibilityDescription: String
        
        if !syncthingClient.isConnected {
            iconName = "exclamationmark.triangle.fill"
            accessibilityDescription = "Disconnected"
        } else {
            let isSyncing = syncthingClient.deviceCompletions.values.contains { $0.completion < 100 } ||
                            syncthingClient.folderStatuses.values.contains { $0.state == "syncing" }
            let allFoldersIdle = syncthingClient.folderStatuses.values.allSatisfy { $0.state == "idle" && $0.needFiles == 0 }

            if isSyncing {
                iconName = "arrow.triangle.2.circlepath"
                accessibilityDescription = "Syncing"
            } else if allFoldersIdle {
                iconName = "checkmark.circle.fill"
                accessibilityDescription = "Synced"
            } else {
                iconName = "pause.circle.fill"
                accessibilityDescription = "Paused or Out of Sync"
            }
        }
        statusButton.image = NSImage(systemSymbolName: iconName, accessibilityDescription: accessibilityDescription)
        statusButton.image?.isTemplate = true
    }
    
    @objc func statusItemClicked() {
        guard let statusButton = statusItem?.button else { return }
        
        if let popover, popover.isShown {
            closePopover()
        } else {
            showPopover(statusButton)
        }
    }
    
    @objc func openMainWindow() {
        closePopover()
        
        if windowController == nil {
            windowController = MainWindowController(syncthingClient: syncthingClient, appDelegate: self)
            windowController?.window?.delegate = self
        }
        
        NSApp.setActivationPolicy(.regular)
        windowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func showPopover(_ sender: NSButton) {
        popover?.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
    }
    
    func closePopover() {
        popover?.performClose(nil)
    }
    
    @objc func openSettings() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        let selectors = ["showSettingsWindow:", "showPreferencesWindow:", "orderFrontSettingsWindow:"]
        for name in selectors {
            let selector = Selector(name)
            if NSApp.sendAction(selector, to: nil, from: nil) {
                return
            }
        }
        presentFallbackSettingsWindow()
    }
    
    func quit() {
        timer?.invalidate()
        NSApplication.shared.terminate(nil)
    }
    
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        if window === windowController?.window {
            NSApp.setActivationPolicy(.accessory)
            windowController = nil
        } else if window === settingsWindowController?.window {
            settingsWindowController = nil
            if windowController == nil {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }
    
    private func bindClient() {
        syncthingClient.$isConnected
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateStatusIcon() }
            .store(in: &cancellables)
        
        syncthingClient.$deviceCompletions
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateStatusIcon() }
            .store(in: &cancellables)
        
        syncthingClient.$folderStatuses
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateStatusIcon() }
            .store(in: &cancellables)
    }
    
    private func presentFallbackSettingsWindow() {
        if let controller = settingsWindowController {
            controller.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let hostingController = NSHostingController(rootView: SettingsView(settings: settings))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 380),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.contentViewController = hostingController
        window.center()
        
        let controller = NSWindowController(window: window)
        controller.window?.delegate = self
        settingsWindowController = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - Helper Functions
private func formatUptime(_ seconds: Int) -> String {
    let duration = TimeInterval(seconds)
    let formatter = DateComponentsFormatter()
    formatter.unitsStyle = .abbreviated
    formatter.allowedUnits = [.day, .hour, .minute]
    return formatter.string(from: duration) ?? "0m"
}

// Corrected to handle Int64
private func formatBytes(_ bytes: Int64) -> String {
    let bcf = ByteCountFormatter()
    bcf.allowedUnits = [.useAll]
    bcf.countStyle = .file
    return bcf.string(fromByteCount: bytes)
}

private func formatTransferRate(_ bytesPerSecond: Double) -> String {
    if bytesPerSecond < 1 {
        return "0 B/s"
    }
    let bcf = ByteCountFormatter()
    bcf.allowedUnits = [.useAll]
    bcf.countStyle = .binary
    return bcf.string(fromByteCount: Int64(bytesPerSecond)) + "/s"
}

private func formatRelativeTime(since date: Date) -> String {
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

private func formatConnectionDuration(since date: Date?) -> String {
    guard let date = date else { return "Not connected" }
    let interval = Date().timeIntervalSince(date)
    let formatter = DateComponentsFormatter()
    formatter.unitsStyle = .abbreviated
    formatter.allowedUnits = [.day, .hour, .minute]
    formatter.maximumUnitCount = 2
    return formatter.string(from: interval) ?? "0m"
}

private func hasSignificantActivity(history: DeviceTransferHistory) -> Bool {
    // Only show chart if there's been meaningful transfer activity
    // Minimum threshold: 1 KB/s peak speed
    let minThreshold: Double = 1024 // 1 KB/s in bytes/sec
    let maxDown = history.dataPoints.map { $0.downloadRate }.max() ?? 0
    let maxUp = history.dataPoints.map { $0.uploadRate }.max() ?? 0
    return max(maxDown, maxUp) >= minThreshold
}

// MARK: - ContentView
struct ContentView: View {
    weak var appDelegate: AppDelegate?
    @ObservedObject var syncthingClient: SyncthingClient
    var isPopover: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            HeaderView(isConnected: syncthingClient.isConnected) {
                Task { await syncthingClient.refresh() }
            }
            .padding([.top, .horizontal])
            
            Divider().padding(.vertical, 8)
            
            if !syncthingClient.isConnected {
                DisconnectedView {
                    appDelegate?.openSettings()
                }
            } else {
                let statusContent = VStack(spacing: 16) {
                    if let status = syncthingClient.systemStatus {
                        SystemStatusView(status: status, isPopover: isPopover)
                    }

                    if !isPopover {
                        SystemStatisticsView(syncthingClient: syncthingClient)
                    }

                    VStack(spacing: 16) {
                        RemoteDevicesView(syncthingClient: syncthingClient, isPopover: isPopover)
                        FolderSyncStatusView(syncthingClient: syncthingClient, isPopover: isPopover)

                        if !isPopover {
                            // Show transfer speed charts for connected devices with significant data
                            ForEach(syncthingClient.devices) { device in
                                if let history = syncthingClient.deviceTransferHistory[device.deviceID],
                                   !history.dataPoints.isEmpty,
                                   syncthingClient.connections[device.deviceID]?.connected == true,
                                   hasSignificantActivity(history: history) {
                                    TransferSpeedChartView(deviceName: device.name, history: history)
                                }
                            }

                            if !syncthingClient.recentSyncEvents.isEmpty {
                                SyncHistoryView(events: syncthingClient.recentSyncEvents)
                            }
                        }
                    }
                }
                .padding(.horizontal)

                if isPopover {
                    statusContent
                } else {
                    ScrollView {
                        statusContent
                    }
                }
            }
            
            Spacer(minLength: 0)
            
            if let appDelegate = appDelegate {
                FooterView(appDelegate: appDelegate, isConnected: syncthingClient.isConnected, isPopover: isPopover)
                    .padding()
            }
        }
        .background(
            GeometryReader { geometry in
                Color.clear.preference(key: ViewHeightKey.self, value: geometry.size.height)
            }
        )
        .onPreferenceChange(ViewHeightKey.self) { newHeight in
            if isPopover {
                appDelegate?.updatePopoverSize(height: newHeight)
            }
        }
        .frame(width: isPopover ? 400 : nil)
    }
}

// MARK: - Component Views
struct HeaderView: View {
    let isConnected: Bool
    let onRefresh: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: isConnected ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(isConnected ? .green : .red)
            Text("Syncthing Monitor").font(.headline)
            Spacer()
            Button("Refresh", action: onRefresh).buttonStyle(.bordered).controlSize(.small)
        }
    }
}

struct DisconnectedView: View {
    let openSettings: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "wifi.slash").font(.largeTitle).foregroundColor(.red)
            Text("Syncthing Not Connected").font(.title3).fontWeight(.medium)
            Text("Make sure Syncthing is running and the API key is set.")
                .font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center)
            Button("Open Syncthing Web UI") {
                if let url = URL(string: "http://127.0.0.1:8384") { NSWorkspace.shared.open(url) }
            }.buttonStyle(.borderedProminent)
            if #available(macOS 13.0, *) {
                SettingsLink {
                    Text("Open Settings")
                }
                .buttonStyle(.bordered)
            } else {
                Button("Open Settings", action: openSettings)
                    .buttonStyle(.bordered)
            }
            Spacer()
        }
    }
}

struct FooterView: View {
    let appDelegate: AppDelegate
    let isConnected: Bool
    let isPopover: Bool

    var body: some View {
        HStack {
            Button("Open Web UI") {
                if let url = URL(string: "http://127.0.0.1:8384") { NSWorkspace.shared.open(url) }
            }.disabled(!isConnected)
            
            if #available(macOS 13.0, *) {
                SettingsLink {
                    Text("Settings")
                }
                .buttonStyle(.bordered)
            } else {
                Button("Settings") {
                    appDelegate.openSettings()
                }
                .buttonStyle(.bordered)
            }
            
            Spacer()
            
            if isPopover {
                Button("Open in Window") {
                    appDelegate.openMainWindow()
                }
                .buttonStyle(.bordered)
            }
            
            Button("Quit") { appDelegate.quit() }.foregroundColor(.red)
        }
    }
}

struct SystemStatusView: View {
    let status: SyncthingSystemStatus
    var isPopover: Bool = true

    var body: some View {
        GroupBox("System Status") {
            VStack(spacing: 8) {
                HStack {
                    Text("Device ID:").fontWeight(.medium)
                    Spacer()
                    if isPopover {
                        Text(String(status.myID.prefix(12)) + "...").font(.system(.caption, design: .monospaced))
                    } else {
                        Text(status.myID).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                    }
                }
                Divider()
                HStack {
                    Text("Uptime:").fontWeight(.medium)
                    Spacer()
                    Text(formatUptime(status.uptime))
                }
                if !isPopover, let version = status.version {
                    Divider()
                    HStack {
                        Text("Version:").fontWeight(.medium)
                        Spacer()
                        Text(version)
                    }
                }
            }
        }
    }
}

struct SystemStatisticsView: View {
    @ObservedObject var syncthingClient: SyncthingClient

    var body: some View {
        GroupBox("System Statistics") {
            VStack(spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total Folders")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(syncthingClient.folders.count)")
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Connected Devices")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(syncthingClient.totalDevicesConnected) / \(syncthingClient.devices.count)")
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                }

                Divider()

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Local Data")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatBytes(syncthingClient.totalSyncedData))
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Global Data")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatBytes(syncthingClient.totalGlobalData))
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                }

                Divider()

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total Received")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatBytes(syncthingClient.totalDataReceived))
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Total Sent")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatBytes(syncthingClient.totalDataSent))
                            .font(.subheadline)
                            .foregroundColor(.green)
                    }
                }

                if syncthingClient.currentDownloadSpeed > 0 || syncthingClient.currentUploadSpeed > 0 {
                    Divider()
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Current Download")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formatTransferRate(syncthingClient.currentDownloadSpeed))
                                .font(.subheadline)
                                .foregroundColor(.blue)
                                .fontWeight(.medium)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Current Upload")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formatTransferRate(syncthingClient.currentUploadSpeed))
                                .font(.subheadline)
                                .foregroundColor(.green)
                                .fontWeight(.medium)
                        }
                    }
                }
            }
        }
    }
}

struct RemoteDevicesView: View {
    @ObservedObject var syncthingClient: SyncthingClient
    var isPopover: Bool = true

    var body: some View {
        GroupBox("Remote Devices") {
            if syncthingClient.devices.isEmpty {
                Text("No remote devices configured").foregroundColor(.secondary).padding(.vertical, 4)
            } else {
                VStack(spacing: 12) {
                    ForEach(syncthingClient.devices) { device in
                        DeviceStatusRow(
                            device: device,
                            connection: syncthingClient.connections[device.deviceID],
                            completion: syncthingClient.deviceCompletions[device.deviceID],
                            transferRates: syncthingClient.transferRates[device.deviceID],
                            connectionHistory: syncthingClient.deviceHistory[device.deviceID],
                            isDetailed: !isPopover
                        )
                    }
                }
            }
        }
    }
}

struct FolderSyncStatusView: View {
    @ObservedObject var syncthingClient: SyncthingClient
    var isPopover: Bool = true

    var body: some View {
        GroupBox("Folder Sync Status") {
            if syncthingClient.folders.isEmpty {
                Text("No folders configured").foregroundColor(.secondary).padding(.vertical, 4)
            } else {
                VStack(spacing: 12) {
                    ForEach(syncthingClient.folders) { folder in
                        FolderStatusRow(folder: folder, status: syncthingClient.folderStatuses[folder.id], isDetailed: !isPopover)
                    }
                }
            }
        }
    }
}

struct SyncHistoryView: View {
    let events: [SyncEvent]
    @State private var showAll = false

    var body: some View {
        GroupBox("Recent Sync Activity") {
            if events.isEmpty {
                Text("No sync activity yet").foregroundColor(.secondary).padding(.vertical, 4)
            } else {
                VStack(spacing: 8) {
                    let displayEvents = showAll ? events : Array(events.prefix(5))
                    ForEach(displayEvents) { event in
                        SyncEventRow(event: event)
                    }

                    if events.count > 5 {
                        Button(showAll ? "Show Less" : "Show All (\(events.count))") {
                            showAll.toggle()
                        }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.top, 4)
                    }
                }
            }
        }
    }
}

struct SyncEventRow: View {
    let event: SyncEvent

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            eventIcon
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(event.folderName)
                        .font(.caption)
                        .fontWeight(.medium)
                    Spacer()
                    Text(formatRelativeTime(since: event.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Text(eventDescription)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var eventIcon: some View {
        Group {
            switch event.eventType {
            case .syncStarted:
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundColor(.blue)
            case .syncCompleted:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .idle:
                Image(systemName: "pause.circle")
                    .foregroundColor(.orange)
            }
        }
        .font(.caption)
    }

    private var eventDescription: String {
        switch event.eventType {
        case .syncStarted:
            return event.details ?? "Started syncing"
        case .syncCompleted:
            return event.details ?? "Sync completed"
        case .idle:
            return event.details ?? "Paused"
        }
    }
}

struct TransferSpeedChartView: View {
    let deviceName: String
    let history: DeviceTransferHistory

    private var maxSpeed: Double {
        let maxDown = history.dataPoints.map { $0.downloadRate }.max() ?? 0
        let maxUp = history.dataPoints.map { $0.uploadRate }.max() ?? 0
        let maxValue = max(maxDown, maxUp) / 1024 // Convert to KB/s
        // Add 20% padding to max value for better visualization
        return maxValue * 1.2
    }

    var body: some View {
        GroupBox("\(deviceName) - Transfer Speed") {
            if history.dataPoints.isEmpty {
                Text("No data yet").foregroundColor(.secondary).padding(.vertical, 20)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Chart {
                        ForEach(history.dataPoints) { point in
                            LineMark(
                                x: .value("Time", point.timestamp),
                                y: .value("Download", point.downloadRate / 1024)
                            )
                            .foregroundStyle(.blue)
                            .interpolationMethod(.catmullRom)
                            .lineStyle(StrokeStyle(lineWidth: 2))

                            AreaMark(
                                x: .value("Time", point.timestamp),
                                y: .value("Download", point.downloadRate / 1024)
                            )
                            .foregroundStyle(.blue.opacity(0.1))
                            .interpolationMethod(.catmullRom)

                            LineMark(
                                x: .value("Time", point.timestamp),
                                y: .value("Upload", point.uploadRate / 1024)
                            )
                            .foregroundStyle(.green)
                            .interpolationMethod(.catmullRom)
                            .lineStyle(StrokeStyle(lineWidth: 2))

                            AreaMark(
                                x: .value("Time", point.timestamp),
                                y: .value("Upload", point.uploadRate / 1024)
                            )
                            .foregroundStyle(.green.opacity(0.1))
                            .interpolationMethod(.catmullRom)
                        }
                    }
                    .chartYScale(domain: 0...max(maxSpeed, 1))
                    .chartYAxis {
                        AxisMarks(position: .leading, values: .automatic(desiredCount: 4))
                    }
                    .chartYAxisLabel("KB/s", position: .leading)
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 5)) { value in
                            if let date = value.as(Date.self) {
                                AxisValueLabel {
                                    Text(date, format: .dateTime.hour().minute())
                                        .font(.caption2)
                                }
                            }
                        }
                    }
                    .frame(height: 150)

                    HStack(spacing: 16) {
                        Label("Download", systemImage: "arrow.down.circle.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                        Label("Upload", systemImage: "arrow.up.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                    .padding(.top, 4)
                }
                .padding(.vertical, 8)
            }
        }
    }
}

// MARK: - Row Views
struct DeviceStatusRow: View {
    let device: SyncthingDevice
    let connection: SyncthingConnection?
    let completion: SyncthingDeviceCompletion?
    let transferRates: TransferRates?
    let connectionHistory: ConnectionHistory?
    var isDetailed: Bool = false

    var body: some View {
        if isDetailed {
            detailedView
        } else {
            compactView
        }
    }

    private var compactView: some View {
        HStack {
            Circle().fill(connection?.connected == true ? .green : .red).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name).fontWeight(.medium)
                Text(String(device.deviceID.prefix(12)) + "...").font(.system(.caption, design: .monospaced)).foregroundColor(.secondary)
            }
            Spacer()
            if let connection, connection.connected {
                if let completion, completion.completion < 100 {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Syncing (\(Int(completion.completion))%)").font(.caption).foregroundColor(.blue)
                        if let rates = transferRates, rates.downloadRate > 0 {
                            Text("↓ \(formatTransferRate(rates.downloadRate))").font(.caption2).foregroundColor(.blue)
                        } else {
                            Text("~ \(formatBytes(completion.needBytes)) left").font(.caption2).foregroundColor(.secondary)
                        }
                    }
                } else {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Up to date").font(.caption).foregroundColor(.green)
                        if let version = connection.clientVersion {
                            Text(version).font(.caption2).foregroundColor(.secondary)
                        }
                    }
                }
            } else {
                Text("Disconnected").font(.caption).foregroundColor(.red)
            }
        }
    }

    private var detailedView: some View {
        DisclosureGroup {
            VStack(spacing: 6) {
                InfoRow(label: "Device ID", value: device.deviceID, isMonospaced: true)

                if let connection, connection.connected {
                    if let address = connection.address {
                        InfoRow(label: "Address", value: address, isMonospaced: true)
                    }
                    if let type = connection.type {
                        InfoRow(label: "Connection Type", value: type)
                    }
                    if let version = connection.clientVersion {
                        InfoRow(label: "Client Version", value: version)
                    }

                    Divider()

                    InfoRow(label: "Data Received", value: formatBytes(connection.inBytesTotal))
                    InfoRow(label: "Data Sent", value: formatBytes(connection.outBytesTotal))

                    if let rates = transferRates {
                        if rates.downloadRate > 0 || rates.uploadRate > 0 {
                            Divider()
                            if rates.downloadRate > 0 {
                                InfoRow(label: "Download Speed", value: formatTransferRate(rates.downloadRate), isHighlighted: true)
                            }
                            if rates.uploadRate > 0 {
                                InfoRow(label: "Upload Speed", value: formatTransferRate(rates.uploadRate), isHighlighted: true)
                            }
                        }
                    }

                    if let completion {
                        Divider()
                        InfoRow(label: "Completion", value: String(format: "%.2f%%", completion.completion))
                        if completion.needBytes > 0 {
                            InfoRow(label: "Remaining", value: formatBytes(completion.needBytes))
                        }
                    }

                    if let history = connectionHistory {
                        Divider()
                        if let connectedSince = history.connectedSince {
                            InfoRow(label: "Connected For", value: formatConnectionDuration(since: connectedSince))
                        }
                    }
                } else {
                    if !device.addresses.isEmpty {
                        InfoRow(label: "Addresses", value: device.addresses.joined(separator: ", "))
                    }

                    if let history = connectionHistory, let lastSeen = history.lastSeen {
                        Divider()
                        InfoRow(label: "Last Seen", value: formatRelativeTime(since: lastSeen))
                    }
                }
            }
            .padding(.vertical, 4)
        } label: {
            HStack {
                Circle().fill(connection?.connected == true ? .green : .red).frame(width: 10, height: 10)
                Text(device.name).font(.headline)
                Spacer()
                if let connection, connection.connected {
                    if let completion, completion.completion < 100 {
                        Text("Syncing (\(Int(completion.completion))%)").font(.subheadline).foregroundColor(.blue)
                    } else {
                        Text("Up to date").font(.subheadline).foregroundColor(.green)
                    }
                } else {
                    Text("Disconnected").font(.subheadline).foregroundColor(.red)
                }
            }
        }
    }
}

// MARK: - Helper View for Info Rows
struct InfoRow: View {
    let label: String
    let value: String
    var isMonospaced: Bool = false
    var isHighlighted: Bool = false

    var body: some View {
        HStack(alignment: .top) {
            Text(label + ":")
                .fontWeight(.medium)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)
            if isMonospaced {
                Text(value)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .foregroundColor(isHighlighted ? .blue : .primary)
            } else {
                Text(value)
                    .font(.caption)
                    .fontWeight(isHighlighted ? .semibold : .regular)
                    .foregroundColor(isHighlighted ? .blue : .primary)
            }
            Spacer()
        }
    }
}

struct FolderStatusRow: View {
    let folder: SyncthingFolder
    let status: SyncthingFolderStatus?
    var isDetailed: Bool = false

    var body: some View {
        if isDetailed {
            detailedView
        } else {
            compactView
        }
    }

    private var compactView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                statusIcon
                VStack(alignment: .leading, spacing: 2) {
                    Text(folder.label.isEmpty ? folder.id : folder.label).fontWeight(.medium)
                    Text(folder.path).font(.caption).foregroundColor(.secondary).lineLimit(1)
                }
                Spacer()
                if let status {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(status.state.capitalized).font(.caption).foregroundColor(statusColor)
                        if status.needFiles > 0 {
                            Text("\(status.needFiles) items, \(formatBytes(status.needBytes))").font(.caption2).foregroundColor(.orange)
                        } else {
                            Text("Up to date").font(.caption2).foregroundColor(.green)
                        }
                    }
                }
            }
            if let status, status.state == "syncing", status.needBytes > 0 {
                let total = Double(status.globalBytes)
                let current = Double(status.localBytes)
                if total > 0 {
                    ProgressView(value: current / total).progressViewStyle(.linear)
                }
            }
        }
    }

    private var detailedView: some View {
        DisclosureGroup {
            VStack(spacing: 6) {
                InfoRow(label: "Path", value: folder.path)

                if let status {
                    Divider()
                    InfoRow(label: "Global Files", value: "\(status.globalFiles) files")
                    InfoRow(label: "Global Size", value: formatBytes(status.globalBytes))

                    Divider()
                    InfoRow(label: "Local Files", value: "\(status.localFiles) files")
                    InfoRow(label: "Local Size", value: formatBytes(status.localBytes))

                    if status.needFiles > 0 {
                        Divider()
                        InfoRow(label: "Need to Sync", value: "\(status.needFiles) files")
                        InfoRow(label: "Need to Sync Size", value: formatBytes(status.needBytes))
                    }

                    if status.state == "syncing", status.needBytes > 0 {
                        let total = Double(status.globalBytes)
                        let current = Double(status.localBytes)
                        if total > 0 {
                            Divider()
                            let percentage = (current / total) * 100
                            InfoRow(label: "Progress", value: String(format: "%.2f%%", percentage))
                            ProgressView(value: current / total).progressViewStyle(.linear)
                                .padding(.vertical, 4)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        } label: {
            HStack {
                statusIcon
                VStack(alignment: .leading, spacing: 2) {
                    Text(folder.label.isEmpty ? folder.id : folder.label).font(.headline)
                    if let status {
                        HStack(spacing: 4) {
                            Text("\(status.localFiles) files")
                            Text("•")
                            Text(formatBytes(status.localBytes))
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
                Spacer()
                if let status {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(status.state.capitalized).font(.subheadline).foregroundColor(statusColor)
                        if status.needFiles > 0 {
                            Text("\(status.needFiles) items pending").font(.caption2).foregroundColor(.orange)
                        } else {
                            Text("Up to date").font(.caption2).foregroundColor(.green)
                        }
                    }
                }
            }
        }
    }
    
    private var statusIcon: some View {
        Group {
            if let status {
                switch status.state {
                case "idle" where status.needFiles > 0: Image(systemName: "pause.circle.fill").foregroundColor(.orange)
                case "idle": Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                case "syncing": Image(systemName: "arrow.triangle.2.circlepath").foregroundColor(.blue)
                case "scanning": Image(systemName: "magnifyingglass").foregroundColor(.blue)
                default: Image(systemName: "questionmark.circle").foregroundColor(.gray)
                }
            } else {
                Image(systemName: "exclamationmark.triangle").foregroundColor(.red)
            }
        }
    }
    
    private var statusColor: Color {
        guard let status else { return .red }
        switch status.state {
        case "idle" where status.needFiles > 0: return .orange
        case "idle": return .green
        case "syncing", "scanning": return .blue
        default: return .gray
        }
    }
}

struct SettingsView: View {
    @ObservedObject var settings: SyncthingSettings
    @State private var showResetConfirmation = false
    
    private var isManualMode: Bool {
        !settings.useAutomaticDiscovery
    }
    
    var body: some View {
        Form {
            Section("Connection Mode") {
                Toggle("Discover API key from Syncthing config.xml", isOn: $settings.useAutomaticDiscovery)
                Text("Turn this off to point the app at a different Syncthing instance.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("Manual Configuration") {
                TextField("Base URL", text: $settings.baseURLString, prompt: Text("http://127.0.0.1:8384"))
                    .textFieldStyle(.roundedBorder)
                SecureField("API Key", text: $settings.manualAPIKey)
                    .textFieldStyle(.roundedBorder)
                Text("Stored securely in your login Keychain.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .disabled(!isManualMode)
            
            Section {
                Button("Reset to Defaults", role: .destructive) {
                    showResetConfirmation = true
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .padding(20)
        .alert("Reset Settings", isPresented: $showResetConfirmation) {
            Button("Reset", role: .destructive) { settings.resetToDefaults() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will restore the built-in localhost configuration and clear any manual API key.")
        }
    }
}

// MARK: - SwiftUI Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let previewDefaults = UserDefaults(suiteName: "PreviewSyncthingSettings") ?? .standard
        let settings = SyncthingSettings(defaults: previewDefaults, keychainService: "PreviewSyncthingSettings")
        settings.useAutomaticDiscovery = false
        settings.baseURLString = "http://127.0.0.1:8384"
        settings.manualAPIKey = "PREVIEW-KEY"
        
        let appDelegate = AppDelegate(settings: settings)
        let client = appDelegate.syncthingClient
        
        client.isConnected = true
        // Updated preview data
        client.systemStatus = .init(myID: "PREVIEW-ID", tilde: "~", uptime: 12345, version: "v1.23.4")
        client.devices = [
            .init(deviceID: "DEVICE1-ID", name: "PLEXmini", addresses: []),
            .init(deviceID: "DEVICE2-ID", name: "M1max", addresses: []),
            .init(deviceID: "DEVICE3-ID", name: "Another Device", addresses: [])
        ]
        client.folders = [
            .init(id: "folder1", label: "Xcode Projects", path: "/Users/sim/XcodeProjects", devices: []),
            .init(id: "folder2", label: "SYNCSim", path: "/Users/sim/SYNCSim", devices: []),
            .init(id: "folder3", label: "Documents", path: "/Users/sim/Documents", devices: [])
        ]
        client.connections = [
            "DEVICE1-ID": .init(connected: true, address: "1.2.3.4", clientVersion: "v1.30.0", type: "TCP", inBytesTotal: 0, outBytesTotal: 0),
            "DEVICE2-ID": .init(connected: false, address: nil, clientVersion: nil, type: nil, inBytesTotal: 0, outBytesTotal: 0),
            "DEVICE3-ID": .init(connected: true, address: "5.6.7.8", clientVersion: "v1.29.0", type: "QUIC", inBytesTotal: 0, outBytesTotal: 0)
        ]
        client.deviceCompletions = [
            "DEVICE1-ID": .init(completion: 99.5, globalBytes: 1000, needBytes: 5)
        ]
        client.folderStatuses = [
            "folder1": .init(globalFiles: 10, globalBytes: 10000, localFiles: 10, localBytes: 10000, needFiles: 0, needBytes: 0, state: "idle", lastScan: "2023-01-01T12:00:00Z"),
            "folder2": .init(globalFiles: 20, globalBytes: 20000, localFiles: 15, localBytes: 15000, needFiles: 5, needBytes: 5000, state: "syncing", lastScan: "2023-01-01T12:00:00Z")
        ]
        
        return ContentView(appDelegate: appDelegate, syncthingClient: client, isPopover: true)
    }
}

// MARK: - Main App Structure
@main
struct SyncthingStatusApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            SettingsView(settings: appDelegate.settings)
        }
    }
}
