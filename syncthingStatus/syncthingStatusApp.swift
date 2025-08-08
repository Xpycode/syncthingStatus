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

// Data model for the /rest/db/completion endpoint
struct SyncthingDeviceCompletion: Codable {
    let completion: Double
    let globalBytes: Int
    let needBytes: Int
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
        
        guard let finalPath = configPath else {
            print("Could not find Syncthing config.xml in standard locations.")
            return
        }
        
        print("Looking for config at: \(finalPath.path)")
        
        guard let xmlData = try? Data(contentsOf: finalPath) else {
            print("Failed to read config file data at \(finalPath.path)")
            return
        }
        
        let parser = XMLParser(data: xmlData)
        let delegate = ApiKeyParserDelegate()
        parser.delegate = delegate
        
        if parser.parse(), let key = delegate.apiKey {
            self.apiKey = key
            print("API key found: \(self.apiKey?.prefix(5) ?? "none")...")
        } else {
            print("Failed to parse or find API key in config.xml.")
        }
    }
    
    private func makeRequest<T: Codable>(endpoint: String, responseType: T.Type) async throws -> T {
        guard let url = URL(string: "\(baseURL)/rest/\(endpoint)") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        guard let apiKey = apiKey else {
            throw URLError(.userAuthenticationRequired, userInfo: ["message": "API key is missing."])
        }
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.cannotParseResponse)
        }
        
        if httpResponse.statusCode != 200 {
            let responseBody = String(data: data, encoding: .utf8) ?? "No response body"
            print("HTTP Error: \(httpResponse.statusCode) for endpoint \(endpoint). Body: \(responseBody)")
            throw URLError(.badServerResponse, userInfo: ["statusCode": httpResponse.statusCode, "body": responseBody])
        }
        
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            print("JSON Decoding Error for \(T.self) on endpoint \(endpoint): \(error)")
            let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
            print("Raw Response: \(responseString)")
            throw error
        }
    }
    
    func fetchStatus() async {
        do {
            let status = try await makeRequest(endpoint: "system/status", responseType: SyncthingStatus.self)
            await MainActor.run {
                self.systemStatus = status
                self.isConnected = true
            }
        } catch {
            print("Failed to fetch system status: \(error)")
            await MainActor.run { self.isConnected = false }
        }
    }
    
    func fetchConfig() async {
        do {
            let config = try await makeRequest(endpoint: "system/config", responseType: SyncthingConfig.self)
            let localDeviceID = await MainActor.run { self.systemStatus?.myID }
            
            await MainActor.run {
                // Filter out the local device from the list
                self.devices = config.devices.filter { $0.deviceID != localDeviceID }
                self.folders = config.folders
            }
        } catch {
            print("Failed to fetch config: \(error)")
        }
    }
    
    func fetchConnections() async {
        do {
            let connectionsResponse = try await makeRequest(endpoint: "system/connections", responseType: SyncthingConnections.self)
            await MainActor.run {
                self.connections = connectionsResponse.connections
            }
        } catch {
            print("Failed to fetch connections: \(error)")
        }
    }
    
    func fetchFolderStatus() async {
        let foldersToFetch = await MainActor.run { self.folders }
        for folder in foldersToFetch {
            do {
                let status = try await makeRequest(endpoint: "db/status?folder=\(folder.id)", responseType: SyncthingFolderStatus.self)
                await MainActor.run {
                    self.folderStatuses[folder.id] = status
                }
            } catch {
                print("Failed to fetch status for folder \(folder.id): \(error)")
            }
        }
    }
    
    func fetchDeviceCompletions() async {
        let devicesToFetch = await MainActor.run { self.devices }
        for device in devicesToFetch {
            do {
                let completion = try await makeRequest(endpoint: "db/completion?device=\(device.deviceID)", responseType: SyncthingDeviceCompletion.self)
                await MainActor.run {
                    self.deviceCompletions[device.deviceID] = completion
                }
            } catch {
                print("Failed to fetch completion for device \(device.deviceID): \(error)")
            }
        }
    }
    
    func refresh() async {
        guard apiKey != nil else {
            print("Refresh aborted: API Key is not available.")
            await MainActor.run { self.isConnected = false }
            return
        }
        
        await fetchStatus()
        
        if await MainActor.run(body: { self.isConnected }) {
            await fetchConfig() // populates devices and folders
            
            // These can run concurrently now
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
    var syncthingClient = SyncthingClient()
    private var timer: Timer?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let statusButton = statusItem?.button {
            updateStatusIcon()
            statusButton.action = #selector(statusItemClicked)
            statusButton.target = self
        }
        
        setupPopover()
        NSApp.setActivationPolicy(.accessory)
        startMonitoring()
    }
    
    func setupPopover() {
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 400, height: 500)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(rootView: ContentView(appDelegate: self, syncthingClient: syncthingClient))
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
    
    private func updateStatusIcon() {
        guard let statusButton = statusItem?.button else { return }
        
        if !syncthingClient.isConnected {
            statusButton.image = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: "Syncthing Disconnected")
            statusButton.image?.isTemplate = true
            return
        }
        
        let isSyncing = syncthingClient.deviceCompletions.values.contains { $0.completion < 100 } ||
                        syncthingClient.folderStatuses.values.contains { $0.state == "syncing" }
        
        let allFoldersIdle = syncthingClient.folderStatuses.values.allSatisfy { $0.state == "idle" && $0.needFiles == 0 }

        if isSyncing {
            statusButton.image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: "Syncing")
        } else if allFoldersIdle {
            statusButton.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "All Synced")
        } else {
            statusButton.image = NSImage(systemSymbolName: "pause.circle.fill", accessibilityDescription: "Sync Issues")
        }
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

// MARK: - ContentView (SwiftUI)
struct ContentView: View {
    let appDelegate: AppDelegate
    @ObservedObject var syncthingClient: SyncthingClient
    
    init(appDelegate: AppDelegate, syncthingClient: SyncthingClient) {
        self.appDelegate = appDelegate
        self.syncthingClient = syncthingClient
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: syncthingClient.isConnected ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(syncthingClient.isConnected ? .green : .red)
                Text("Syncthing Monitor")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Button("Refresh") {
                    Task {
                        await syncthingClient.refresh()
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.top)
            
            Divider()
            
            if !syncthingClient.isConnected {
                // Disconnected state
                VStack(spacing: 12) {
                    Image(systemName: "wifi.slash")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                    Text("Syncthing Not Connected")
                        .font(.title3)
                        .fontWeight(.medium)
                    Text("Make sure Syncthing is running and the API key is set.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Open Syncthing Web UI") {
                        if let url = URL(string: "http://127.0.0.1:8384") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            } else {
                // Connected state
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // System Status
                        if let status = syncthingClient.systemStatus {
                            GroupBox("System Status") {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("Device ID:")
                                            .fontWeight(.medium)
                                        Spacer()
                                        Text(String(status.myID.prefix(12)) + "...")
                                            .font(.system(.caption, design: .monospaced))
                                    }
                                    HStack {
                                        Text("Uptime:")
                                            .fontWeight(.medium)
                                        Spacer()
                                        Text(formatUptime(status.uptime))
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        
                        // Devices Status
                        GroupBox("Remote Devices") {
                            if syncthingClient.devices.isEmpty {
                                Text("No remote devices configured")
                                    .foregroundColor(.secondary)
                            } else {
                                VStack(alignment: .leading, spacing: 8) {
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
                        
                        // Folders Status
                        GroupBox("Folder Sync Status") {
                            if syncthingClient.folders.isEmpty {
                                Text("No folders configured")
                                    .foregroundColor(.secondary)
                            } else {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(syncthingClient.folders) { folder in
                                        FolderStatusRow(
                                            folder: folder,
                                            status: syncthingClient.folderStatuses[folder.id]
                                        )
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            Spacer()
            
            // Footer
            HStack {
                Button("Open Web UI") {
                    if let url = URL(string: "http://127.0.0.1:8384") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .disabled(!syncthingClient.isConnected)
                
                Spacer()
                
                Button("Quit") {
                    appDelegate.quit()
                }
                .foregroundColor(.red)
            }
            .padding(.bottom)
        }
        .padding(.horizontal)
        .onAppear {
            Task {
                await syncthingClient.refresh()
            }
        }
        .frame(width: 400, height: 500)
    }
}

// MARK: - Device Status Row
struct DeviceStatusRow: View {
    let device: SyncthingDevice
    let connection: SyncthingConnection?
    let completion: SyncthingDeviceCompletion?
    
    var body: some View {
        HStack {
            Circle()
                .fill(connection?.connected == true ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .fontWeight(.medium)
                Text(String(device.deviceID.prefix(12)) + "...")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if let connection, connection.connected {
                if let completion, completion.completion < 100 {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Syncing (\(Int(completion.completion))%)")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text("~ \(formatBytes(completion.needBytes)) left")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                } else {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Up to date")
                            .font(.caption)
                            .foregroundColor(.green)
                        if let version = connection.clientVersion {
                            Text(version)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } else {
                Text("Disconnected")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Folder Status Row
struct FolderStatusRow: View {
    let folder: SyncthingFolder
    let status: SyncthingFolderStatus?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                statusIcon
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(folder.label.isEmpty ? folder.id : folder.label)
                        .fontWeight(.medium)
                    Text(folder.path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                if let status {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(status.state.capitalized)
                            .font(.caption)
                            .foregroundColor(statusColor)
                        
                        if status.needFiles > 0 {
                            Text("\(status.needFiles) items, \(formatBytes(status.needBytes))")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        } else {
                            Text("Up to date")
                                .font(.caption2)
                                .foregroundColor(.green)
                        }
                    }
                }
            }
            
            if let status, status.state == "syncing", status.needBytes > 0 {
                let total = Double(status.globalBytes)
                let current = Double(status.localBytes)
                if total > 0 {
                    ProgressView(value: current / total)
                        .progressViewStyle(LinearProgressViewStyle())
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var statusIcon: some View {
        Group {
            if let status {
                switch status.state {
                case "idle" where status.needFiles > 0:
                     Image(systemName: "pause.circle.fill")
                        .foregroundColor(.orange)
                case "idle":
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                case "syncing":
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundColor(.blue)
                case "scanning":
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.blue)
                default:
                    Image(systemName: "questionmark.circle")
                        .foregroundColor(.gray)
                }
            } else {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.red)
            }
        }
    }
    
    private var statusColor: Color {
        guard let status = status else { return .red }
        
        switch status.state {
        case "idle" where status.needFiles > 0:
            return .orange
        case "idle":
            return .green
        case "syncing", "scanning":
            return .blue
        default:
            return .gray
        }
    }
}

// MARK: - SwiftUI Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let appDelegate = AppDelegate()
        // You can populate mock data in the client for previews
        // appDelegate.syncthingClient.devices = ...
        return ContentView(appDelegate: appDelegate, syncthingClient: appDelegate.syncthingClient)
    }
}


// MARK: - Main App Structure
@main
struct SyncthingStatusApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            // ContentView needs an appDelegate, so we create a dummy one for the preview.
            let appDelegate = AppDelegate()
            ContentView(appDelegate: appDelegate, syncthingClient: appDelegate.syncthingClient)
        }
    }
}