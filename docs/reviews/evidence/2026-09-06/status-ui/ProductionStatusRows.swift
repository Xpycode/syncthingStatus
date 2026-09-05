import AppKit
import Charts
import Foundation
import SwiftUI

struct DeviceTransferSpeedChartView: View {
    let deviceName: String
    let deviceID: String
    let history: DeviceTransferHistory
    @AppStorage("deviceTransferChartExpanded") private var isExpanded: Bool = true

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
        DisclosureGroup(isExpanded: $isExpanded) {
            if history.dataPoints.isEmpty {
                Text("No data yet")
                    .foregroundColor(.secondary)
                    .frame(height: AppConstants.UI.chartHeight)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppConstants.UI.paddingS)
            } else {
                VStack(alignment: .leading, spacing: AppConstants.UI.spacingM) {
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
                    .frame(height: AppConstants.UI.chartHeight)

                    HStack(spacing: AppConstants.UI.spacingXL) {
                        Label("Download (received)", systemImage: "arrow.down.circle.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                        Label("Upload (sent)", systemImage: "arrow.up.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                    .padding(.top, AppConstants.UI.paddingXS)
                }
                .padding(.vertical, AppConstants.UI.paddingS)
            }
        } label: {
            Text("\(displayName) - Activity")
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .groupBoxStyle(.automatic)
    }
}


struct DeviceStatusRow: View {
    let syncthingClient: SyncthingClient  // Not @ObservedObject - prevents unnecessary rebuilds
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

    private var policy: SyncStatusPolicy.DeviceState {
        guard syncthingClient.hasCurrentConfiguration else { return .unavailable }
        return SyncStatusPolicy.device(device, connection: connection, completion: completion)
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

            VStack(alignment: .leading, spacing: AppConstants.UI.spacingXS) {
                Text(device.name).fontWeight(.medium)
                HStack(spacing: AppConstants.UI.spacingS) {
                    Circle().fill(device.paused ? .gray : (connection?.connected == true ? .green : .red)).frame(width: AppConstants.UI.iconSizeSmall, height: AppConstants.UI.iconSizeSmall)
                    if device.paused {
                        Text("Paused").font(.caption).foregroundColor(.secondary)
                    } else if let connection, connection.connected {
                        Text(connection.address ?? "Connected").font(.caption).foregroundColor(.secondary)
                    } else {
                        Text(policy == .offline ? "Offline" : "Status unavailable").font(.caption).foregroundColor(.secondary)
                    }
                }
            }
            Spacer()
            if let connection, connection.connected, !device.paused {
                if policy == .pending, let completion {
                    VStack(alignment: .trailing, spacing: AppConstants.UI.spacingXS) {
                        Text("Syncing (\(Int(completion.completion))%)").font(.caption).foregroundColor(.blue)
                        if let rates = transferRates {
                            // rates.downloadRate = data we're receiving from remote device (↓ Download)
                            // rates.uploadRate = data we're sending to remote device (↑ Upload)
                            let downloadSpeed = rates.downloadRate
                            let uploadSpeed = rates.uploadRate
                            if downloadSpeed > 0 || uploadSpeed > 0 {
                                HStack(spacing: AppConstants.UI.spacingM - 2) {
                                    if downloadSpeed > 0 {
                                        Text("↓ \(formatTransferRate(downloadSpeed))").font(.caption2).foregroundColor(.blue)
                                    }
                                    if uploadSpeed > 0 {
                                        Text("↑ \(formatTransferRate(uploadSpeed))").font(.caption2).foregroundColor(.blue)
                                    }
                                }
                            } else {
                                Text(completion.pendingSummary).font(.caption2).foregroundColor(.secondary)
                            }
                        } else {
                            Text(completion.pendingSummary).font(.caption2).foregroundColor(.secondary)
                        }
                    }
                } else if policy == .upToDate {
                    VStack(alignment: .trailing, spacing: AppConstants.UI.spacingXS) {
                        Text("Up to date").font(.caption).foregroundColor(.green)
                        if let version = connection.clientVersion {
                            Text(version).font(.caption2).foregroundColor(.secondary)
                        }
                    }
                } else {
                    Text("Status unavailable").font(.caption).foregroundColor(.orange)
                }
            }
        }
    }

    private var detailedView: some View {
        DisclosureGroup {
            VStack(spacing: AppConstants.UI.spacingM) {
                if let connection, connection.connected {
                    DeviceDetailedConnectedView(
                        connection: connection,
                        completion: completion,
                        transferRates: transferRates,
                        settings: settings,
                        device: device,
                        syncthingClient: syncthingClient
                    )
                } else {
                    DeviceDetailedDisconnectedView(
                        device: device,
                        connectionHistory: connectionHistory
                    )
                }
            }
            .padding(.vertical, AppConstants.UI.paddingXS)
        } label: {
            HStack(alignment: .center) {
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

                deviceStatusLabel
            }
        }
    }

    @ViewBuilder
    private var deviceStatusLabel: some View {
        switch policy {
        case .paused: Text("Paused").font(.subheadline).foregroundColor(.secondary)
        case .offline: Text("Offline").font(.subheadline).foregroundColor(.secondary)
        case .unavailable: Text("Status unavailable").font(.subheadline).foregroundColor(.orange)
        case .upToDate: Text("Up to date").font(.subheadline).foregroundColor(.green)
        case .pending:
            if let completion {
                Text("Syncing (\(Int(completion.completion))%)").font(.subheadline).foregroundColor(.blue)
            }
        }
    }
}


struct DeviceDetailedConnectedView: View {
    let connection: SyncthingConnection
    let completion: SyncthingDeviceCompletion?
    let transferRates: TransferRates?
    let settings: SyncthingSettings
    let device: SyncthingDevice
    let syncthingClient: SyncthingClient

    var body: some View {
                    // Row 2: Address, Connection Type, Client Version (3 columns)
                    // Padded left to align with device name
                    HStack(alignment: .top, spacing: AppConstants.UI.spacingL) {
                        // Left: Address
                        VStack(alignment: .leading, spacing: AppConstants.UI.spacingXS) {
                            Text("Address:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if let address = connection.address {
                                Text(address)
                                    .font(.system(.caption, design: .monospaced))
                                    .textSelection(.enabled)
                            } else {
                                Text("—")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // Middle: Connection Type
                        VStack(alignment: .center, spacing: AppConstants.UI.spacingXS) {
                            Text("Connection Type:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(connection.type ?? "—")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)

                        // Right: Client Version
                        VStack(alignment: .trailing, spacing: AppConstants.UI.spacingXS) {
                            Text("Client Version:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(connection.clientVersion ?? "—")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding(.leading, AppConstants.UI.detailRowIndent) // Align with device name

                    Divider()

                    // Row 3: Conditional 4-column display
                    // When actively transferring: Received | Sent | Download Speed | Upload Speed
                    // When idle: Received | Sent | Completion | Remaining
                    // Padded left to align with device name
                    HStack(alignment: .top, spacing: AppConstants.UI.spacingL) {
                        // Column 1: Data Received (always shown)
                        VStack(alignment: .center, spacing: AppConstants.UI.spacingXS) {
                            Text("Received")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formatBytes(connection.inBytesTotal))
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)

                        // Column 2: Data Sent (always shown)
                        VStack(alignment: .center, spacing: AppConstants.UI.spacingXS) {
                            Text("Sent")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formatBytes(connection.outBytesTotal))
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)

                        // Columns 3 & 4: Show speeds if actively transferring, otherwise show completion/remaining
                        if let rates = transferRates {
                            // rates.downloadRate = data we're receiving from remote device (Download)
                            // rates.uploadRate = data we're sending to remote device (Upload)
                            let downloadSpeed = rates.downloadRate
                            let uploadSpeed = rates.uploadRate
                            if downloadSpeed > 0 || uploadSpeed > 0 {
                                // Column 3: Download Speed (when active)
                                VStack(alignment: .center, spacing: AppConstants.UI.spacingXS) {
                                    Text("Download")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(formatTransferRate(downloadSpeed))
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.blue)
                                }
                                .frame(maxWidth: .infinity)

                                // Column 4: Upload Speed (when active)
                                VStack(alignment: .center, spacing: AppConstants.UI.spacingXS) {
                                    Text("Upload")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(formatTransferRate(uploadSpeed))
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.blue)
                                }
                                .frame(maxWidth: .infinity)
                            } else {
                                // Show completion/remaining when no active transfer
                                completionAndRemainingColumns
                            }
                        } else {
                            // No transfer rates available, show completion/remaining
                            completionAndRemainingColumns
                        }
                    }
                    .padding(.leading, AppConstants.UI.detailRowIndent) // Align with device name

        // Always show transfer speed chart (even when empty) to prevent window jumping
        Divider()
        if let history = syncthingClient.deviceTransferHistory[device.deviceID] {
            DeviceTransferSpeedChartView(deviceName: device.name, deviceID: device.deviceID, history: history)
        } else {
            // Show placeholder if no history yet
            DeviceTransferSpeedChartView(deviceName: device.name, deviceID: device.deviceID, history: DeviceTransferHistory())
        }
    }

    private var completionAndRemainingColumns: some View {
        Group {
            // Column 3: Completion
            VStack(alignment: .center, spacing: AppConstants.UI.spacingXS) {
                Text("Completion")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if let completion {
                    Text(String(format: "%.2f%%", completion.completion))
                        .font(.caption)
                } else {
                    Text("—")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)

            // Column 4: Remaining
            VStack(alignment: .center, spacing: AppConstants.UI.spacingXS) {
                Text("Remaining")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if let completion, !SyncStatusPolicy.isComplete(completion) {
                    Text(completion.pendingSummary)
                        .font(.caption)
                } else {
                    Text("—")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}


struct DeviceDetailedDisconnectedView: View {
    let device: SyncthingDevice
    let connectionHistory: ConnectionHistory?
    @State private var lastSeenText: String = ""

    // Timer that fires every 60 seconds to update relative time
    let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        if !device.addresses.isEmpty {
            InfoRow(label: "Addresses", value: device.addresses.joined(separator: ", "))
        }

        if let history = connectionHistory, let lastSeen = history.lastSeen {
            Divider()
            InfoRow(label: "Last Seen", value: lastSeenText)
                .onAppear {
                    updateLastSeenText(lastSeen: lastSeen)
                }
                .onReceive(timer) { _ in
                    updateLastSeenText(lastSeen: lastSeen)
                }
        }
    }

    private func updateLastSeenText(lastSeen: Date) {
        lastSeenText = formatRelativeTime(since: lastSeen)
    }
}


struct FolderDetailedContentView: View {
    let folder: SyncthingFolder
    let status: SyncthingFolderStatus

    var body: some View {
        // Single row: Path + 4 data columns
        HStack(alignment: .top, spacing: AppConstants.UI.spacingL) {
            // Left: Path
            VStack(alignment: .leading, spacing: AppConstants.UI.spacingXS) {
                Text("Path:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(folder.path)
                    .font(.caption)
                    .textSelection(.enabled)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Column 1: Global Files (always shown)
            VStack(alignment: .center, spacing: AppConstants.UI.spacingXS) {
                Text("Global Files")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(status.globalFiles)")
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)

            // Column 2: Global Size (always shown)
            VStack(alignment: .center, spacing: AppConstants.UI.spacingXS) {
                Text("Global Size")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(formatBytes(status.globalBytes))
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)

            // Columns 3 & 4: Show sync progress if syncing, otherwise show local info
            if status.state == "syncing" && status.needBytes > 0 {
                let total = Double(status.globalBytes)
                let current = Double(status.localBytes)
                if total > 0 {
                    let percentage = (current / total) * 100
                    // Column 3: Progress percentage
                    VStack(alignment: .center, spacing: AppConstants.UI.spacingXS) {
                        Text("Progress")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.1f%%", percentage))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }
                    .frame(maxWidth: .infinity)

                    // Column 4: Remaining
                    VStack(alignment: .center, spacing: AppConstants.UI.spacingXS) {
                        Text("Remaining")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(status.needFiles) files")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    localFilesAndSizeColumns
                }
            } else {
                localFilesAndSizeColumns
            }
        }
        .padding(.leading, AppConstants.UI.detailRowIndent) // Align with folder name

        // Progress bar if syncing
        if status.state == "syncing", status.needBytes > 0 {
            let total = Double(status.globalBytes)
            let current = Double(status.localBytes)
            if total > 0 {
                ProgressView(value: current / total)
                    .progressViewStyle(.linear)
                    .padding(.leading, AppConstants.UI.detailRowIndent)
            }
        }
    }

    private var localFilesAndSizeColumns: some View {
        Group {
            // Column 3: Local Files
            VStack(alignment: .center, spacing: AppConstants.UI.spacingXS) {
                Text("Local Files")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(status.localFiles)")
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)

            // Column 4: Local Size
            VStack(alignment: .center, spacing: AppConstants.UI.spacingXS) {
                Text("Local Size")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(formatBytes(status.localBytes))
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
        }
    }
}


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
                .frame(width: AppConstants.UI.labelWidth, alignment: .leading)
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
    let syncthingClient: SyncthingClient  // Not @ObservedObject - prevents unnecessary rebuilds
    let folder: SyncthingFolder
    let status: SyncthingFolderStatus?
    var isDetailed: Bool = false

    private var policy: SyncStatusPolicy.FolderState {
        SyncStatusPolicy.folder(folder, status: syncthingClient.hasCurrentConfiguration ? status : nil)
    }

    var body: some View {
        if isDetailed {
            detailedView
        } else {
            compactView
        }
    }

    private var compactView: some View {
        VStack(alignment: .leading, spacing: AppConstants.UI.spacingM) {
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

                VStack(alignment: .leading, spacing: AppConstants.UI.spacingXS) {
                    Text(folder.label.isEmpty ? folder.id : folder.label)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    Text(folder.path).font(.caption).foregroundColor(.secondary).lineLimit(1)
                }
                .layoutPriority(1)

                Spacer()

                if let status {
                    VStack(alignment: .trailing, spacing: AppConstants.UI.spacingXS) {
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

                VStack(alignment: .trailing, spacing: AppConstants.UI.spacingXS) {
                    HStack {
                        statusIcon
                        Text(policy.title).font(.caption).foregroundColor(statusColor)
                    }
                    if policy != .unavailable, let status, status.hasPendingWork {
                        Text(status.pendingSummary).font(.caption2).foregroundColor(.orange)
                    }
                }
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .trailing)
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

    private var localFilesAndSizeColumns: some View {
        Group {
            // Column 3: Local Files
            VStack(alignment: .center, spacing: AppConstants.UI.spacingXS) {
                Text("Local Files")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if let status {
                    Text("\(status.localFiles)")
                        .font(.caption)
                } else {
                    Text("—")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)

            // Column 4: Local Size
            VStack(alignment: .center, spacing: AppConstants.UI.spacingXS) {
                Text("Local Size")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if let status {
                    Text(formatBytes(status.localBytes))
                        .font(.caption)
                } else {
                    Text("—")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var detailedView: some View {
        DisclosureGroup {
            VStack(spacing: AppConstants.UI.spacingM) {
                if let status {
                    FolderDetailedContentView(
                        folder: folder,
                        status: status
                    )
                }
            }
            .padding(.vertical, AppConstants.UI.paddingXS)
        } label: {
            HStack(alignment: .center) {
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

                Text(folder.label.isEmpty ? folder.id : folder.label).font(.headline)

                Spacer()

                folderStatusLabel
            }
        }
    }

    private var folderStatusLabel: some View {
        HStack(spacing: AppConstants.UI.spacingXS) {
            Text(policy.title).font(.subheadline).foregroundColor(statusColor)
            if policy == .pending {
                Button {
                    Task { await syncthingClient.rescanFolder(folderID: folder.id) }
                } label: {
                    Image(systemName: "arrow.clockwise").font(.subheadline).foregroundColor(.orange)
                }
                .buttonStyle(.plain)
                .help("Rescan this folder to repair out-of-sync items")
            }
        }
    }

    private var statusIcon: some View {
        Image(systemName: policy.symbolName).foregroundColor(statusColor)
    }

    private var statusColor: Color { policy.color }
}


struct ProductionSyncCompletionSection: View {
    var body: some View {
        Form {
            Section("Sync Completion") {
                Text("Up to date means no pending files, directories, symlinks, deletions or bytes. Scanning and unavailable status are shown separately; offline devices do not imply a connection failure to Syncthing.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
    }
}
