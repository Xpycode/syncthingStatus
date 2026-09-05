import Foundation
import XCTest

final class SyncStatusTests: XCTestCase {
    static let folder = SyncthingFolder(id: "fixture-folder", label: "Fixture", path: "/fixture",
                                       devices: [], paused: false)

    static func payload(_ overrides: [String: Any] = [:], removing: [String] = []) throws -> String {
        var values: [String: Any] = ["globalFiles": 10, "globalBytes": 1000,
            "localFiles": 10, "localBytes": 1000, "needFiles": 0, "needBytes": 0,
            "needDirectories": 0, "needSymlinks": 0, "needDeletes": 0,
            "needTotalItems": 0, "state": "idle"]
        values.merge(overrides) { _, new in new }
        removing.forEach { values.removeValue(forKey: $0) }
        return String(decoding: try JSONSerialization.data(withJSONObject: values), as: UTF8.self)
    }

    static func decode(_ json: String) throws -> SyncthingFolderStatus {
        try JSONDecoder().decode(SyncthingFolderStatus.self, from: Data(json.utf8))
    }

    @MainActor
    func testPendingCountersCannotProduceHealthyIcon() async throws {
        let fixture = await ClientFixture.make()
        addTeardownBlock { @MainActor in await fixture.close() }
        fixture.client.configurationAvailable = true
        fixture.client.isConnected = true
        fixture.client.folders = [Self.folder]
        for pending in [["needFiles": 1, "needBytes": 512], ["needDirectories": 1, "needTotalItems": 1],
                        ["needSymlinks": 1], ["needDeletes": 4], ["needBytes": 1], ["needTotalItems": 1]] {
            let status = try Self.decode(Self.payload(pending))
            fixture.client.folderStatuses = [Self.folder.id: status]
            XCTAssertEqual(StatusIconStateResolver().resolveState(client: fixture.client,
                settings: fixture.settingsFixture.settings), .outOfSync, "\(pending)")
            XCTAssertFalse(status.pendingSummary.isEmpty, "\(pending)")
        }
    }

    @MainActor
    func testMissingStatusCannotProduceHealthyIcon() async {
        let fixture = await ClientFixture.make()
        addTeardownBlock { @MainActor in await fixture.close() }
        fixture.client.configurationAvailable = true
        fixture.client.isConnected = true
        fixture.client.folders = [Self.folder]
        XCTAssertNotEqual(StatusIconStateResolver().resolveState(client: fixture.client,
            settings: fixture.settingsFixture.settings), .inSync)
    }

    func testMalformedPayloadCannotBecomeKnownZero() throws {
        for json in ["{}", try Self.payload(["needBytes": "wrong"]),
                     try Self.payload(removing: ["state"]), try Self.payload(["needFiles": -1])] {
            XCTAssertThrowsError(try Self.decode(json), json)
        }
    }

    @MainActor
    func testDeviceWithFourDeletesIsNotComplete() async {
        let fixture = await ClientFixture.make()
        addTeardownBlock { @MainActor in await fixture.close() }
        for percent in [95.0, 100.0] {
            XCTAssertFalse(isEffectivelySynced(completion: .init(completion: percent,
                globalBytes: 1000, needBytes: 0, needDeletes: 4), settings: fixture.settingsFixture.settings))
        }
    }

    @MainActor
    func configuredFixture(peer: Bool = false) async throws -> ClientFixture {
        let fixture = await ClientFixture.make()
        addTeardownBlock { @MainActor in await fixture.close() }
        fixture.enqueueRefresh()
        await fixture.client.refresh()
        let devices = peer ? #"[{"deviceID":"peer","name":"Peer","addresses":[],"paused":false}]"# : "[]"
        fixture.http.enqueue("/rest/system/config", json:
            "{\"devices\":\(devices),\"folders\":[{\"id\":\"fixture-folder\",\"label\":\"Fixture\",\"path\":\"/fixture\",\"devices\":[],\"paused\":false}]}")
        await fixture.client.fetchConfig(localDeviceID: "local")
        XCTAssertEqual(fixture.client.folders, [Self.folder])
        XCTAssertTrue(fixture.client.configurationAvailable)
        fixture.client.configurationAvailable = true
        fixture.client.isConnected = true
        return fixture
    }

    @MainActor
    func testFailedLatestFetchInvalidatesFolderAndPeerCompletion() async throws {
        let fixture = try await configuredFixture(peer: true)
        fixture.http.enqueue("/rest/db/status", json: try Self.payload())
        fixture.http.enqueue("/rest/db/completion", json: #"{"completion":100,"globalBytes":1000,"needBytes":0,"needDeletes":0,"needItems":0}"#)
        await fixture.client.fetchFolderStatus()
        await fixture.client.fetchDeviceCompletions()
        XCTAssertNotNil(fixture.client.folderStatuses[Self.folder.id])
        XCTAssertNotNil(fixture.client.deviceCompletions["peer"])
        fixture.http.enqueue("/rest/db/status", json: "{}", status: 500)
        fixture.http.enqueue("/rest/db/completion", json: "{}", status: 500)
        await fixture.client.fetchFolderStatus()
        await fixture.client.fetchDeviceCompletions()
        XCTAssertNil(fixture.client.folderStatuses[Self.folder.id])
        XCTAssertNil(fixture.client.deviceCompletions["peer"])
        // A folder-specific API failure does not mean the whole API is unreachable.
        XCTAssertTrue(fixture.client.isConnected)
        XCTAssertNotEqual(StatusIconStateResolver().resolveState(client: fixture.client,
            settings: fixture.settingsFixture.settings), .inSync)
    }

    @MainActor
    func testPendingDeletesCannotSendFolderCompletion() async throws {
        let fixture = try await configuredFixture()
        fixture.settingsFixture.settings.showSyncNotifications = true
        fixture.http.enqueue("/rest/db/status", json: try Self.payload(["state": "syncing", "needBytes": 100_000_000]))
        await fixture.client.fetchFolderStatus()
        fixture.http.enqueue("/rest/db/status", json: try Self.payload(["needDeletes": 4]))
        await fixture.client.fetchFolderStatus()
        XCTAssertFalse(fixture.client.recentSyncEvents.contains { $0.eventType == .syncCompleted })
        XCTAssertTrue(fixture.notifications.isEmpty)
    }

    @MainActor
    func testUnknownStatusCannotSendGlobalCompletion() async throws {
        let fixture = try await configuredFixture()
        fixture.settingsFixture.settings.showSyncNotifications = true
        fixture.client.handleGlobalSyncComplete()
        XCTAssertTrue(fixture.notifications.isEmpty)
    }

    func testEveryRequiredFolderFieldRejectsAbsenceAndWrongType() throws {
        let required = ["globalFiles", "globalBytes", "localFiles", "localBytes", "needFiles",
                        "needBytes", "needDirectories", "needSymlinks", "needDeletes", "state"]
        for key in required {
            XCTAssertThrowsError(try Self.decode(Self.payload(removing: [key])), key)
            XCTAssertThrowsError(try Self.decode(Self.payload([key: ["invalid"]])), key)
            XCTAssertThrowsError(try Self.decode(Self.payload([key: NSNull()])), key)
            if key != "state" {
                XCTAssertThrowsError(try Self.decode(Self.payload([key: -1])), key)
            }
        }
        XCTAssertThrowsError(try Self.decode(Self.payload(["needTotalItems": "invalid"])))
        XCTAssertThrowsError(try Self.decode(Self.payload(["needTotalItems": -1])))
    }

    func testAggregateFallbackAndUnknownFieldsDoNotDoubleCount() throws {
        let status = try Self.decode(Self.payload(["needFiles": 1, "needDirectories": 2,
            "needSymlinks": 3, "needDeletes": 4, "needTotalItems": 10, "futureField": ["ok": true]]))
        XCTAssertEqual(status.pendingSummary, "1 file, 2 directories, 3 symlinks, 4 deletes")
        let legacy = try Self.decode(Self.payload(["needDirectories": 2, "needSymlinks": 3], removing: ["needTotalItems"]))
        XCTAssertEqual(legacy.needTotalItems, 5)
        XCTAssertEqual(legacy.pendingSummary, "2 directories, 3 symlinks")
        XCTAssertEqual(try Self.decode(Self.payload(["needTotalItems": 2])).pendingSummary, "2 other items")
    }

    func testFolderDecisionTable() throws {
        let idle = try Self.decode(Self.payload())
        XCTAssertEqual(SyncStatusPolicy.folder(Self.folder, status: idle), .upToDate)
        XCTAssertEqual(SyncStatusPolicy.folder(Self.folder, status: nil), .unavailable)
        for state in SyncStatusPolicy.activeFolderStates {
            let status = try Self.decode(Self.payload(["state": state]))
            XCTAssertEqual(SyncStatusPolicy.folder(Self.folder, status: status), .active(state))
        }
        XCTAssertEqual(SyncStatusPolicy.folder(Self.folder,
            status: try Self.decode(Self.payload(["state": "future-state"]))), .unavailable)
        XCTAssertEqual(SyncStatusPolicy.folder(Self.folder,
            status: try Self.decode(Self.payload(["state": "error"]))), .error)
        var paused = Self.folder
        paused.paused = true
        XCTAssertEqual(SyncStatusPolicy.folder(paused, status: idle), .paused)
        XCTAssertEqual(SyncStatusPolicy.folder(paused, status: nil), .paused)
    }

    static let peer = SyncthingDevice(deviceID: "peer", name: "Peer", addresses: [], paused: false)
    static func connection(connected: Bool = true) -> SyncthingConnection {
        .init(connected: connected, address: nil, clientVersion: nil, type: nil, inBytesTotal: 0, outBytesTotal: 0)
    }

    func testDeviceDecisionTableAndRequiredCounters() throws {
        let complete = SyncthingDeviceCompletion(completion: 100, globalBytes: 1000, needBytes: 0)
        XCTAssertEqual(SyncStatusPolicy.device(Self.peer, connection: Self.connection(), completion: complete), .upToDate)
        XCTAssertEqual(SyncStatusPolicy.device(Self.peer, connection: nil, completion: complete), .unavailable)
        XCTAssertEqual(SyncStatusPolicy.device(Self.peer, connection: Self.connection(), completion: nil), .unavailable)
        XCTAssertEqual(SyncStatusPolicy.device(Self.peer, connection: Self.connection(connected: false), completion: complete), .offline)
        for completion in [SyncthingDeviceCompletion(completion: 100, globalBytes: 1000, needBytes: 1),
                           .init(completion: 100, globalBytes: 1000, needBytes: 0, needItems: 1),
                           .init(completion: 95, globalBytes: 1000, needBytes: 0)] {
            XCTAssertEqual(SyncStatusPolicy.device(Self.peer, connection: Self.connection(), completion: completion), .pending)
        }
        let paused = SyncthingDevice(deviceID: "peer", name: "Peer", addresses: [], paused: true)
        XCTAssertEqual(SyncStatusPolicy.device(paused, connection: nil, completion: nil), .paused)
        let fields: [String: Any] = ["completion": 100, "globalBytes": 1000, "needBytes": 0, "needItems": 0, "needDeletes": 0]
        for key in fields.keys {
            var values = fields
            values.removeValue(forKey: key)
            XCTAssertThrowsError(try JSONDecoder().decode(SyncthingDeviceCompletion.self,
                from: JSONSerialization.data(withJSONObject: values)), key)
            values[key] = "wrong"
            XCTAssertThrowsError(try JSONDecoder().decode(SyncthingDeviceCompletion.self,
                from: JSONSerialization.data(withJSONObject: values)), key)
        }
    }

    @MainActor
    func testIconTableIncludesKnownCompleteNoFoldersScanningPausedAndOffline() async throws {
        let fixture = try await configuredFixture()
        let client = fixture.client!
        let settings = fixture.settingsFixture.settings
        client.folderStatuses = [Self.folder.id: try Self.decode(Self.payload())]
        for mode in [IconColorMode.monochrome, .traffic] {
            settings.iconColorMode = mode
            XCTAssertEqual(StatusIconStateResolver().resolveState(client: client, settings: settings), .inSync)
            client.folders = []
            XCTAssertEqual(StatusIconStateResolver().resolveState(client: client, settings: settings), .warning(tooltip: "No folders"))
            client.folders = [Self.folder]
        }
        client.folderStatuses = [Self.folder.id: try Self.decode(Self.payload(["state": "scanning"]))]
        XCTAssertEqual(StatusIconStateResolver().resolveState(client: client, settings: settings), .upAndDown(isActivityBased: false))
        var paused = Self.folder
        paused.paused = true
        client.folders = [paused]
        XCTAssertEqual(StatusIconStateResolver().resolveState(client: client, settings: settings), .paused)
        client.folders = [Self.folder]
        client.folderStatuses = [Self.folder.id: try Self.decode(Self.payload())]
        client.devices = [Self.peer]
        client.connections = [Self.peer.id: Self.connection(connected: false)]
        XCTAssertEqual(StatusIconStateResolver().resolveState(client: client, settings: settings),
                       .warning(tooltip: "Local folders up to date; some devices offline"))
        XCTAssertTrue(client.isConnected)
        client.connections = [Self.peer.id: Self.connection()]
        XCTAssertEqual(StatusIconStateResolver().resolveState(client: client, settings: settings),
                       .unavailable(tooltip: "Device status unavailable"))
    }

    @MainActor
    func testGenuineCompletionSendsExactlyOneFolderAndGlobalNotification() async throws {
        let fixture = try await configuredFixture()
        fixture.settingsFixture.settings.showSyncNotifications = true
        for payload in [try Self.payload(["state": "syncing", "needFiles": 1, "needBytes": 1]),
                        try Self.payload(["needDeletes": 4]), try Self.payload(), try Self.payload()] {
            fixture.http.enqueue("/rest/db/status", json: payload)
            await fixture.client.fetchFolderStatus()
        }
        XCTAssertEqual(fixture.client.recentSyncEvents.filter { $0.eventType == .syncCompleted }.count, 1)
        XCTAssertEqual(fixture.notifications.count, 1)
        fixture.client.handleGlobalSyncComplete()
        fixture.client.handleGlobalSyncComplete()
        XCTAssertEqual(fixture.notifications.count, 2)
    }

    @MainActor
    func testFetchFailureAndPauseCannotManufactureCompletionTransition() async throws {
        let fixture = try await configuredFixture()
        fixture.settingsFixture.settings.showSyncNotifications = true
        for payload in [try Self.payload(["state": "syncing", "needFiles": 1]), "{}", try Self.payload()] {
            fixture.http.enqueue("/rest/db/status", json: payload)
            await fixture.client.fetchFolderStatus()
        }
        XCTAssertTrue(fixture.notifications.isEmpty)
        XCTAssertFalse(fixture.client.recentSyncEvents.contains { $0.eventType == .syncCompleted })
        fixture.client.folders[0].paused = true
        fixture.client.handleGlobalSyncComplete()
        XCTAssertTrue(fixture.notifications.isEmpty)
    }

    @MainActor
    func testConfigurationAndConnectionFailureBlockCachedSuccess() async throws {
        let fixture = try await configuredFixture(peer: true)
        fixture.client.folderStatuses = [Self.folder.id: try Self.decode(Self.payload())]
        fixture.client.connections = [Self.peer.id: Self.connection()]
        fixture.client.deviceCompletions = [Self.peer.id: .init(completion: 100, globalBytes: 0, needBytes: 0)]
        fixture.http.enqueue("/rest/system/connections", json: "{}", status: 503)
        await fixture.client.fetchConnections()
        XCTAssertTrue(fixture.client.connections.isEmpty)
        XCTAssertNotEqual(StatusIconStateResolver().resolveState(client: fixture.client,
            settings: fixture.settingsFixture.settings), .inSync)
        fixture.http.enqueue("/rest/system/config", json: "{}", status: 503)
        await fixture.client.fetchConfig(localDeviceID: "local")
        XCTAssertFalse(fixture.client.configurationAvailable)
        XCTAssertEqual(StatusIconStateResolver().resolveState(client: fixture.client,
            settings: fixture.settingsFixture.settings), .unavailable(tooltip: "Configuration unavailable"))
        XCTAssertTrue(fixture.client.isConnected)
    }

    func testGlobalTrackerCompletesActiveAndIdlePendingExactlyOnce() {
        for start in [StatusIconStateResolver.IconDisplayState.outOfSync, .upAndDown(isActivityBased: false)] {
            var tracker = GlobalSyncCompletionTracker()
            XCTAssertFalse(tracker.observe(start, hasPendingWork: true, isRefreshing: false))
            XCTAssertFalse(tracker.observe(.inSync, hasPendingWork: false, isRefreshing: true))
            XCTAssertTrue(tracker.observe(.inSync, hasPendingWork: false, isRefreshing: false))
            XCTAssertFalse(tracker.observe(.inSync, hasPendingWork: false, isRefreshing: false))
        }
    }

    func testGlobalTrackerForgetsPendingAcrossUnavailablePausedAndError() {
        for gap in [StatusIconStateResolver.IconDisplayState.unavailable(tooltip: "Folder status unavailable"),
                    .unavailable(tooltip: "Configuration unavailable"), .paused, .error(tooltip: "Disconnected")] {
            var tracker = GlobalSyncCompletionTracker()
            XCTAssertFalse(tracker.observe(.upAndDown(isActivityBased: false), hasPendingWork: true, isRefreshing: false))
            XCTAssertFalse(tracker.observe(gap, hasPendingWork: false, isRefreshing: false))
            XCTAssertFalse(tracker.observe(.inSync, hasPendingWork: false, isRefreshing: false))
        }
        var tracker = GlobalSyncCompletionTracker()
        XCTAssertFalse(tracker.observe(.uploading, hasPendingWork: false, isRefreshing: false))
        XCTAssertFalse(tracker.observe(.inSync, hasPendingWork: false, isRefreshing: false))
    }

    @MainActor
    func testConfigurationFailureClearsFolderCompletionHistory() async throws {
        let fixture = try await configuredFixture()
        fixture.settingsFixture.settings.showSyncNotifications = true
        fixture.http.enqueue("/rest/db/status", json: try Self.payload(["needFiles": 1]))
        await fixture.client.fetchFolderStatus()
        fixture.http.enqueue("/rest/system/config", json: "{}", status: 503)
        await fixture.client.fetchConfig(localDeviceID: "local")
        let config = SyncthingConfig(devices: [], folders: [Self.folder])
        fixture.http.enqueue("/rest/system/config", json: String(decoding: try JSONEncoder().encode(config), as: UTF8.self))
        await fixture.client.fetchConfig(localDeviceID: "local")
        fixture.http.enqueue("/rest/db/status", json: try Self.payload())
        await fixture.client.fetchFolderStatus()
        XCTAssertTrue(fixture.notifications.isEmpty)
        XCTAssertFalse(fixture.client.recentSyncEvents.contains { $0.eventType == .syncCompleted })
    }

    func testBothIconStylesWarnForUnavailableAndRetainSoftWarningChoice() {
        for mode in [IconColorMode.monochrome, .traffic] {
            XCTAssertEqual(StatusIconStateResolver.IconDisplayState.unavailable(tooltip: "Status unavailable").iconState(for: mode), .warning)
            XCTAssertEqual(StatusIconStateResolver.IconDisplayState.outOfSync.iconState(for: mode), .error)
            XCTAssertEqual(StatusIconStateResolver.IconDisplayState.inSync.iconState(for: mode), .normal)
            let soft: SyncState = mode == .traffic ? .warning : .normal
            XCTAssertEqual(StatusIconStateResolver.IconDisplayState.paused.iconState(for: mode), soft)
            XCTAssertEqual(StatusIconStateResolver.IconDisplayState.warning(tooltip: "Some devices offline").iconState(for: mode), soft)
        }
    }

    @MainActor
    func testConfigurationOnlyFailureDiscardsCachedCompleteMetrics() async throws {
        let fixture = try await configuredFixture(peer: true)
        fixture.client.folderStatuses = [Self.folder.id: try Self.decode(Self.payload())]
        fixture.client.deviceCompletions = [Self.peer.id: .init(completion: 100, globalBytes: 0, needBytes: 0)]
        fixture.client.connections = [Self.peer.id: Self.connection()]
        fixture.http.enqueue("/rest/system/config", json: "{}", status: 503)
        await fixture.client.fetchConfig(localDeviceID: "local")
        // performRefresh still runs the status endpoints after config failure.
        // Their responses cannot certify the stale folder/device universe.
        fixture.http.enqueue("/rest/db/status", json: try Self.payload())
        fixture.http.enqueue("/rest/db/completion", json: #"{"completion":100,"globalBytes":1000,"needBytes":0,"needDeletes":0,"needItems":0}"#)
        await fixture.client.fetchFolderStatus()
        await fixture.client.fetchDeviceCompletions()
        XCTAssertNil(fixture.client.folderStatuses[Self.folder.id])
        XCTAssertNil(fixture.client.deviceCompletions[Self.peer.id])
        XCTAssertFalse(fixture.client.folderStatisticsAvailable)
        XCTAssertEqual(fixture.client.connections[Self.peer.id]?.connected, true)
    }

    @MainActor
    func testUnavailableObservationHidesStaleStuckDeleteCount() async throws {
        let fixture = try await configuredFixture()
        fixture.settingsFixture.settings.stuckDeletesAlertsEnabled = true
        fixture.client.stuckDeleteCounts = [Self.folder.id: 4]
        fixture.http.enqueue("/rest/db/status", json: "{}", status: 503)
        await fixture.client.fetchFolderStatus()
        XCTAssertNil(fixture.client.stuckDeleteCounts[Self.folder.id])
        XCTAssertEqual(StatusIconStateResolver().resolveState(client: fixture.client,
            settings: fixture.settingsFixture.settings), .unavailable(tooltip: "Folder status unavailable"))
    }
}
