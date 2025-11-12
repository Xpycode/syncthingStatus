import SwiftUI
import Charts
import AppKit
import UniformTypeIdentifiers

// MARK: - PreferenceKey for dynamic height
struct ViewHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct ContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - ContentView
struct ContentView: View {
    var appDelegate: AppDelegate  // Strong reference - AppDelegate outlives views
    @ObservedObject var syncthingClient: SyncthingClient
    @ObservedObject var settings: SyncthingSettings
    var isPopover: Bool

    var body: some View {
        VStack(spacing: 0) {
            HeaderView(syncthingClient: syncthingClient, isConnected: syncthingClient.isConnected) {
                Task { await syncthingClient.refresh() }
            }
            .padding([.top, .horizontal])

            Divider().padding(.vertical, 8)

            if !syncthingClient.isConnected {
                DisconnectedView(appDelegate: appDelegate, settings: settings)
            } else {
                let statusContent = VStack(spacing: 16) {
                    if let status = syncthingClient.systemStatus {
                        SystemStatusView(status: status, deviceName: syncthingClient.localDeviceName, version: syncthingClient.syncthingVersion, isPopover: isPopover)
                    }

                    if !isPopover {
                        SystemStatisticsView(syncthingClient: syncthingClient)
                        TotalTransferSpeedChartView(history: syncthingClient.totalTransferHistory_published)
                    }

                    VStack(spacing: 16) {
                        RemoteDevicesView(syncthingClient: syncthingClient, settings: settings, isPopover: isPopover)
                        FolderSyncStatusView(syncthingClient: syncthingClient, isPopover: isPopover)

                        if !isPopover {
                            if !syncthingClient.recentSyncEvents.isEmpty {
                                SyncHistoryView(events: syncthingClient.recentSyncEvents)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .background(
                    GeometryReader { geometry in
                        Color.clear.preference(key: ContentHeightKey.self, value: geometry.size.height)
                    }
                )

                ScrollView {
                    statusContent
                }
            }

            FooterView(appDelegate: appDelegate, settings: settings, syncthingClient: syncthingClient, isConnected: syncthingClient.isConnected, isPopover: isPopover)
                .padding()
        }
        .background(
            ZStack {
                if isPopover {
                    Color(nsColor: .windowBackgroundColor)
                }
            }
        )
        .onPreferenceChange(ContentHeightKey.self) { contentHeight in
            if isPopover {
                appDelegate.updatePopoverSize(contentHeight: contentHeight)
            }
        }
        .frame(width: isPopover ? 400 : nil)
    }
}

// MARK: - Component Views
struct HeaderView: View {
    @ObservedObject var syncthingClient: SyncthingClient
    let isConnected: Bool
    let onRefresh: () -> Void
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            Spacer(minLength: 0)

            VStack(alignment: .center, spacing: 4) {
                Text("syncthingStatus")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                if isConnected {
                    HStack(alignment: .center, spacing: 8) {
                        Text("Connected")
                            .font(.caption)
                            .foregroundColor(.green)
                        HStack(spacing: 6) {
                            Text("↓ \(formatTransferRate(syncthingClient.currentDownloadSpeed))")
                                .font(.caption2)
                                .foregroundColor(.blue)
                            Text("↑ \(formatTransferRate(syncthingClient.currentUploadSpeed))")
                                .font(.caption2)
                                .foregroundColor(.green)
                        }
                    }
                } else {
                    Text("Disconnected")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            .frame(maxWidth: .infinity)
            .layoutPriority(1)

            HStack(alignment: .bottom, spacing: 8) {
                if syncthingClient.isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                }
                if isConnected {
                    Button(action: {
                        if syncthingClient.allDevicesPaused {
                            Task { await syncthingClient.resumeAllDevices() }
                        } else {
                            Task { await syncthingClient.pauseAllDevices() }
                        }
                    }) {
                        Image(systemName: syncthingClient.allDevicesPaused ? "play.circle.fill" : "pause.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .help(syncthingClient.allDevicesPaused ? "Resume All Devices" : "Pause All Devices")
                }
                
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(syncthingClient.isRefreshing)
            }
        }
    }
}

struct DisconnectedView: View {
    @Environment(\.openSettings) private var openSettings
    var appDelegate: AppDelegate  // Strong reference
    let settings: SyncthingSettings
    
    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "wifi.slash").font(.largeTitle).foregroundColor(.red)
            Text("Syncthing Not Connected").font(.title3).fontWeight(.medium)
            Text("Make sure Syncthing is running and the API key is set.")
                .font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center)
            Button("Open Syncthing Web UI") {
                if let url = URL(string: settings.baseURLString) { NSWorkspace.shared.open(url) }
            }.buttonStyle(.borderedProminent)
            Button("Open Settings") {
                appDelegate.presentSettings(using: openSettings.callAsFunction)
            }
            .buttonStyle(.bordered)
            Spacer()
        }
    }
}

struct FooterView: View {
    @Environment(\.openSettings) private var openSettings
    var appDelegate: AppDelegate  // Strong reference
    let settings: SyncthingSettings
    @ObservedObject var syncthingClient: SyncthingClient
    let isConnected: Bool
    let isPopover: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let errorMessage = syncthingClient.lastErrorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .help(errorMessage)
                }
            }
            
            HStack {
                Button("Open Web UI") {
                    if let url = URL(string: settings.baseURLString) { NSWorkspace.shared.open(url) }
                }.disabled(!isConnected)
                
                Button("Settings") {
                    appDelegate.presentSettings(using: openSettings.callAsFunction)
                }
                .buttonStyle(.bordered)
                
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
}

struct SystemStatusView: View {
    let status: SyncthingSystemStatus
    let deviceName: String
    let version: String?
    var isPopover: Bool = true

    var body: some View {
        GroupBox("Local Device") {
            HStack {
                Text(deviceName)
                    .fontWeight(.medium)
                Spacer()
                if let version = version {
                    Text(version)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(formatUptime(status.uptime))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
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
    @ObservedObject var settings: SyncthingSettings
    var isPopover: Bool = true

    var body: some View {
        GroupBox("Remote Devices") {
            if syncthingClient.devices.isEmpty {
                Text("No remote devices configured").foregroundColor(.secondary).padding(.vertical, 4)
            } else {
                VStack(spacing: 12) {
                    ForEach(syncthingClient.devices) { device in
                        DeviceStatusRow(
                            syncthingClient: syncthingClient,
                            device: device,
                            connection: syncthingClient.connections[device.deviceID],
                            completion: syncthingClient.deviceCompletions[device.deviceID],
                            transferRates: syncthingClient.transferRates[device.deviceID],
                            connectionHistory: syncthingClient.deviceHistory[device.deviceID],
                            settings: settings,
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
                        FolderStatusRow(syncthingClient: syncthingClient, folder: folder, status: syncthingClient.folderStatuses[folder.id], isDetailed: !isPopover)
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

struct DeviceTransferSpeedChartView: View {
    let deviceName: String
    let history: DeviceTransferHistory

    private var maxSpeed: Double {
        // Use cached max values instead of recalculating
        let maxValue = max(history.maxDownloadRate, history.maxUploadRate) / AppConstants.DataSize.bytesPerKB
        // Add 20% padding to max value for better visualization, minimum 1
        return max(maxValue * 1.2, 1)
    }

    private var displayName: String {
        deviceName.isEmpty ? "Unknown Device" : deviceName
    }

    var body: some View {
        GroupBox("\(displayName) - Transfer Speed") {
            if history.dataPoints.isEmpty {
                Text("No data yet").foregroundColor(.secondary).padding(.vertical, 20)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Chart {
                        // Download series (data being received from remote device)
                        ForEach(history.dataPoints) { point in
                            LineMark(
                                x: .value("Time", point.timestamp),
                                y: .value("Speed", point.downloadRate / AppConstants.DataSize.bytesPerKB),
                                series: .value("Type", "Download")
                            )
                            .foregroundStyle(.blue)
                            .lineStyle(StrokeStyle(lineWidth: 2.5))
                            .symbol(.circle)
                            .symbolSize(20)
                        }

                        // Upload series (data being sent to remote device)
                        ForEach(history.dataPoints) { point in
                            LineMark(
                                x: .value("Time", point.timestamp),
                                y: .value("Speed", point.uploadRate / AppConstants.DataSize.bytesPerKB),
                                series: .value("Type", "Upload")
                            )
                            .foregroundStyle(.green)
                            .lineStyle(StrokeStyle(lineWidth: 2.5, dash: [5, 3]))
                            .symbol(.square)
                            .symbolSize(20)
                        }
                    }
                    .chartYScale(domain: 0...maxSpeed)
                    .chartYAxis {
                        AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                            AxisValueLabel()
                            AxisGridLine()
                        }
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
                        Label("Download (received)", systemImage: "arrow.down.circle.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                        Label("Upload (sent)", systemImage: "arrow.up.circle.fill")
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

struct TotalTransferSpeedChartView: View {
    let history: DeviceTransferHistory

    private var maxSpeed: Double {
        // Use cached max values instead of recalculating
        let maxValue = max(history.maxDownloadRate, history.maxUploadRate) / AppConstants.DataSize.bytesPerKB
        // Add 20% padding to max value for better visualization, minimum 1
        return max(maxValue * 1.2, 1)
    }

    var body: some View {
        GroupBox("Total Transfer Speed") {
            if history.dataPoints.isEmpty {
                Text("No transfer data yet").foregroundColor(.secondary).padding(.vertical, 20)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Chart {
                        // Download series (received data)
                        ForEach(history.dataPoints) { point in
                            LineMark(
                                x: .value("Time", point.timestamp),
                                y: .value("Speed", point.downloadRate / AppConstants.DataSize.bytesPerKB),
                                series: .value("Type", "Download")
                            )
                            .foregroundStyle(.blue)
                            .lineStyle(StrokeStyle(lineWidth: 2.5))
                            .symbol(.circle)
                            .symbolSize(20)
                        }

                        // Upload series (sent data)
                        ForEach(history.dataPoints) { point in
                            LineMark(
                                x: .value("Time", point.timestamp),
                                y: .value("Speed", point.uploadRate / AppConstants.DataSize.bytesPerKB),
                                series: .value("Type", "Upload")
                            )
                            .foregroundStyle(.green)
                            .lineStyle(StrokeStyle(lineWidth: 2.5, dash: [5, 3]))
                            .symbol(.square)
                            .symbolSize(20)
                        }
                    }
                    .chartYScale(domain: 0...maxSpeed)
                    .chartYAxis {
                        AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                            AxisValueLabel()
                            AxisGridLine()
                        }
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
                        Label("Download (received)", systemImage: "arrow.down.circle.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                        Label("Upload (sent)", systemImage: "arrow.up.circle.fill")
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
    @ObservedObject var syncthingClient: SyncthingClient
    let device: SyncthingDevice
    let connection: SyncthingConnection?
    let completion: SyncthingDeviceCompletion?
    let transferRates: TransferRates?
    let connectionHistory: ConnectionHistory?
    @ObservedObject var settings: SyncthingSettings
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
            Button(action: {
                if device.paused {
                    Task { await syncthingClient.resumeDevice(deviceID: device.deviceID) }
                } else {
                    Task { await syncthingClient.pauseDevice(deviceID: device.deviceID) }
                }
            }) {
                Image(systemName: device.paused ? "play.circle.fill" : "pause.circle.fill")
            }
            .buttonStyle(.plain)

            Image(systemName: "laptopcomputer")
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(device.name).fontWeight(.medium)
                HStack(spacing: 4) {
                    Circle().fill(device.paused ? .gray : (connection?.connected == true ? .green : .red)).frame(width: 8, height: 8)
                    if device.paused {
                        Text("Paused").font(.caption).foregroundColor(.secondary)
                    } else if let connection, connection.connected {
                        Text(connection.address ?? "Connected").font(.caption).foregroundColor(.secondary)
                    } else {
                        Text("Disconnected").font(.caption).foregroundColor(.secondary)
                    }
                }
            }
            Spacer()
            if let connection, connection.connected, !device.paused {
                if let completion, !isEffectivelySynced(completion: completion, settings: settings) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Syncing (\(Int(completion.completion))%)").font(.caption).foregroundColor(.blue)
                        if let rates = transferRates {
                            let remoteDownloadRate = rates.uploadRate
                            let remoteUploadRate = rates.downloadRate
                            if remoteDownloadRate > 0 || remoteUploadRate > 0 {
                                HStack(spacing: 6) {
                                    if remoteDownloadRate > 0 {
                                        Text("↓ \(formatTransferRate(remoteDownloadRate))").font(.caption2).foregroundColor(.blue)
                                    }
                                    if remoteUploadRate > 0 {
                                        Text("↑ \(formatTransferRate(remoteUploadRate))").font(.caption2).foregroundColor(.blue)
                                    }
                                }
                            } else {
                                Text("~ \(formatBytes(completion.needBytes)) left").font(.caption2).foregroundColor(.secondary)
                            }
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
            }
        }
    }

    private var detailedView: some View {
        DisclosureGroup {
            VStack(spacing: 6) {
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
                        let remoteDownloadRate = rates.uploadRate
                        let remoteUploadRate = rates.downloadRate
                        if remoteDownloadRate > 0 || remoteUploadRate > 0 {
                            Divider()
                            if remoteDownloadRate > 0 {
                                InfoRow(label: "Download Speed", value: formatTransferRate(remoteDownloadRate), isHighlighted: true)
                            }
                            if remoteUploadRate > 0 {
                                InfoRow(label: "Upload Speed", value: formatTransferRate(remoteUploadRate), isHighlighted: true)
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
                    
                    if let history = syncthingClient.deviceTransferHistory[device.deviceID], hasSignificantActivity(history: history) {
                        Divider()
                        DeviceTransferSpeedChartView(deviceName: device.name, history: history)
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
                Button(action: {
                    if device.paused {
                        Task { await syncthingClient.resumeDevice(deviceID: device.deviceID) }
                    } else {
                        Task { await syncthingClient.pauseDevice(deviceID: device.deviceID) }
                    }
                }) {
                    Image(systemName: device.paused ? "play.circle.fill" : "pause.circle.fill")
                }
                .buttonStyle(.plain)

                Image(systemName: "laptopcomputer")
                    .foregroundColor(.secondary)
                Text(device.name).font(.headline)
                Spacer()
                if device.paused {
                    Text("Paused").font(.subheadline).foregroundColor(.secondary)
                } else if let connection, connection.connected {
                    if let completion, !isEffectivelySynced(completion: completion, settings: settings) {
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
    @ObservedObject var syncthingClient: SyncthingClient
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
                Button(action: {
                    if folder.paused {
                        Task { await syncthingClient.resumeFolder(folderID: folder.id) }
                    } else {
                        Task { await syncthingClient.pauseFolder(folderID: folder.id) }
                    }
                }) {
                    Image(systemName: folder.paused ? "play.circle.fill" : "pause.circle.fill")
                }
                .buttonStyle(.plain)

                Image(systemName: "folder.fill")
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(folder.label.isEmpty ? folder.id : folder.label).fontWeight(.medium)
                    Text(folder.path).font(.caption).foregroundColor(.secondary).lineLimit(1)
                }

                Spacer()

                if let status {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(status.localFiles) files")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatBytes(status.localBytes))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .trailing)
                }

                Spacer()
                
                if let status {
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack {
                            statusIcon
                            Text(status.state.capitalized).font(.caption).foregroundColor(statusColor)
                        }
                        if status.needFiles > 0 {
                            Text("\(status.needFiles) items, \(formatBytes(status.needBytes))").font(.caption2).foregroundColor(.orange)
                        } else {
                            Text("Up to date").font(.caption2).foregroundColor(.green)
                        }
                    }
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .trailing)
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
        .contextMenu {
            Button("Rescan") {
                Task { await syncthingClient.rescanFolder(folderID: folder.id) }
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
                Button(action: {
                    if folder.paused {
                        Task { await syncthingClient.resumeFolder(folderID: folder.id) }
                    } else {
                        Task { await syncthingClient.pauseFolder(folderID: folder.id) }
                    }
                }) {
                    Image(systemName: folder.paused ? "play.circle.fill" : "pause.circle.fill")
                }
                .buttonStyle(.plain)

                Image(systemName: "folder.fill")
                    .foregroundColor(.secondary)

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
    @ObservedObject var syncthingClient: SyncthingClient
    @State private var showResetConfirmation = false
    @State private var remainingMB: Double
    @State private var stalledMinutes: Double
    @State private var configSelectionError: String?
    @State private var isSelectingConfig = false

    private var isManualMode: Bool {
        !settings.useAutomaticDiscovery
    }

    init(settings: SyncthingSettings, syncthingClient: SyncthingClient) {
        self.settings = settings
        self.syncthingClient = syncthingClient
        _remainingMB = State(initialValue: Double(settings.syncRemainingBytesThreshold) / 1_048_576.0)
        _stalledMinutes = State(initialValue: settings.stalledSyncTimeoutMinutes)
    }

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at Login", isOn: $settings.launchAtLogin)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Popover Max Height:")
                        Spacer()
                        Text("\(Int(settings.popoverMaxHeightPercentage))% of screen")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $settings.popoverMaxHeightPercentage, in: 30...100, step: 5)
                    Text("Controls how tall the status popover can grow before showing scrollbars")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section("Connection Mode") {
                Toggle("Discover API key from Syncthing config.xml", isOn: $settings.useAutomaticDiscovery)
                Text("Turn this off to point the app at a different Syncthing instance.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    Button("Select Syncthing config.xml…") {
                        selectSyncthingConfig()
                    }
                    .disabled(!settings.useAutomaticDiscovery)

                    if let path = settings.configBookmarkDisplayPath {
                        Text("Using: \(path)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Select your Syncthing config.xml so syncthingStatus can read the API key automatically.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    if settings.hasConfigBookmark {
                        Button("Forget selection") {
                            settings.clearConfigBookmark()
                            configSelectionError = nil
                            if settings.useAutomaticDiscovery {
                                Task { await syncthingClient.refresh() }
                            }
                        }
                        .buttonStyle(.link)
                    }

                    if let configSelectionError {
                        Text(configSelectionError)
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                }
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

            Section("Sync Completion Threshold") {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Completion Percentage:")
                            Spacer()
                            Text("\(Int(settings.syncCompletionThreshold))%")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $settings.syncCompletionThreshold, in: 90...100, step: 1)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Remaining Data:")
                            Spacer()
                            Text(String(format: "%.1f MB", remainingMB))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $remainingMB, in: 0...10, step: 0.5)
                            .onChange(of: remainingMB) { oldValue, newValue in
                                settings.syncRemainingBytesThreshold = Int64(newValue * 1_048_576.0)
                            }
                    }
                }

                Text("Devices are considered 'synced' when they reach the completion percentage with less than the specified remaining data. This handles cases where Syncthing shows high completion (95%+) with minimal remaining bytes.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("Monitoring") {
                Picker("Refresh Interval", selection: $settings.refreshInterval) {
                    Text("5 seconds").tag(5.0)
                    Text("10 seconds").tag(10.0)
                    Text("30 seconds").tag(30.0)
                    Text("1 minute").tag(60.0)
                    Text("5 minutes").tag(300.0)
                }
            }

            Section("Notifications") {
                Toggle("Show device connect notifications", isOn: $settings.showDeviceConnectNotifications)
                Toggle("Show device disconnect notifications", isOn: $settings.showDeviceDisconnectNotifications)
                Toggle("Show pause/resume notifications", isOn: $settings.showPauseResumeNotifications)
                
                Toggle("Alert when sync stalls", isOn: $settings.showStalledSyncNotifications)
                
                if settings.showStalledSyncNotifications {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Stall threshold")
                            Spacer()
                            Text("\(Int(stalledMinutes)) min")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $stalledMinutes, in: 1...30, step: 1)
                            .onChange(of: stalledMinutes) { _, newValue in
                                settings.stalledSyncTimeoutMinutes = newValue
                            }
                        Text("Trigger a reminder if a folder stays in 'Syncing' without progress longer than this.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                DisclosureGroup("Per-folder sync completion notifications") {
                    if syncthingClient.folders.isEmpty {
                        Text("No folders configured.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(syncthingClient.folders) { folder in
                            Toggle(folder.label, isOn: Binding(
                                get: { settings.notificationEnabledFolderIDs.contains(folder.id) },
                                set: { isOn in
                                    if isOn {
                                        settings.notificationEnabledFolderIDs.append(folder.id)
                                    } else {
                                        settings.notificationEnabledFolderIDs.removeAll { $0 == folder.id }
                                    }
                                }
                            ))
                        }
                    }
                }
            }

            Section {
                Button("Reset to Defaults", role: .destructive) {
                    showResetConfirmation = true
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .padding(20)
        .alert("Reset Settings", isPresented: $showResetConfirmation) {
            Button("Reset", role: .destructive) {
                settings.resetToDefaults()
                remainingMB = Double(settings.syncRemainingBytesThreshold) / 1_048_576.0
                stalledMinutes = settings.stalledSyncTimeoutMinutes
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will restore the built-in localhost configuration and clear any manual API key.")
        }
        .onChange(of: settings.useAutomaticDiscovery) { _, newValue in
            if newValue {
                if !settings.hasConfigBookmark {
                    selectSyncthingConfig()
                }
            } else {
                configSelectionError = nil
            }
        }
        .onChange(of: settings.stalledSyncTimeoutMinutes) { _, newValue in
            stalledMinutes = newValue
        }
    }

    private func selectSyncthingConfig() {
        guard !isSelectingConfig else { return }
        isSelectingConfig = true

        let panel = NSOpenPanel()
        panel.title = "Select Syncthing config.xml"
        panel.prompt = "Grant Access"

        let suggestedURL: URL?
        if let existingPath = settings.configBookmarkPath {
            suggestedURL = URL(fileURLWithPath: existingPath)
        } else {
            suggestedURL = defaultSyncthingConfigDirectory()?.appendingPathComponent("config.xml")
        }

        let pathDescription: String
        if let suggestedURL {
            pathDescription = (suggestedURL.path as NSString).abbreviatingWithTildeInPath
        } else {
            pathDescription = "~/Library/Application Support/Syncthing/config.xml"
        }
        panel.message = "syncthingStatus needs access to Syncthing's config.xml (typically \(pathDescription)). Press ⌘⇧. to show hidden folders."
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if #available(macOS 11.0, *) {
            panel.allowedContentTypes = [.xml]
        } else {
            panel.allowedFileTypes = ["xml"]
        }
        if let existing = settings.configBookmarkPath {
            let url = URL(fileURLWithPath: existing)
            panel.directoryURL = url.deletingLastPathComponent()
            panel.nameFieldStringValue = url.lastPathComponent
        } else if let directory = defaultSyncthingConfigDirectory() {
            panel.directoryURL = directory
            panel.nameFieldStringValue = "config.xml"
        } else {
            panel.nameFieldStringValue = "config.xml"
        }

        panel.begin { response in
            defer { isSelectingConfig = false }

            guard response == .OK, let url = panel.url else {
                if !settings.hasConfigBookmark {
                    settings.useAutomaticDiscovery = false
                }
                return
            }

            do {
                try settings.updateConfigBookmark(with: url)
                configSelectionError = nil
                if settings.useAutomaticDiscovery {
                    Task { await syncthingClient.refresh() }
                }
            } catch {
                configSelectionError = error.localizedDescription
            }
        }
    }

    private func defaultSyncthingConfigDirectory() -> URL? {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        let primary = home.appendingPathComponent("Library/Application Support/Syncthing", isDirectory: true)
        if fileManager.fileExists(atPath: primary.path) { return primary }
        let alternate = home.appendingPathComponent(".config/syncthing", isDirectory: true)
        if fileManager.fileExists(atPath: alternate.path) { return alternate }
        return nil
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
            .init(deviceID: "DEVICE1-ID", name: "PLEXmini", addresses: [], paused: false),
            .init(deviceID: "DEVICE2-ID", name: "M1max", addresses: [], paused: true),
            .init(deviceID: "DEVICE3-ID", name: "Another Device", addresses: [], paused: false)
        ]
        client.folders = [
            .init(id: "folder1", label: "Xcode Projects", path: "/Users/sim/XcodeProjects", devices: [], paused: false),
            .init(id: "folder2", label: "SYNCSim", path: "/Users/sim/SYNCSim", devices: [], paused: true),
            .init(id: "folder3", label: "Documents", path: "/Users/sim/Documents", devices: [], paused: false)
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
        
        return ContentView(appDelegate: appDelegate, syncthingClient: client, settings: settings, isPopover: true)
    }
}
