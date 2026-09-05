import AppKit
import Foundation
import SwiftUI

@main
struct StatusUIHarness {
    @MainActor
    static func main() async {
        setbuf(stdout, nil)
        guard CommandLine.arguments.count == 2,
              ["compact", "detailed"].contains(CommandLine.arguments[1]) else {
            print("usage: StatusUIFixture compact|detailed")
            exit(2)
        }

        let http = HTTPFixture()
        let settingsFixture = await SettingsFixture.make(baseURL: http.baseURL.absoluteString)
        let session = http.makeSession()
        var capturedNotifications = [String]()
        let client = SyncthingClient(
            settings: settingsFixture.settings,
            session: session,
            deliverNotification: { request, completion in
                capturedNotifications.append(request.content.title)
                completion(nil)
            }
        )

        enqueueFixture(http)
        await client.refresh()

        guard client.isConnected, client.hasCurrentConfiguration,
              http.unexpectedRequests.isEmpty, capturedNotifications.isEmpty else {
            print("fixtureLoad=failed;connected=\(client.isConnected);config=\(client.hasCurrentConfiguration);unexpected=\(http.unexpectedRequests);notifications=\(capturedNotifications)")
            await settingsFixture.close()
            session.invalidateAndCancel()
            http.close()
            exit(3)
        }

        let displayState = StatusIconStateResolver().resolveState(client: client, settings: settingsFixture.settings)
        let trafficState = statusDescription(displayState) + "; icon=" + String(describing: displayState.iconState(for: .traffic))
        settingsFixture.settings.iconColorMode = .monochrome
        let monochromeState = statusDescription(displayState) + "; icon=" + String(describing: displayState.iconState(for: .monochrome))
        settingsFixture.settings.iconColorMode = .traffic
        let softWarning = StatusIconStateResolver.IconDisplayState.warning(tooltip: "Offline peer")
        let softWarningMapping = "traffic=" + String(describing: softWarning.iconState(for: .traffic))
            + "; monochrome=" + String(describing: softWarning.iconState(for: .monochrome))
        let paused = StatusIconStateResolver.IconDisplayState.paused
        let pausedMapping = "traffic=" + String(describing: paused.iconState(for: .traffic))
            + "; monochrome=" + String(describing: paused.iconState(for: .monochrome))

        let configOnlyClient = SyncthingClient(
            settings: settingsFixture.settings,
            session: session,
            deliverNotification: { request, completion in
                capturedNotifications.append(request.content.title)
                completion(nil)
            }
        )
        configOnlyClient.isConnected = true
        http.enqueue("/rest/system/config", json: #"{"error":"fixture unavailable"}"#, status: 503)
        await configOnlyClient.fetchConfig(localDeviceID: "local")
        let configOnlyState = statusDescription(
            StatusIconStateResolver().resolveState(client: configOnlyClient, settings: settingsFixture.settings)
        )

        let mode = CommandLine.arguments[1]
        let view = StatusRowsFixtureView(
            client: client,
            settings: settingsFixture.settings,
            detailed: mode == "detailed",
            trafficState: trafficState,
            monochromeState: monochromeState,
            softWarningMapping: softWarningMapping,
            pausedMapping: pausedMapping,
            configOnlyState: configOnlyState,
            close: { NSApp.stop(nil) }
        )
        let hosting = NSHostingView(rootView: view)
        let window = NSWindow(
            contentRect: NSRect(x: 120, y: 80, width: mode == "detailed" ? 900 : 760, height: 820),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Wave 2 Status UI — \(mode.capitalized)"
        window.isReleasedWhenClosed = false
        window.contentView = hosting

        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        app.activate(ignoringOtherApps: true)
        print("fixtureReady=true;mode=\(mode);folders=\(client.folders.count);devices=\(client.devices.count);traffic=\(trafficState);monochrome=\(monochromeState);notifications=\(capturedNotifications.count)")
        app.run()

        await settingsFixture.close()
        session.invalidateAndCancel()
        http.close()
        print("fixtureClosed=true;unexpectedHTTP=\(http.unexpectedRequests.count);notifications=\(capturedNotifications.count)")
    }

    private static func statusDescription(_ state: StatusIconStateResolver.IconDisplayState) -> String {
        switch state {
        case .error(let tooltip): return "error: \(tooltip)"
        case .upAndDown: return "syncing"
        case .uploading: return "uploading"
        case .downloading: return "downloading"
        case .paused: return "paused"
        case .warning(let tooltip): return "warning: \(tooltip)"
        case .unavailable(let tooltip): return "unavailable: \(tooltip)"
        case .inSync: return "in sync"
        case .outOfSync: return "out of sync"
        }
    }

    private static func enqueueFixture(_ http: HTTPFixture) {
        http.enqueue("/rest/system/status", json: #"{"myID":"local","uptime":123}"#)
        http.enqueue("/rest/system/config", json: configurationJSON)
        http.enqueue("/rest/system/version", json: #"{"version":"fixture-version"}"#)
        http.enqueue("/rest/system/connections", json: connectionsJSON)

        http.enqueue("/rest/db/status", json: folderStatus())
        http.enqueue("/rest/db/status", json: folderStatus(needDeletes: 4, needTotalItems: 4))
        http.enqueue("/rest/db/status", json: #"{"error":"fixture unavailable"}"#, status: 503)
        http.enqueue("/rest/db/status", json: folderStatus())

        http.enqueue("/rest/db/completion", json: completionStatus())
        http.enqueue("/rest/db/completion", json: completionStatus(needDeletes: 4))
        http.enqueue("/rest/db/completion", json: #"{"error":"fixture unavailable"}"#, status: 503)
        http.enqueue("/rest/db/completion", json: completionStatus())
        http.enqueue("/rest/db/completion", json: completionStatus())
    }

    private static func folderStatus(needDeletes: Int = 0, needTotalItems: Int = 0) -> String {
        """
        {"globalFiles":10,"globalBytes":1000,"localFiles":10,"localBytes":1000,
         "needFiles":0,"needBytes":0,"needDeletes":\(needDeletes),"needDirectories":0,
         "needSymlinks":0,"needTotalItems":\(needTotalItems),"state":"idle"}
        """
    }

    private static func completionStatus(needDeletes: Int = 0, needItems: Int = 0) -> String {
        """
        {"completion":100,"globalBytes":1000,"needBytes":0,
         "needDeletes":\(needDeletes),"needItems":\(needItems)}
        """
    }

    private static let configurationJSON = #"{"devices":[{"deviceID":"local","name":"Local","addresses":[],"paused":false},{"deviceID":"idle-device","name":"Idle Device","addresses":[],"paused":false},{"deviceID":"pending-device","name":"Pending Deletes Device","addresses":[],"paused":false},{"deviceID":"unavailable-device","name":"Unavailable Device","addresses":[],"paused":false},{"deviceID":"paused-device","name":"Paused Device","addresses":[],"paused":true},{"deviceID":"offline-device","name":"Offline Peer","addresses":[],"paused":false}],"folders":[{"id":"idle-folder","label":"Idle Folder","path":"/fixture/idle","devices":[],"paused":false},{"id":"pending-folder","label":"Pending Deletes Folder","path":"/fixture/pending","devices":[],"paused":false},{"id":"unavailable-folder","label":"Unavailable Folder","path":"/fixture/unavailable","devices":[],"paused":false},{"id":"paused-folder","label":"Paused Folder","path":"/fixture/paused","devices":[],"paused":true}]}"#

    private static let connectionsJSON = #"{"connections":{"idle-device":{"connected":true,"address":"fixture-idle","clientVersion":"v2","type":"stub","inBytesTotal":0,"outBytesTotal":0},"pending-device":{"connected":true,"address":"fixture-pending","clientVersion":"v2","type":"stub","inBytesTotal":0,"outBytesTotal":0},"unavailable-device":{"connected":true,"address":"fixture-unavailable","clientVersion":"v2","type":"stub","inBytesTotal":0,"outBytesTotal":0},"paused-device":{"connected":true,"address":"fixture-paused","clientVersion":"v2","type":"stub","inBytesTotal":0,"outBytesTotal":0},"offline-device":{"connected":false,"address":null,"clientVersion":"v2","type":"stub","inBytesTotal":0,"outBytesTotal":0}}}"#
}

struct StatusRowsFixtureView: View {
    let client: SyncthingClient
    @ObservedObject var settings: SyncthingSettings
    let detailed: Bool
    let trafficState: String
    let monochromeState: String
    let softWarningMapping: String
    let pausedMapping: String
    let configOnlyState: String
    let close: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text(detailed ? "Detailed production status rows" : "Compact production status rows")
                    .font(.title2).fontWeight(.semibold)
                Spacer()
                Button("Close Fixture", action: close)
            }
            HStack {
                Text("Traffic icon semantic: \(trafficState)")
                Divider().frame(height: 18)
                Text("Monochrome icon semantic: \(monochromeState)")
                Spacer()
            }
            .font(.caption)
            HStack {
                Text("Soft warning mapping: \(softWarningMapping)")
                Divider().frame(height: 18)
                Text("Paused mapping: \(pausedMapping)")
                Divider().frame(height: 18)
                Text("Config-only failure: \(configOnlyState)")
                Spacer()
            }
            .font(.caption)
            ProductionSyncCompletionSection()
                .frame(height: 92)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Folder scenarios").font(.headline)
                    ForEach(client.folders) { folder in
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Fixture scenario: \(folder.label)").font(.caption).foregroundColor(.secondary)
                            FolderStatusRow(
                                syncthingClient: client,
                                folder: folder,
                                status: client.folderStatuses[folder.id],
                                isDetailed: detailed
                            )
                        }
                        Divider()
                    }
                    Text("Device scenarios").font(.headline)
                    ForEach(client.devices) { device in
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Fixture scenario: \(device.name)").font(.caption).foregroundColor(.secondary)
                            DeviceStatusRow(
                                syncthingClient: client,
                                device: device,
                                connection: client.connections[device.id],
                                completion: client.deviceCompletions[device.id],
                                transferRates: client.transferRates[device.id],
                                connectionHistory: client.deviceHistory[device.id],
                                settings: settings,
                                isDetailed: detailed
                            )
                        }
                        Divider()
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(16)
        .frame(minWidth: detailed ? 860 : 720, minHeight: 780)
    }
}
