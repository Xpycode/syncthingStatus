import Cocoa
import SwiftUI
import Foundation

// MARK: - Syncthing Data Models
struct SyncthingStatus: Codable {
    let myID: String
    let tilde: String
    let uptime: Int
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
}

struct SyncthingConnections: Codable {
    let connections: [String: SyncthingConnection]
}

struct SyncthingFolderStatus: Codable {
    let globalFiles: Int
    let globalBytes: Int
    let localFiles: Int
    let localBytes: Int
    let needFiles: Int
    let needBytes: Int
    let state: String
    let stateChanged: String
}

struct SyncthingDeviceCompletion: Codable {
    let completion: Double
    let globalBytes: Int
    let needBytes: Int
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
    var apiKey: String?

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        if elementName == "apikey" {
            isApiKeyTag = true
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if isApiKeyTag {
            apiKey = string
            isApiKeyTag = false
        }
    }
}


// MARK: - Syncthing API Client
class SyncthingClient: ObservableObject {
    private let baseURL = "http://127.0.0.1:8384"
    private let session = URLSession.shared
    @Published var isConnected = false
    @Published var devices: [SyncthingDevice] = []
    @Published var folders: [SyncthingFolder] = []
    @Published var connections: [String: SyncthingConnection] = [:]
    @Published var folderStatuses: [String: SyncthingFolderStatus] = [:]
    @Published var systemStatus: SyncthingStatus?
    @Published var deviceCompletions: [String: SyncthingDeviceCompletion] = [:]
    
    private var apiKey: String?
    
    init() {
        loadAPIKey()
        if apiKey == nil {
            print("API key could not be loaded. Check Syncthing config.")
        } else {
            print("Successfully loaded API key from config.")
        }
    }
    
    private func loadAPIKey() {
        let fileManager = FileManager.default
        let homeDir = fileManager.homeDirectoryForCurrentUser
        
        let standardConfigPath = homeDir.appendingPathComponent("Library/Application Support/Syncthing/config.xml")
        let alternativeConfigPath = homeDir.appendingPathComponent(".config/syncthing/config.xml")

        var configPath: URL?
        
        if fileManager.fileExists(atPath: standardConfigPath.path) {
            configPath = standardConfigPath
        } else if fileManager.fileExists(atPath: alternativeConfigPath.path) {
            configPath = alternativeConfigPath
        }
        
        guard let finalPath = configPath else { return }
        guard let xmlData = try? Data(contentsOf: finalPath) else { return }
        
        let parser = XMLParser(data: xmlData)
        let delegate = ApiKeyParserDelegate()
        parser.delegate = delegate
        
        if parser.parse(), let key = delegate.apiKey {
            self.apiKey = key
        } else {
            print("Failed to parse or find API key in config.xml.")
        }
    }
    
    private func makeRequest<T: Codable>(endpoint: String, responseType: T.Type) async throws -> T {
        guard let url = URL(string: "\(baseURL)/rest/\(endpoint)") else { throw URLError(.badURL) }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        guard let apiKey = apiKey else { throw URLError(.userAuthenticationRequired) }
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    func fetchStatus() async {
        do {
            let status = try await makeRequest(endpoint: "system/status", responseType: SyncthingStatus.self)
            await MainActor.run {
                self.systemStatus = status
                self.isConnected = true
            }
        } catch {
            await MainActor.run { self.isConnected = false }
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
        } catch { print("Failed to fetch config: \(error)") }
    }
    
    func fetchConnections() async {
        do {
            let connectionsResponse = try await makeRequest(endpoint: "system/connections", responseType: SyncthingConnections.self)
            await MainActor.run { self.connections = connectionsResponse.connections }
        } catch { print("Failed to fetch connections: \(error)") }
    }
    
    func fetchFolderStatus() async {
        let foldersToFetch = await MainActor.run { self.folders }
        for folder in foldersToFetch {
            do {
                let status = try await makeRequest(endpoint: "db/status?folder=\(folder.id)", responseType: SyncthingFolderStatus.self)
                await MainActor.run { self.folderStatuses[folder.id] = status }
            } catch { print("Failed to fetch status for folder \(folder.id): \(error)") }
        }
    }
    
    func fetchDeviceCompletions() async {
        let devicesToFetch = await MainActor.run { self.devices }
        for device in devicesToFetch {
            do {
                let completion = try await makeRequest(endpoint: "db/completion?device=\(device.deviceID)", responseType: SyncthingDeviceCompletion.self)
                await MainActor.run { self.deviceCompletions[device.deviceID] = completion }
            } catch { print("Failed to fetch completion for device \(device.deviceID): \(error)") }
        }
    }
    
    func refresh() async {
        guard apiKey != nil else {
            await MainActor.run { self.isConnected = false }
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

// MARK: - AppDelegate
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    lazy var syncthingClient = SyncthingClient()
    private var timer: Timer?
    
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
            rootView: ContentView(appDelegate: self, syncthingClient: syncthingClient)
        )
    }

    func updatePopoverSize(height: CGFloat) {
        guard let popover else { return }
        
        // Determine max height based on the screen the status item is on.
        // Add some padding so the popover doesn't touch the screen edges.
        let screenPadding: CGFloat = 100.0
        let maxHeight: CGFloat
        
        if let screen = statusItem?.button?.window?.screen {
            maxHeight = screen.visibleFrame.height - screenPadding
        } else if let mainScreen = NSScreen.main {
            // Fallback to main screen
            maxHeight = mainScreen.visibleFrame.height - screenPadding
        } else {
            // Absolute fallback if no screen info is available
            maxHeight = 700
        }
        
        let newHeight = min(height, maxHeight)
        let newSize = NSSize(width: 400, height: newHeight)
        
        // Only resize if the new size is different, to avoid unnecessary redraws
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
    
    func showPopover(_ sender: NSButton) {
        popover?.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
    }
    
    func closePopover() {
        popover?.performClose(nil)
    }
    
    func quit() {
        timer?.invalidate()
        NSApplication.shared.terminate(nil)
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

private func formatBytes(_ bytes: Int) -> String {
    let bcf = ByteCountFormatter()
    bcf.allowedUnits = [.useAll]
    bcf.countStyle = .file
    return bcf.string(fromByteCount: Int64(bytes))
}

// MARK: - ContentView
struct ContentView: View {
    let appDelegate: AppDelegate
    @ObservedObject var syncthingClient: SyncthingClient
    
    var body: some View {
        VStack(spacing: 0) {
            HeaderView(isConnected: syncthingClient.isConnected) {
                Task { await syncthingClient.refresh() }
            }
            .padding([.top, .horizontal])
            
            Divider().padding(.vertical, 8)
            
            if !syncthingClient.isConnected {
                DisconnectedView()
            } else {
                VStack(spacing: 16) {
                    if let status = syncthingClient.systemStatus {
                        SystemStatusView(status: status)
                    }
                    
                    VStack(spacing: 16) {
                        RemoteDevicesView(syncthingClient: syncthingClient)
                        FolderSyncStatusView(syncthingClient: syncthingClient)
                    }
                }
                .padding(.horizontal)
            }
            
            Spacer(minLength: 0)
            
            FooterView(appDelegate: appDelegate, isConnected: syncthingClient.isConnected)
                .padding()
        }
        .background(
            GeometryReader { geometry in
                Color.clear.preference(key: ViewHeightKey.self, value: geometry.size.height)
            }
        )
        .onPreferenceChange(ViewHeightKey.self) { newHeight in
            appDelegate.updatePopoverSize(height: newHeight)
        }
        .frame(width: 400) // Keep a fixed width
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
            Spacer()
        }
    }
}

struct FooterView: View {
    let appDelegate: AppDelegate
    let isConnected: Bool
    
    var body: some View {
        HStack {
            Button("Open Web UI") {
                if let url = URL(string: "http://127.0.0.1:8384") { NSWorkspace.shared.open(url) }
            }.disabled(!isConnected)
            Spacer()
            Button("Quit") { appDelegate.quit() }.foregroundColor(.red)
        }
    }
}

struct SystemStatusView: View {
    let status: SyncthingStatus
    
    var body: some View {
        GroupBox("System Status") {
            VStack(spacing: 8) {
                HStack {
                    Text("Device ID:").fontWeight(.medium)
                    Spacer()
                    Text(String(status.myID.prefix(12)) + "...").font(.system(.caption, design: .monospaced))
                }
                Divider()
                HStack {
                    Text("Uptime:").fontWeight(.medium)
                    Spacer()
                    Text(formatUptime(status.uptime))
                }
            }
        }
    }
}

struct RemoteDevicesView: View {
    @ObservedObject var syncthingClient: SyncthingClient
    
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
                            completion: syncthingClient.deviceCompletions[device.deviceID]
                        )
                    }
                }
            }
        }
    }
}

struct FolderSyncStatusView: View {
    @ObservedObject var syncthingClient: SyncthingClient
    
    var body: some View {
        GroupBox("Folder Sync Status") {
            if syncthingClient.folders.isEmpty {
                Text("No folders configured").foregroundColor(.secondary).padding(.vertical, 4)
            } else {
                VStack(spacing: 12) {
                    ForEach(syncthingClient.folders) { folder in
                        FolderStatusRow(folder: folder, status: syncthingClient.folderStatuses[folder.id])
                    }
                }
            }
        }
    }
}

// MARK: - Row Views
struct DeviceStatusRow: View {
    let device: SyncthingDevice
    let connection: SyncthingConnection?
    let completion: SyncthingDeviceCompletion?
    
    var body: some View {
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
                        Text("~ \(formatBytes(completion.needBytes)) left").font(.caption2).foregroundColor(.secondary)
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
}

struct FolderStatusRow: View {
    let folder: SyncthingFolder
    let status: SyncthingFolderStatus?
    
    var body: some View {
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

// MARK: - SwiftUI Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let appDelegate = AppDelegate()
        let client = appDelegate.syncthingClient
        
        client.isConnected = true
        client.systemStatus = .init(myID: "PREVIEW-ID", tilde: "~", uptime: 12345)
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
            "DEVICE1-ID": .init(connected: true, address: "1.2.3.4", clientVersion: "v1.30.0", type: "TCP"),
            "DEVICE2-ID": .init(connected: false, address: nil, clientVersion: nil, type: nil),
            "DEVICE3-ID": .init(connected: true, address: "5.6.7.8", clientVersion: "v1.29.0", type: "QUIC")
        ]
        client.deviceCompletions = [
            "DEVICE1-ID": .init(completion: 99.5, globalBytes: 1000, needBytes: 5)
        ]
        client.folderStatuses = [
            "folder1": .init(globalFiles: 10, globalBytes: 10000, localFiles: 10, localBytes: 10000, needFiles: 0, needBytes: 0, state: "idle", stateChanged: ""),
            "folder2": .init(globalFiles: 20, globalBytes: 20000, localFiles: 15, localBytes: 15000, needFiles: 5, needBytes: 5000, state: "syncing", stateChanged: "")
        ]
        
        return ContentView(appDelegate: appDelegate, syncthingClient: client)
    }
}

// MARK: - Main App Structure
@main
struct SyncthingStatusApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            Text("Settings")
        }
    }
}