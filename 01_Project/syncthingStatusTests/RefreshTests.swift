import Foundation
import XCTest
import Combine

/// Deliberately ignores cancellation until released: models cancellation unwind
/// and a transport returning a late success without relying on executor timing.
@MainActor
final class RefreshGate {
    let entered = XCTestExpectation(description: "refresh reached gate")
    private var continuation: CheckedContinuation<Void, Never>?
    private var open = false

    func wait() async {
        entered.fulfill()
        await withCheckedContinuation { continuation in
            if open { continuation.resume() } else { self.continuation = continuation }
        }
    }

    func release() {
        open = true
        continuation?.resume()
        continuation = nil
    }
}

@MainActor
final class RefreshHarness {
    let settingsFixture: SettingsFixture
    var client: SyncthingClient!
    var requests: [URLRequest] = []
    var notifications = 0
    var notificationTitles: [String] = []
    var timerCallbacks: [@MainActor () -> Void] = []
    var timerIntervals: [TimeInterval] = []
    var liveTimers: Set<Int> = []
    var activeRequests = 0
    var maximumActiveRequests = 0
    var activeByEndpoint: [String: Int] = [:]
    var maximumByEndpoint: [String: Int] = [:]
    var intercept: ((URLRequest, Int) async throws -> String?)?

    private init(settings: SettingsFixture) {
        settingsFixture = settings
        client = SyncthingClient(settings: settings.settings, requestData: { [unowned self] request in
            requests.append(request)
            let endpoint = request.url!.path
            activeRequests += 1
            maximumActiveRequests = max(maximumActiveRequests, activeRequests)
            activeByEndpoint[endpoint, default: 0] += 1
            maximumByEndpoint[endpoint] = max(maximumByEndpoint[endpoint, default: 0], activeByEndpoint[endpoint]!)
            defer {
                activeRequests -= 1
                activeByEndpoint[endpoint, default: 0] -= 1
            }
            let ordinal = requests.filter { $0.url?.path == request.url?.path }.count
            let body = try await intercept?(request, ordinal) ?? Self.body(for: request)
            return (Data(body.utf8), HTTPURLResponse(url: request.url!, statusCode: 200,
                                                   httpVersion: nil, headerFields: nil)!)
        }, makeTimer: { [unowned self] interval, fire in
            let index = timerCallbacks.count
            timerCallbacks.append(fire)
            timerIntervals.append(interval)
            liveTimers.insert(index)
            return AnyCancellable { [weak self] in self?.liveTimers.remove(index) }
        }, deliverNotification: { [unowned self] request, completion in
            notifications += 1
            notificationTitles.append(request.content.title)
            completion(nil)
        })
    }

    static func make() async -> RefreshHarness {
        RefreshHarness(settings: await SettingsFixture.make())
    }

    static func body(for request: URLRequest) -> String {
        switch request.url!.path {
        case "/rest/system/status": return #"{"myID":"local","uptime":123}"#
        case "/rest/system/config": return #"{"devices":[],"folders":[]}"#
        case "/rest/system/version": return #"{"version":"current"}"#
        case "/rest/system/connections": return #"{"connections":{}}"#
        default:
            XCTFail("Unscripted request: \(request.url!.path)")
            return "{}"
        }
    }

    var passes: Int { requests.filter { $0.url?.path == "/rest/system/status" }.count }

    func close() async {
        client.stopMonitoring()
        await client.waitForRefreshToFinish()
        client = nil
        await settingsFixture.close()
    }
}

final class RefreshTests: XCTestCase {
    @MainActor
    func testGlobalCompletionForgetsPendingAcrossConnectionFailure() async throws {
        let fixture = await RefreshHarness.make()
        let folder = SyncthingFolder(id: "folder", label: "Folder", path: "/fixture", devices: [], paused: false)
        let config = String(decoding: try JSONEncoder().encode(SyncthingConfig(devices: [], folders: [folder])), as: UTF8.self)
        let pending = try SyncStatusTests.payload(["needFiles": 1])
        let complete = try SyncStatusTests.payload()
        fixture.settingsFixture.settings.showSyncNotifications = true
        fixture.intercept = { request, ordinal in
            switch request.url!.path {
            case "/rest/system/status" where ordinal == 2: throw URLError(.cannotConnectToHost)
            case "/rest/system/config": return config
            case "/rest/db/status": return ordinal == 1 ? pending : complete
            default: return nil
            }
        }
        await fixture.client.refresh()
        await fixture.client.refresh()
        XCTAssertFalse(fixture.client.isConnected)
        await fixture.client.refresh()
        XCTAssertFalse(fixture.notificationTitles.contains("All Synced"))
        XCTAssertFalse(fixture.notificationTitles.contains("Sync Complete"))
        XCTAssertFalse(fixture.client.recentSyncEvents.contains { $0.eventType == .syncCompleted })
        await fixture.close()
    }

    @MainActor
    func testConnectionEditsDuringDemoPreserveSyntheticPresentation() async {
        let fixture = await RefreshHarness.make()
        fixture.client.enableDemoMode(deviceCount: 2, folderCount: 2, scenario: .highSpeed)
        let completions = fixture.client.deviceCompletions
        let download = fixture.client.currentDownloadSpeed
        let upload = fixture.client.currentUploadSpeed
        let statuses = fixture.client.folderStatuses
        fixture.settingsFixture.settings.manualAPIKey = "new-key"
        XCTAssertEqual(fixture.client.deviceCompletions, completions)
        XCTAssertEqual(fixture.client.currentDownloadSpeed, download)
        XCTAssertEqual(fixture.client.currentUploadSpeed, upload)
        XCTAssertEqual(fixture.client.folderStatuses, statuses)
        XCTAssertEqual(fixture.requests.count, 0)
        await fixture.close()
    }

    @MainActor
    func testGlobalCompletionIsDeliveredAtPassBoundaryWithFollowUpPending() async throws {
        let fixture = await RefreshHarness.make()
        let folder = SyncthingFolder(id: "folder-0", label: "Folder", path: "/fixture", devices: [], paused: false)
        let config = String(decoding: try JSONEncoder().encode(SyncthingConfig(devices: [], folders: [folder])), as: UTF8.self)
        let pending = try SyncStatusTests.payload(["needFiles": 1])
        let complete = try SyncStatusTests.payload()
        let secondGate = RefreshGate()
        let thirdGate = RefreshGate()
        fixture.settingsFixture.settings.showSyncNotifications = true
        fixture.intercept = { request, ordinal in
            switch request.url!.path {
            case "/rest/system/config": return config
            case "/rest/db/status":
                if ordinal == 2 { await secondGate.wait() }
                if ordinal == 3 { await thirdGate.wait() }
                return ordinal == 1 ? pending : complete
            default: return nil
            }
        }
        await fixture.client.refresh()
        fixture.client.requestRefresh()
        await fulfillment(of: [secondGate.entered], timeout: 2)
        fixture.client.requestRefresh()
        secondGate.release()
        await fulfillment(of: [thirdGate.entered], timeout: 2)
        XCTAssertTrue(fixture.client.isRefreshing)
        XCTAssertEqual(fixture.notificationTitles.filter { $0 == "All Synced" }.count, 1)
        thirdGate.release()
        await fixture.client.waitForRefreshToFinish()
        XCTAssertEqual(fixture.notificationTitles.filter { $0 == "All Synced" }.count, 1)
        await fixture.close()
    }

    static func config(entryCount: Int) throws -> String {
        let config = SyncthingConfig(devices: (0..<entryCount).map {
            SyncthingDevice(deviceID: "peer-\($0)", name: "Peer \($0)", addresses: [], paused: false)
        }, folders: (0..<entryCount).map {
            SyncthingFolder(id: "folder-\($0)", label: "Folder \($0)", path: "/fixture/\($0)", devices: [], paused: false)
        })
        return String(decoding: try JSONEncoder().encode(config), as: UTF8.self)
    }

    static let complete = #"{"completion":100,"globalBytes":1000,"needBytes":0,"needItems":0,"needDeletes":0}"#

    @MainActor
    func testEveryFetchRejectsLateSuccessAndFailureAfterIdentityChange() async throws {
        for endpoint in ["system/status", "system/config", "system/version", "system/connections", "db/status", "db/completion"] {
            for fail in [false, true] {
                let fixture = await RefreshHarness.make()
                let config = try Self.config(entryCount: 1)
                let pending = try SyncStatusTests.payload(["needFiles": 1])
                let completeStatus = try SyncStatusTests.payload()
                fixture.settingsFixture.settings.showSyncNotifications = true
                fixture.intercept = { request, _ in
                    switch request.url!.path {
                    case "/rest/system/config": return config
                    case "/rest/db/status": return pending
                    case "/rest/db/completion": return Self.complete
                    default: return nil
                    }
                }
                await fixture.client.refresh()
                let gate = RefreshGate()
                fixture.intercept = { request, _ in
                    if request.url!.path == "/rest/" + endpoint {
                        await gate.wait()
                        if fail { throw URLError(.cannotConnectToHost) }
                    }
                    switch request.url!.path {
                    case "/rest/system/config": return config
                    case "/rest/db/status": return completeStatus
                    case "/rest/db/completion": return Self.complete
                    default: return nil
                    }
                }
                // Direct fetches are not children of the owner's cancelled pass:
                // this exercises generation guards independently of cancellation.
                let fetch = Task { @MainActor in
                    switch endpoint {
                    case "system/status": await fixture.client.fetchStatus()
                    case "system/config": await fixture.client.fetchConfig(localDeviceID: "local")
                    case "system/version": await fixture.client.fetchVersion()
                    case "system/connections": await fixture.client.fetchConnections()
                    case "db/status": await fixture.client.fetchFolderStatus()
                    default: await fixture.client.fetchDeviceCompletions()
                    }
                }
                await fulfillment(of: [gate.entered], timeout: 2)
                fixture.settingsFixture.settings.manualAPIKey = "new-identity-key"
                fixture.client.lastErrorMessage = "current-generation-error"
                gate.release()
                await fetch.value
                XCTAssertNil(fixture.client.systemStatus, endpoint)
                XCTAssertNil(fixture.client.syncthingVersion, endpoint)
                XCTAssertFalse(fixture.client.configurationAvailable, endpoint)
                XCTAssertTrue(fixture.client.folders.isEmpty, endpoint)
                XCTAssertTrue(fixture.client.connections.isEmpty, endpoint)
                XCTAssertTrue(fixture.client.folderStatuses.isEmpty, endpoint)
                XCTAssertTrue(fixture.client.deviceCompletions.isEmpty, endpoint)
                XCTAssertEqual(fixture.client.lastErrorMessage, "current-generation-error", endpoint)
                XCTAssertEqual(fixture.notifications, 0, endpoint)
                await fixture.close()
            }
        }
    }

    @MainActor
    func testRequestCapAndGenerationIsolationWhileAllSlotsAreOccupied() async throws {
        let fixture = await RefreshHarness.make()
        let gates = (0..<6).map { _ in RefreshGate() }
        let config = try Self.config(entryCount: 6)
        let status = try SyncStatusTests.payload()
        fixture.intercept = { request, _ in
            let endpoint = request.url!.path
            let value = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.first?.value
            if request.value(forHTTPHeaderField: "X-API-Key") == "fixture-api-key" {
                switch endpoint {
                case "/rest/system/version": await gates[0].wait()
                case "/rest/system/connections": await gates[1].wait()
                case "/rest/db/status" where value == "folder-0": await gates[2].wait()
                case "/rest/db/status" where value == "folder-1": await gates[3].wait()
                case "/rest/db/completion" where value == "peer-0": await gates[4].wait()
                case "/rest/db/completion" where value == "peer-1": await gates[5].wait()
                default: break
                }
            }
            switch endpoint {
            case "/rest/system/config": return config
            case "/rest/db/status": return status
            case "/rest/db/completion": return Self.complete
            default: return nil
            }
        }
        fixture.client.requestRefresh()
        await fulfillment(of: gates.map(\.entered), timeout: 2)
        XCTAssertEqual(fixture.activeRequests, 6)
        fixture.settingsFixture.settings.manualAPIKey = "new-key"
        gates.dropLast().forEach { $0.release() }
        XCTAssertEqual(fixture.passes, 1)
        gates.last!.release()
        await fixture.client.waitForRefreshToFinish()
        XCTAssertEqual(fixture.passes, 2)
        XCTAssertEqual(fixture.maximumActiveRequests, 6)
        let obsoleteEntries = fixture.requests.filter {
            $0.value(forHTTPHeaderField: "X-API-Key") == "fixture-api-key" && $0.url!.path.hasPrefix("/rest/db/")
        }
        XCTAssertEqual(obsoleteEntries.count, 4, "Cancelled workers cannot launch later entries")
        XCTAssertEqual(fixture.client.folderStatuses.count, 6)
        XCTAssertEqual(fixture.client.deviceCompletions.count, 6)
        XCTAssertEqual(fixture.notifications, 0)
        await fixture.close()
    }

    @MainActor
    func testEntryFailureInvalidatesOnlyItsOwnCachedStatus() async throws {
        let fixture = await RefreshHarness.make()
        let config = try Self.config(entryCount: 4)
        let status = try SyncStatusTests.payload()
        var fail = false
        fixture.intercept = { request, _ in
            let endpoint = request.url!.path
            let value = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.first?.value
            if fail && (value == "folder-1" || value == "peer-1") { throw URLError(.timedOut) }
            switch endpoint {
            case "/rest/system/config": return config
            case "/rest/db/status": return status
            case "/rest/db/completion": return Self.complete
            default: return nil
            }
        }
        await fixture.client.refresh()
        fail = true
        await fixture.client.refresh()
        XCTAssertEqual(Set(fixture.client.folderStatuses.keys), ["folder-0", "folder-2", "folder-3"])
        XCTAssertEqual(Set(fixture.client.deviceCompletions.keys), ["peer-0", "peer-2", "peer-3"])
        XCTAssertTrue(fixture.client.isConnected)
        await fixture.close()
    }

    @MainActor
    func testDemoExitStartsFreshMonitoringWithoutRestoringOldStatus() async {
        let fixture = await RefreshHarness.make()
        fixture.client.startMonitoring()
        await fixture.client.waitForRefreshToFinish()
        fixture.client.enableDemoMode(deviceCount: 1, folderCount: 1)
        XCTAssertTrue(fixture.liveTimers.isEmpty)
        fixture.timerCallbacks[0]()
        await fixture.client.refresh()
        XCTAssertEqual(fixture.passes, 1)
        fixture.client.disableDemoMode()
        XCTAssertNil(fixture.client.systemStatus)
        XCTAssertTrue(fixture.client.folderStatuses.isEmpty)
        await fixture.client.waitForRefreshToFinish()
        XCTAssertEqual(fixture.passes, 2)
        XCTAssertEqual(fixture.liveTimers.count, 1)
        XCTAssertEqual(fixture.client.syncthingVersion, "current")
        await fixture.close()
    }

    @MainActor
    func testSlowFirstMiddleAndLastEntriesDoNotHoldFastEntries() async throws {
        for slowIndex in [0, 2, 5] {
            let fixture = await RefreshHarness.make()
            let folderGate = RefreshGate()
            let peerGate = RefreshGate()
            let config = try Self.config(entryCount: 6)
            let status = try SyncStatusTests.payload()
            fixture.intercept = { request, _ in
                let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.first?.value
                switch request.url!.path {
                case "/rest/system/config": return config
                case "/rest/db/status":
                    if query == "folder-\(slowIndex)" { await folderGate.wait() }
                    return status
                case "/rest/db/completion":
                    if query == "peer-\(slowIndex)" { await peerGate.wait() }
                    return Self.complete
                default: return nil
                }
            }
            let fastFolders = expectation(description: "all fast folders publish with slow \(slowIndex) held")
            let fastPeers = expectation(description: "all fast peers publish with slow \(slowIndex) held")
            let folderObserver = fixture.client.$folderStatuses.filter { $0.count == 5 }.prefix(1)
                .sink { _ in fastFolders.fulfill() }
            let peerObserver = fixture.client.$deviceCompletions.filter { $0.count == 5 }.prefix(1)
                .sink { _ in fastPeers.fulfill() }
            fixture.client.requestRefresh()
            await fulfillment(of: [folderGate.entered, peerGate.entered, fastFolders, fastPeers], timeout: 2)
            XCTAssertNil(fixture.client.folderStatuses["folder-\(slowIndex)"])
            XCTAssertNil(fixture.client.deviceCompletions["peer-\(slowIndex)"])
            folderGate.release()
            peerGate.release()
            await fixture.client.waitForRefreshToFinish()
            XCTAssertEqual(fixture.client.folderStatuses.count, 6)
            XCTAssertEqual(fixture.client.deviceCompletions.count, 6)
            XCTAssertLessThanOrEqual(fixture.maximumByEndpoint["/rest/db/status", default: 0], 2)
            XCTAssertLessThanOrEqual(fixture.maximumByEndpoint["/rest/db/completion", default: 0], 2)
            XCTAssertLessThanOrEqual(fixture.maximumActiveRequests, 6)
            withExtendedLifetime((folderObserver, peerObserver)) {}
            await fixture.close()
        }
    }

    @MainActor
    func testTimerAndManualBurstsCoalesceWithoutCancellingActiveRequest() async {
        let fixture = await RefreshHarness.make()
        let firstGate = RefreshGate()
        let secondGate = RefreshGate()
        fixture.intercept = { request, ordinal in
            guard request.url?.path == "/rest/system/status" else { return nil }
            if ordinal == 1 { await firstGate.wait() }
            if ordinal == 2 { await secondGate.wait() }
            XCTAssertFalse(Task.isCancelled)
            return nil
        }
        fixture.client.startMonitoring()
        await fulfillment(of: [firstGate.entered], timeout: 2)
        let manualCompleted = expectation(description: "manual refresh completed")
        var completions = 0
        for _ in 0..<20 {
            fixture.timerCallbacks[0]()
            fixture.client.requestRefresh { completions += 1 }
        }
        fixture.client.requestRefresh { manualCompleted.fulfill() }
        firstGate.release()
        await fulfillment(of: [secondGate.entered], timeout: 2)
        XCTAssertEqual(completions, 0)
        XCTAssertEqual(fixture.passes, 2)
        secondGate.release()
        await fulfillment(of: [manualCompleted], timeout: 2)
        await fixture.client.waitForRefreshToFinish()
        XCTAssertEqual(completions, 20)
        XCTAssertEqual(fixture.passes, 2)
        await fixture.close()
    }

    @MainActor
    func testManualCompletionDoesNotWaitForLaterTimerPass() async {
        let fixture = await RefreshHarness.make()
        let firstGate = RefreshGate()
        let nextGate = RefreshGate()
        fixture.intercept = { request, ordinal in
            guard request.url?.path == "/rest/system/status" else { return nil }
            if ordinal == 1 { await firstGate.wait() }
            if ordinal == 2 { await nextGate.wait() }
            return nil
        }
        let manualCompleted = expectation(description: "manual completes despite later work")
        fixture.client.requestRefresh { manualCompleted.fulfill() }
        await fulfillment(of: [firstGate.entered], timeout: 2)
        fixture.client.requestRefresh()
        firstGate.release()
        await fulfillment(of: [manualCompleted, nextGate.entered], timeout: 2)
        XCTAssertTrue(fixture.client.isRefreshing)
        nextGate.release()
        await fixture.client.waitForRefreshToFinish()
        await fixture.close()
    }

    @MainActor
    func testConnectionEditsAwaitOldUnwindAndUseLatestCredentials() async {
        for edit in ["url", "key", "grant", "discovery"] {
            let fixture = await RefreshHarness.make()
            let gate = RefreshGate()
            fixture.intercept = { request, ordinal in
                if request.url?.path == "/rest/system/status", ordinal == 1 { await gate.wait() }
                return nil
            }
            fixture.client.requestRefresh()
            await fulfillment(of: [gate.entered], timeout: 2)
            let initialRevision = fixture.client.cleanupConnectionRevision
            let settings = fixture.settingsFixture.settings
            switch edit {
            case "url":
                settings.baseURLString = "https://intermediate.invalid"
                settings.baseURLString = "https://latest.invalid"
            case "key":
                settings.manualAPIKey = "intermediate-key"
                settings.manualAPIKey = "latest-key"
            case "grant": settings.configBookmarkData = Data("invalid-fixture-bookmark".utf8)
            default:
                settings.useAutomaticDiscovery = true
                settings.useAutomaticDiscovery = false
            }
            XCTAssertNotEqual(initialRevision, fixture.client.cleanupConnectionRevision)
            XCTAssertEqual(fixture.passes, 1, "No overlapping pass while old request unwinds")
            gate.release()
            await fixture.client.waitForRefreshToFinish()
            XCTAssertEqual(fixture.passes, 2, edit)
            XCTAssertEqual(fixture.client.syncthingVersion, "current")
            let newRequests = fixture.requests.dropFirst()
            XCTAssertTrue(newRequests.allSatisfy {
                $0.url?.host == (edit == "url" ? "latest.invalid" : "syncthing.invalid")
            })
            XCTAssertTrue(newRequests.allSatisfy {
                $0.value(forHTTPHeaderField: "X-API-Key") == (edit == "key" ? "latest-key" : "fixture-api-key")
            })
            XCTAssertEqual(fixture.notifications, 0)
            await fixture.close()
        }
    }

    @MainActor
    func testRepeatedStartAndIntervalChangesKeepOneTimerDuringRefresh() async {
        let fixture = await RefreshHarness.make()
        let gate = RefreshGate()
        fixture.intercept = { request, ordinal in
            if request.url?.path == "/rest/system/status", ordinal == 1 { await gate.wait() }
            return nil
        }
        fixture.client.startMonitoring()
        fixture.client.startMonitoring()
        await fulfillment(of: [gate.entered], timeout: 2)
        fixture.settingsFixture.settings.refreshInterval = 15
        fixture.settingsFixture.settings.refreshInterval = 20
        XCTAssertEqual(fixture.liveTimers, [2])
        XCTAssertEqual(fixture.timerIntervals, [10, 15, 20])
        fixture.timerCallbacks[0]()
        fixture.timerCallbacks[1]()
        gate.release()
        await fixture.client.waitForRefreshToFinish()
        XCTAssertEqual(fixture.passes, 1, "Invalidated timer callbacks must do nothing")
        await fixture.close()
        XCTAssertTrue(fixture.liveTimers.isEmpty)
    }

    @MainActor
    func testShutdownRejectsLateSuccessAndQueuedTriggers() async {
        let fixture = await RefreshHarness.make()
        let gate = RefreshGate()
        fixture.intercept = { request, _ in
            if request.url?.path == "/rest/system/status" { await gate.wait() }
            return nil
        }
        fixture.client.startMonitoring()
        await fulfillment(of: [gate.entered], timeout: 2)
        var pendingCompleted = false
        fixture.client.requestRefresh { pendingCompleted = true }
        fixture.client.stopMonitoring()
        XCTAssertTrue(pendingCompleted)
        fixture.timerCallbacks[0]()
        fixture.settingsFixture.settings.manualAPIKey = "new-key"
        fixture.settingsFixture.settings.refreshInterval = 15
        fixture.client.startMonitoring()
        await fixture.client.refresh()
        gate.release()
        await fixture.client.waitForRefreshToFinish()
        XCTAssertEqual(fixture.passes, 1)
        XCTAssertNil(fixture.client.systemStatus)
        XCTAssertFalse(fixture.client.isRefreshing)
        XCTAssertTrue(fixture.liveTimers.isEmpty)
        await fixture.close()
    }

    @MainActor
    func testReplacementWaitsForActivePassAndIsNotDropped() async {
        let fixture = await RefreshHarness.make()
        let gate = RefreshGate()
        fixture.intercept = { request, ordinal in
            if request.url?.path == "/rest/system/status", ordinal == 1 { await gate.wait() }
            return nil
        }
        let first = Task { await fixture.client.refresh() }
        await fulfillment(of: [gate.entered], timeout: 2)

        // The second call must remain pending while the first pass is held.
        let replacement = Task { await fixture.client.refresh() }
        // A queued MainActor marker proves replacement had its turn to register.
        await Task { @MainActor in }.value
        gate.release()
        await first.value
        await replacement.value

        XCTAssertEqual(fixture.passes, 2, "Replacement refresh must survive cancellation unwind")
        XCTAssertEqual(fixture.client.syncthingVersion, "current")
        XCTAssertFalse(fixture.client.isRefreshing)
        await fixture.close()
    }

    @MainActor
    func testDemoEntryRejectsLateSuccessfulStatus() async {
        let fixture = await RefreshHarness.make()
        let gate = RefreshGate()
        fixture.intercept = { request, _ in
            if request.url?.path == "/rest/system/status" { await gate.wait() }
            return nil
        }
        let refresh = Task { await fixture.client.refresh() }
        await fulfillment(of: [gate.entered], timeout: 2)
        fixture.client.enableDemoMode(deviceCount: 1, folderCount: 1)
        gate.release()
        await refresh.value

        XCTAssertNil(fixture.client.systemStatus, "Late real results cannot publish into demo")
        XCTAssertEqual(fixture.requests.count, 1)
        XCTAssertEqual(fixture.notifications, 0)
        await fixture.close()
    }
}
