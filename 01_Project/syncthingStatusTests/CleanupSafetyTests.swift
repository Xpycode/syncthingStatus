import Foundation
import XCTest

final class CleanupSafetyTests: XCTestCase {
    func testValidatePathRejectsTraversalOutsideTemporaryRoot() throws {
        let temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("CleanupSafetyTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryRoot) }

        // This narrow baseline complements the controller cases below.
        XCTAssertNil(StuckDeletesController.validatePath("../outside", folderRoot: temporaryRoot))
    }

    @MainActor
    func testSelectedTraversalIsRejectedThroughProductionController() async throws {
        let fixture = try await CleanupFixture.make()
        addTeardownBlock { @MainActor in try await fixture.close() }
        let outside = try fixture.sentinel("outside/keep.txt")
        let unselected = try fixture.sentinel("Project/unselected/keep.txt")
        grantExactRoot(fixture)
        try await fixture.bootstrap()
        try fixture.enqueueCandidates(["unselected", "../outside"])
        let controller = try fixture.controller()
        await controller.loadCandidates()
        XCTAssertEqual(controller.candidates.map(\.name), ["../outside", "unselected"])
        let candidate = try XCTUnwrap(controller.candidates.first { $0.name == "../outside" })
        try fixture.enqueueDeletionPreflight()
        fixture.connection.http.enqueue("POST", "/rest/db/scan", json: "", status: 204)
        try fixture.enqueueCandidates(["../outside", "unselected"])

        let deletion = Task { await controller.performDeletion(selected: [candidate.id]) }
        await fulfillment(of: [fixture.gate.entered], timeout: 5)
        // Release before throwing assertions so a failed test cannot strand work.
        fixture.gate.open()
        await deletion.value

        XCTAssertEqual(controller.lastOutcome?.succeededCount, 0)
        XCTAssertEqual(controller.lastOutcome?.failed, [.init(name: "../outside", reason: "Path rejected by safety check")])
        XCTAssertFalse(controller.deleting)
        XCTAssertEqual(fixture.gate.calls, 1)
        XCTAssertEqual(fixture.scope.starts, [fixture.root, fixture.root])
        XCTAssertEqual(fixture.scope.stops, fixture.scope.starts)
        try fixture.assertSentinel(outside, "outside/keep.txt")
        try fixture.assertSentinel(unselected, "Project/unselected/keep.txt")
        assertCleanupRequests(fixture)
    }

    @MainActor
    func testExactRootGrantDeletesOnlySelectedCandidateAndReloads() async throws {
        let fixture = try await CleanupFixture.make()
        addTeardownBlock { @MainActor in try await fixture.close() }
        let selected = try fixture.sentinel("Project/selected/keep.txt")
        let unselected = try fixture.sentinel("Project/unselected/keep.txt")
        let sibling = try fixture.sentinel("selected/keep.txt")
        grantExactRoot(fixture)
        try await fixture.bootstrap()
        try fixture.enqueueCandidates(["unselected", "selected"])
        let controller = try fixture.controller()
        await controller.loadCandidates()
        let candidate = try XCTUnwrap(controller.candidates.first { $0.name == "selected" })
        try fixture.enqueueDeletionPreflight()
        fixture.connection.http.enqueue("POST", "/rest/db/scan", json: "", status: 204)
        try fixture.enqueueCandidates(["unselected"])

        let deletion = Task { await controller.performDeletion(selected: [candidate.id]) }
        await fulfillment(of: [fixture.gate.entered], timeout: 5)
        XCTAssertTrue(controller.deleting)
        XCTAssertEqual(controller.lastOutcome, DeletionOutcome(succeededCount: 1, failed: []))
        fixture.gate.open()
        await deletion.value

        XCTAssertFalse(FileManager.default.fileExists(atPath: selected.deletingLastPathComponent().path))
        try fixture.assertSentinel(unselected, "Project/unselected/keep.txt")
        try fixture.assertSentinel(sibling, "selected/keep.txt")
        XCTAssertEqual(controller.candidates.map(\.id), ["unselected"])
        XCTAssertFalse(controller.loading)
        XCTAssertFalse(controller.deleting)
        XCTAssertEqual(fixture.scope.starts, [fixture.root, fixture.root])
        XCTAssertEqual(fixture.scope.stops, fixture.scope.starts)
        assertCleanupRequests(fixture)
    }

    @MainActor
    func testMissingBookmarkBlocksSelectedDeletion() async throws {
        let fixture = try await CleanupFixture.make()
        addTeardownBlock { @MainActor in try await fixture.close() }
        let sentinel = try fixture.sentinel("Project/selected/keep.txt")
        try await fixture.bootstrap()
        try fixture.enqueueCandidates(["selected"])
        let controller = try fixture.controller()
        await controller.loadCandidates()
        let candidate = try XCTUnwrap(controller.candidates.first)

        await controller.performDeletion(selected: [candidate.id])

        XCTAssertTrue(controller.accessBlocked)
        XCTAssertNil(controller.lastOutcome)
        XCTAssertFalse(controller.deleting)
        XCTAssertTrue(fixture.scope.starts.isEmpty)
        XCTAssertEqual(fixture.gate.calls, 0)
        XCTAssertFalse(fixture.connection.http.requests.contains { $0.httpMethod == "POST" })
        try fixture.assertSentinel(sentinel, "Project/selected/keep.txt")
    }

    @MainActor
    func testStaleBookmarkRefreshesAndFalseScopeStartDoesNotImplyDenial() async throws {
        let fixture = try await CleanupFixture.make()
        addTeardownBlock { @MainActor in try await fixture.close() }
        fixture.bookmarks.result = .resolved(fixture.root, isStale: true)
        fixture.scope.startSucceeds = false
        try await fixture.bootstrap()
        let controller = try fixture.controller()

        controller.recheckAccess()

        XCTAssertFalse(controller.accessBlocked)
        XCTAssertNil(controller.lastError)
        XCTAssertEqual(fixture.bookmarks.refreshed, ["fixture-folder"])
        XCTAssertEqual(fixture.scope.starts, [fixture.root])
        XCTAssertTrue(fixture.scope.stops.isEmpty)
    }

    @MainActor
    func testRealBookmarkStoreMissingAndClearUseOnlyInjectedDefaults() async {
        let fixture = await SettingsFixture.make()
        addTeardownBlock { @MainActor in await fixture.close() }
        let store = FolderAccessBookmarks(defaults: fixture.defaults)
        XCTAssertNil(store.authorizationToken(for: "fixture-folder"))
        guard case .missing = store.resolve(for: "fixture-folder") else {
            return XCTFail("Fresh fixture should have no bookmark")
        }
        fixture.defaults.set(Data([1]), forKey: "FolderAccessBookmark.fixture-folder")
        fixture.defaults.set(Data([2]), forKey: "FolderAccessBookmark.other-folder")
        XCTAssertEqual(store.authorizationToken(for: "fixture-folder"), Data([1]))
        XCTAssertEqual(store.authorizationToken(for: "other-folder"), Data([2]))
        store.clear(for: "fixture-folder")
        XCTAssertNil(store.authorizationToken(for: "fixture-folder"))
        guard case .missing = store.resolve(for: "fixture-folder") else {
            return XCTFail("Cleared fixture bookmark should be missing")
        }
        XCTAssertEqual(fixture.defaults.data(forKey: "FolderAccessBookmark.other-folder"), Data([2]))
    }

    @MainActor
    func testAncestorGrantDeletesConfiguredChildAndPreservesSameNamedSibling() async throws {
        let fixture = try await CleanupFixture.make()
        addTeardownBlock { @MainActor in try await fixture.close() }
        let target = try fixture.sentinel("Project/selected/keep.txt")
        let sibling = try fixture.sentinel("selected/keep.txt")
        let unselected = try fixture.sentinel("Project/unselected/keep.txt")
        fixture.bookmarks.result = .resolved(fixture.directory, isStale: false)
        try await fixture.bootstrap()
        try fixture.enqueueCandidates(["selected", "unselected"])
        let controller = try fixture.controller()
        await controller.loadCandidates()
        let candidate = try XCTUnwrap(controller.candidates.first { $0.name == "selected" })
        try fixture.enqueueDeletionPreflight()
        try fixture.enqueueReconciliation(["unselected"])

        await controller.performDeletion(selected: [candidate.id])

        XCTAssertEqual(controller.lastOutcome, DeletionOutcome(succeededCount: 1, failed: []))
        XCTAssertFalse(FileManager.default.fileExists(atPath: target.path))
        try fixture.assertSentinel(sibling, "selected/keep.txt")
        try fixture.assertSentinel(unselected, "Project/unselected/keep.txt")
        XCTAssertEqual(fixture.scope.starts, [fixture.directory, fixture.directory])
        XCTAssertEqual(fixture.scope.stops, fixture.scope.starts)
        assertCleanupRequests(fixture)
    }

    @MainActor
    func testObsoleteBookmarkCannotDeleteFromFormerRoot() async throws {
        let fixture = try await CleanupFixture.make()
        addTeardownBlock { @MainActor in try await fixture.close() }
        let current = try fixture.sentinel("Project/selected/keep.txt")
        let old = try fixture.sentinel("OldProject/selected/keep.txt")
        fixture.bookmarks.result = .resolved(fixture.directory.appendingPathComponent("OldProject"), isStale: false)
        try await fixture.bootstrap()
        let controller = try await loadedController(fixture)

        await assertObsoleteDeletionBlocked(controller, fixture: fixture)

        try fixture.assertSentinel(current, "Project/selected/keep.txt")
        try fixture.assertSentinel(old, "OldProject/selected/keep.txt")
    }

    @MainActor
    func testPrefixCollisionBookmarkCannotAuthorizeConfiguredRoot() async throws {
        let fixture = try await CleanupFixture.make()
        addTeardownBlock { @MainActor in try await fixture.close() }
        let current = try fixture.sentinel("Project/selected/keep.txt")
        let collision = try fixture.sentinel("Project-other/selected/keep.txt")
        fixture.bookmarks.result = .resolved(fixture.directory.appendingPathComponent("Project-other"), isStale: false)
        try await fixture.bootstrap()
        let controller = try await loadedController(fixture)

        await assertObsoleteDeletionBlocked(controller, fixture: fixture)

        try fixture.assertSentinel(current, "Project/selected/keep.txt")
        try fixture.assertSentinel(collision, "Project-other/selected/keep.txt")
    }

    @MainActor
    func testStaleWindowCannotDeleteAfterConfiguredPathChangesUnderBroadGrant() async throws {
        let fixture = try await CleanupFixture.make()
        addTeardownBlock { @MainActor in try await fixture.close() }
        let old = try fixture.sentinel("Project/selected/keep.txt")
        let current = try fixture.sentinel("NewProject/selected/keep.txt")
        let sibling = try fixture.sentinel("selected/keep.txt")
        fixture.bookmarks.result = .resolved(fixture.directory, isStale: false)
        try await fixture.bootstrap()
        let controller = try await loadedController(fixture)
        try await fixture.refreshFolders([fixture.configuredFolder(path: fixture.directory.appendingPathComponent("NewProject"))])

        await assertObsoleteDeletionBlocked(controller, fixture: fixture)

        try fixture.assertSentinel(old, "Project/selected/keep.txt")
        try fixture.assertSentinel(current, "NewProject/selected/keep.txt")
        try fixture.assertSentinel(sibling, "selected/keep.txt")
    }

    @MainActor
    func testRemovedFolderCannotBeDeletedByOpenWindow() async throws {
        let fixture = try await CleanupFixture.make()
        addTeardownBlock { @MainActor in try await fixture.close() }
        let target = try fixture.sentinel("Project/selected/keep.txt")
        let sibling = try fixture.sentinel("selected/keep.txt")
        grantExactRoot(fixture)
        try await fixture.bootstrap()
        let controller = try await loadedController(fixture)
        try await fixture.refreshFolders([])

        await assertObsoleteDeletionBlocked(controller, fixture: fixture)

        try fixture.assertSentinel(target, "Project/selected/keep.txt")
        try fixture.assertSentinel(sibling, "selected/keep.txt")
    }

    @MainActor
    func testReusedPathWithDifferentFolderIDCannotBeDeletedByOpenWindow() async throws {
        let fixture = try await CleanupFixture.make()
        addTeardownBlock { @MainActor in try await fixture.close() }
        let target = try fixture.sentinel("Project/selected/keep.txt")
        let sibling = try fixture.sentinel("selected/keep.txt")
        grantExactRoot(fixture)
        try await fixture.bootstrap()
        let controller = try await loadedController(fixture)
        try await fixture.refreshFolders([fixture.configuredFolder(id: "replacement-folder")])

        await assertObsoleteDeletionBlocked(controller, fixture: fixture)

        try fixture.assertSentinel(target, "Project/selected/keep.txt")
        try fixture.assertSentinel(sibling, "selected/keep.txt")
    }

    @MainActor
    func testChangedConnectionWithReusedFolderIDInvalidatesOpenWindowImmediately() async throws {
        let fixture = try await CleanupFixture.make()
        addTeardownBlock { @MainActor in try await fixture.close() }
        let target = try fixture.sentinel("Project/selected/keep.txt")
        let sibling = try fixture.sentinel("selected/keep.txt")
        grantExactRoot(fixture)
        try await fixture.bootstrap()
        let controller = try await loadedController(fixture)
        // Same intercepted host, different reverse-proxy daemon. Do not wait for
        // the debounced refresh: the old selection becomes obsolete immediately.
        fixture.connection.settingsFixture.settings.baseURLString = fixture.connection.http.baseURL.absoluteString + "/replacement"

        await assertObsoleteDeletionBlocked(controller, fixture: fixture)

        try fixture.assertSentinel(target, "Project/selected/keep.txt")
        try fixture.assertSentinel(sibling, "selected/keep.txt")
    }

    @MainActor
    func testChangedCredentialsInvalidateOpenWindowImmediately() async throws {
        let fixture = try await CleanupFixture.make()
        addTeardownBlock { @MainActor in try await fixture.close() }
        let target = try fixture.sentinel("Project/selected/keep.txt")
        let sibling = try fixture.sentinel("selected/keep.txt")
        grantExactRoot(fixture)
        try await fixture.bootstrap()
        let controller = try await loadedController(fixture)
        fixture.connection.settingsFixture.settings.manualAPIKey = "replacement-fixture-key"

        await assertObsoleteDeletionBlocked(controller, fixture: fixture)

        try fixture.assertSentinel(target, "Project/selected/keep.txt")
        try fixture.assertSentinel(sibling, "selected/keep.txt")
    }

    @MainActor
    func testRevokedBookmarkAfterCandidateLoadPreservesSelectedAndSibling() async throws {
        let fixture = try await CleanupFixture.make()
        addTeardownBlock { @MainActor in try await fixture.close() }
        let target = try fixture.sentinel("Project/selected/keep.txt")
        let sibling = try fixture.sentinel("selected/keep.txt")
        grantExactRoot(fixture)
        try await fixture.bootstrap()
        let controller = try await loadedController(fixture)
        controller.recheckAccess()
        fixture.bookmarks.result = .failed(CocoaError(.fileReadNoPermission))

        await assertObsoleteDeletionBlocked(controller, fixture: fixture)

        XCTAssertTrue(controller.accessBlocked)
        try fixture.assertSentinel(target, "Project/selected/keep.txt")
        try fixture.assertSentinel(sibling, "selected/keep.txt")
        XCTAssertEqual(fixture.scope.stops, fixture.scope.starts)
    }

    @MainActor
    func testUnsafeCandidatePathsAreRejectedWithoutLosingSentinels() async throws {
        let fixture = try await CleanupFixture.make()
        addTeardownBlock { @MainActor in try await fixture.close() }
        let selected = try fixture.sentinel("Project/selected/keep.txt")
        let outside = try fixture.sentinel("outside/keep.txt")
        let collision = try fixture.sentinel("Project-other/keep.txt")
        try FileManager.default.createSymbolicLink(at: fixture.root.appendingPathComponent("escape"),
                                                   withDestinationURL: outside.deletingLastPathComponent())
        try FileManager.default.createSymbolicLink(at: fixture.root.appendingPathComponent("prefix-escape"),
                                                   withDestinationURL: collision.deletingLastPathComponent())
        try FileManager.default.createSymbolicLink(at: fixture.root.appendingPathComponent("root-loop"),
                                                   withDestinationURL: fixture.root)
        let unsafe = [".", "./selected", "selected/..", "nested/../selected", "../outside", "selected\0suffix",
                      outside.deletingLastPathComponent().path, "escape", "escape/keep.txt", "prefix-escape", "root-loop"]
        grantExactRoot(fixture)
        try await fixture.bootstrap()
        try fixture.enqueueCandidates(unsafe)
        let controller = try fixture.controller()
        await controller.loadCandidates()
        XCTAssertEqual(Set(controller.candidates.map(\.name)), Set(unsafe))
        try fixture.enqueueDeletionPreflight(count: unsafe.count)
        try fixture.enqueueReconciliation(unsafe)

        await controller.performDeletion(selected: Set(controller.candidates.map(\.id)))

        XCTAssertEqual(controller.lastOutcome?.succeededCount, 0)
        XCTAssertEqual(Set(controller.lastOutcome?.failed.map(\.name) ?? []), Set(unsafe))
        XCTAssertTrue(controller.lastOutcome?.failed.allSatisfy { $0.reason == "Path rejected by safety check" } == true)
        try fixture.assertSentinel(selected, "Project/selected/keep.txt")
        try fixture.assertSentinel(outside, "outside/keep.txt")
        try fixture.assertSentinel(collision, "Project-other/keep.txt")
    }

    @MainActor
    func testEmptyCandidateCannotBecomeSelectedDeletion() async throws {
        let fixture = try await CleanupFixture.make()
        addTeardownBlock { @MainActor in try await fixture.close() }
        let target = try fixture.sentinel("Project/selected/keep.txt")
        let sibling = try fixture.sentinel("selected/keep.txt")
        grantExactRoot(fixture)
        try await fixture.bootstrap()
        try fixture.enqueueCandidates(["", "selected"])
        let controller = try fixture.controller()
        await controller.loadCandidates()
        XCTAssertEqual(controller.candidates.map(\.name), ["selected"])
        XCTAssertNil(StuckDeletesController.validatePath("", folderRoot: fixture.root))

        await controller.performDeletion(selected: [""])

        XCTAssertNil(controller.lastOutcome)
        XCTAssertFalse(fixture.connection.http.requests.contains { $0.httpMethod == "POST" })
        try fixture.assertSentinel(target, "Project/selected/keep.txt")
        try fixture.assertSentinel(sibling, "selected/keep.txt")
    }

    @MainActor
    func testAlreadyGoneCandidateRemainsIdempotentAndPreservesSibling() async throws {
        let fixture = try await CleanupFixture.make()
        addTeardownBlock { @MainActor in try await fixture.close() }
        let sibling = try fixture.sentinel("selected/keep.txt")
        let unselected = try fixture.sentinel("Project/unselected/keep.txt")
        grantExactRoot(fixture)
        try await fixture.bootstrap()
        let controller = try await loadedController(fixture)
        try fixture.enqueueDeletionPreflight()
        try fixture.enqueueReconciliation([])

        await controller.performDeletion(selected: ["selected"])

        XCTAssertEqual(controller.lastOutcome, DeletionOutcome(succeededCount: 1, failed: []))
        try fixture.assertSentinel(sibling, "selected/keep.txt")
        try fixture.assertSentinel(unselected, "Project/unselected/keep.txt")
        assertCleanupRequests(fixture)
    }

    @MainActor
    func testDeletingDirectoryUnlinksNestedSymlinkAndPreservesExternalTarget() async throws {
        let fixture = try await CleanupFixture.make()
        addTeardownBlock { @MainActor in try await fixture.close() }
        let target = try fixture.sentinel("Project/selected/keep.txt")
        let outside = try fixture.sentinel("outside/keep.txt")
        try FileManager.default.createSymbolicLink(at: target.deletingLastPathComponent().appendingPathComponent("link"),
                                                   withDestinationURL: outside.deletingLastPathComponent())
        grantExactRoot(fixture)
        try await fixture.bootstrap()
        let controller = try await loadedController(fixture)
        try fixture.enqueueDeletionPreflight()
        try fixture.enqueueReconciliation([])

        await controller.performDeletion(selected: ["selected"])

        XCTAssertEqual(controller.lastOutcome, DeletionOutcome(succeededCount: 1, failed: []))
        XCTAssertFalse(FileManager.default.fileExists(atPath: target.deletingLastPathComponent().path))
        try fixture.assertSentinel(outside, "outside/keep.txt")
    }

    @MainActor
    func testAuthoritativeConfigPathChangeBlocksDeletionBeforeCachedRefresh() async throws {
        let fixture = try await CleanupFixture.make()
        addTeardownBlock { @MainActor in try await fixture.close() }
        let old = try fixture.sentinel("Project/selected/keep.txt")
        let current = try fixture.sentinel("NewProject/selected/keep.txt")
        let sibling = try fixture.sentinel("selected/keep.txt")
        fixture.bookmarks.result = .resolved(fixture.directory, isStale: false)
        try await fixture.bootstrap()
        let controller = try await loadedController(fixture)
        try fixture.enqueueDeletionPreflight(folder: fixture.configuredFolder(path: fixture.directory.appendingPathComponent("NewProject")))
        XCTAssertEqual(fixture.connection.client.folders.first?.path, fixture.root.path)

        await assertObsoleteDeletionBlocked(controller, fixture: fixture)

        try fixture.assertSentinel(old, "Project/selected/keep.txt")
        try fixture.assertSentinel(current, "NewProject/selected/keep.txt")
        try fixture.assertSentinel(sibling, "selected/keep.txt")
    }

    @MainActor
    func testAuthoritativeConfigMismatchedIDCannotAuthorizeDeletion() async throws {
        let fixture = try await CleanupFixture.make()
        addTeardownBlock { @MainActor in try await fixture.close() }
        let target = try fixture.sentinel("Project/selected/keep.txt")
        let sibling = try fixture.sentinel("selected/keep.txt")
        grantExactRoot(fixture)
        try await fixture.bootstrap()
        let controller = try await loadedController(fixture)
        try fixture.enqueueDeletionPreflight(folder: fixture.configuredFolder(id: "replacement-folder"))

        await assertObsoleteDeletionBlocked(controller, fixture: fixture)

        try fixture.assertSentinel(target, "Project/selected/keep.txt")
        try fixture.assertSentinel(sibling, "selected/keep.txt")
    }

    @MainActor
    func testUnavailableAuthoritativeConfigCannotFallBackToCachedRoot() async throws {
        let fixture = try await CleanupFixture.make()
        addTeardownBlock { @MainActor in try await fixture.close() }
        let target = try fixture.sentinel("Project/selected/keep.txt")
        let sibling = try fixture.sentinel("selected/keep.txt")
        grantExactRoot(fixture)
        try await fixture.bootstrap()
        let controller = try await loadedController(fixture)
        fixture.connection.http.enqueue("/rest/system/status", json: #"{"myID":"fixture-local","uptime":123}"#)
        fixture.connection.http.enqueue("/rest/config/folders/fixture-folder", json: #"{"error":"folder removed"}"#, status: 404)

        await assertObsoleteDeletionBlocked(controller, fixture: fixture)

        try fixture.assertSentinel(target, "Project/selected/keep.txt")
        try fixture.assertSentinel(sibling, "selected/keep.txt")
    }

    @MainActor
    func testChangedDaemonBehindSameAddressAndFolderIDCannotDeleteOldRoot() async throws {
        let fixture = try await CleanupFixture.make()
        addTeardownBlock { @MainActor in try await fixture.close() }
        let target = try fixture.sentinel("Project/selected/keep.txt")
        let sibling = try fixture.sentinel("selected/keep.txt")
        grantExactRoot(fixture)
        try await fixture.bootstrap()
        let controller = try await loadedController(fixture)
        fixture.connection.http.enqueue("/rest/system/status", json: #"{"myID":"replacement-daemon","uptime":123}"#)

        await assertObsoleteDeletionBlocked(controller, fixture: fixture)

        try fixture.assertSentinel(target, "Project/selected/keep.txt")
        try fixture.assertSentinel(sibling, "selected/keep.txt")
    }

    @MainActor
    func testUnavailableDaemonIdentityCannotAuthorizeDeletion() async throws {
        let fixture = try await CleanupFixture.make()
        addTeardownBlock { @MainActor in try await fixture.close() }
        let target = try fixture.sentinel("Project/selected/keep.txt")
        let sibling = try fixture.sentinel("selected/keep.txt")
        grantExactRoot(fixture)
        try await fixture.bootstrap()
        let controller = try await loadedController(fixture)
        fixture.connection.http.enqueue("/rest/system/status", json: #"{"error":"unavailable"}"#, status: 503)

        await assertObsoleteDeletionBlocked(controller, fixture: fixture)

        try fixture.assertSentinel(target, "Project/selected/keep.txt")
        try fixture.assertSentinel(sibling, "selected/keep.txt")
    }

    @MainActor
    func testCanonicalPathAliasStillDeletesConfiguredCandidate() async throws {
        let fixture = try await CleanupFixture.make()
        addTeardownBlock { @MainActor in try await fixture.close() }
        let target = try fixture.sentinel("Project/selected/keep.txt")
        let sibling = try fixture.sentinel("selected/keep.txt")
        let alias = fixture.directory.appendingPathComponent("ProjectAlias")
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: fixture.root)
        grantExactRoot(fixture)
        try await fixture.bootstrap()
        let controller = try await loadedController(fixture)
        let aliasedFolder = fixture.configuredFolder(path: alias)
        try await fixture.refreshFolders([aliasedFolder])
        try fixture.enqueueDeletionPreflight(folder: aliasedFolder)
        try fixture.enqueueReconciliation([])

        await controller.performDeletion(selected: ["selected"])

        XCTAssertEqual(controller.lastOutcome, DeletionOutcome(succeededCount: 1, failed: []))
        XCTAssertFalse(FileManager.default.fileExists(atPath: target.path))
        try fixture.assertSentinel(sibling, "selected/keep.txt")
        XCTAssertEqual(fixture.scope.stops, fixture.scope.starts)
    }

    @MainActor
    func testExplicitConfirmationRejectsSelectionDriftAndNamesReviewedRoot() async throws {
        let fixture = try await CleanupFixture.make()
        addTeardownBlock { @MainActor in try await fixture.close() }
        let selected = try fixture.sentinel("Project/selected/keep.txt")
        let other = try fixture.sentinel("Project/other/keep.txt")
        grantExactRoot(fixture)
        try await fixture.bootstrap()
        try fixture.enqueueCandidates(["selected", "other"])
        let controller = try fixture.controller()
        await controller.loadCandidates()
        let review = try XCTUnwrap(controller.prepareDeletion(selected: ["selected"]))
        XCTAssertEqual(review.rootPath, fixture.root.path)
        XCTAssertEqual(review.names, ["selected"])

        await controller.performDeletion(confirmation: review, selected: ["other"])

        XCTAssertNil(controller.confirmation)
        XCTAssertNil(controller.lastOutcome)
        XCTAssertNotNil(controller.lastError)
        XCTAssertFalse(fixture.connection.http.requests.contains { $0.httpMethod == "POST" })
        try fixture.assertSentinel(selected, "Project/selected/keep.txt")
        try fixture.assertSentinel(other, "Project/other/keep.txt")
    }

    @MainActor
    func testReloadAccessRequestAndCancelInvalidatePreviouslyReviewedConfirmation() async throws {
        for action in ["reload", "access", "cancel"] {
            let fixture = try await CleanupFixture.make()
            addTeardownBlock { @MainActor in try await fixture.close() }
            let target = try fixture.sentinel("Project/selected/keep.txt")
            let sibling = try fixture.sentinel("selected/keep.txt")
            grantExactRoot(fixture)
            try await fixture.bootstrap()
            let controller = try await loadedController(fixture)
            let review = try XCTUnwrap(controller.prepareDeletion(selected: ["selected"]))
            switch action {
            case "reload":
                try fixture.enqueueCandidates(["selected"])
                await controller.loadCandidates()
            case "access": controller.requestAccess()
            default: controller.invalidateConfirmation() // The confirmation sheet's Cancel action.
            }

            await controller.performDeletion(confirmation: review, selected: ["selected"])

            XCTAssertNil(controller.confirmation, action)
            XCTAssertNil(controller.lastOutcome, action)
            XCTAssertNotNil(controller.lastError, action)
            XCTAssertFalse(fixture.connection.http.requests.contains { $0.httpMethod == "POST" }, action)
            try fixture.assertSentinel(target, "Project/selected/keep.txt")
            try fixture.assertSentinel(sibling, "selected/keep.txt")
        }
    }

    @MainActor
    func testFailedPreflightRetainsReviewedCandidatesForRetry() async throws {
        let fixture = try await CleanupFixture.make()
        addTeardownBlock { @MainActor in try await fixture.close() }
        let target = try fixture.sentinel("Project/selected/keep.txt")
        grantExactRoot(fixture)
        try await fixture.bootstrap()
        let controller = try await loadedController(fixture)
        let selection: Set<String> = ["selected"]
        let review = try XCTUnwrap(controller.prepareDeletion(selected: selection))
        fixture.connection.http.enqueue("/rest/system/status", json: #"{"error":"offline"}"#, status: 503)

        await controller.performDeletion(confirmation: review, selected: selection)

        XCTAssertEqual(controller.lastOutcome?.succeededCount, 0)
        XCTAssertEqual(controller.lastOutcome?.failed.map(\.name), ["selected"])
        XCTAssertEqual(Set(controller.candidates.map(\.id)), selection)
        XCTAssertNotNil(controller.prepareDeletion(selected: selection))
        try fixture.assertSentinel(target, "Project/selected/keep.txt")
        XCTAssertFalse(fixture.connection.http.requests.contains { $0.httpMethod == "POST" })
    }

    @MainActor
    func testPartialOutcomeRemovesSuccessAndRetainsFailedCandidateAfterReload() async throws {
        let fixture = try await CleanupFixture.make()
        addTeardownBlock { @MainActor in try await fixture.close() }
        let target = try fixture.sentinel("Project/selected/keep.txt")
        let outside = try fixture.sentinel("outside/keep.txt")
        grantExactRoot(fixture)
        try await fixture.bootstrap()
        try fixture.enqueueCandidates(["selected", "../outside"])
        let controller = try fixture.controller()
        await controller.loadCandidates()
        let review = try XCTUnwrap(controller.prepareDeletion(selected: ["selected", "../outside"]))
        try fixture.enqueueDeletionPreflight(count: 2)
        // Even if the daemon's next list omits the failed item, keep it reviewable.
        try fixture.enqueueReconciliation([])

        await controller.performDeletion(confirmation: review, selected: ["selected", "../outside"])

        XCTAssertEqual(controller.lastOutcome, DeletionOutcome(succeededCount: 1,
            failed: [.init(name: "../outside", reason: "Path rejected by safety check")]))
        XCTAssertEqual(controller.candidates.map(\.id), ["../outside"])
        XCTAssertFalse(FileManager.default.fileExists(atPath: target.path))
        try fixture.assertSentinel(outside, "outside/keep.txt")
    }

    @MainActor
    func testRescanFailurePreservesDeletionOutcomeAndUnselectedCandidates() async throws {
        let fixture = try await CleanupFixture.make()
        addTeardownBlock { @MainActor in try await fixture.close() }
        let target = try fixture.sentinel("Project/selected/keep.txt")
        let unselected = try fixture.sentinel("Project/unselected/keep.txt")
        grantExactRoot(fixture)
        try await fixture.bootstrap()
        try fixture.enqueueCandidates(["selected", "unselected"])
        let controller = try fixture.controller()
        await controller.loadCandidates()
        let review = try XCTUnwrap(controller.prepareDeletion(selected: ["selected"]))
        try fixture.enqueueDeletionPreflight()
        fixture.connection.http.enqueue("POST", "/rest/db/scan", json: #"{"error":"unavailable"}"#, status: 503)

        await controller.performDeletion(confirmation: review, selected: ["selected"])

        XCTAssertEqual(controller.lastOutcome, DeletionOutcome(succeededCount: 1, failed: []))
        XCTAssertTrue(controller.lastError?.contains("could not be rescanned") == true)
        XCTAssertEqual(controller.candidates.map(\.id), ["unselected"])
        XCTAssertEqual(fixture.gate.calls, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: target.path))
        try fixture.assertSentinel(unselected, "Project/unselected/keep.txt")
    }

    @MainActor
    func testConfigurationChangeBetweenItemsPreservesRemainingOldAndNewTargets() async throws {
        let fixture = try await CleanupFixture.make()
        addTeardownBlock { @MainActor in try await fixture.close() }
        let first = try fixture.sentinel("Project/a/keep.txt")
        let remaining = try fixture.sentinel("Project/b/keep.txt")
        let newRoot = try fixture.sentinel("NewProject/b/keep.txt")
        let sibling = try fixture.sentinel("b/keep.txt")
        fixture.bookmarks.result = .resolved(fixture.directory, isStale: false)
        try await fixture.bootstrap()
        try fixture.enqueueCandidates(["a", "b"])
        let controller = try fixture.controller()
        await controller.loadCandidates()
        try fixture.enqueueDeletionPreflight()
        try fixture.enqueueDeletionPreflight(folder: fixture.configuredFolder(path: fixture.directory.appendingPathComponent("NewProject")))

        await controller.performDeletion(selected: ["a", "b"])

        XCTAssertEqual(controller.lastOutcome?.succeededCount, 1)
        XCTAssertEqual(controller.lastOutcome?.failed.map(\.name), ["b"])
        XCTAssertEqual(controller.candidates.map(\.id), ["b"])
        XCTAssertTrue(controller.obsolete)
        XCTAssertFalse(FileManager.default.fileExists(atPath: first.path))
        try fixture.assertSentinel(remaining, "Project/b/keep.txt")
        try fixture.assertSentinel(newRoot, "NewProject/b/keep.txt")
        try fixture.assertSentinel(sibling, "b/keep.txt")
        XCTAssertFalse(fixture.connection.http.requests.contains { $0.httpMethod == "POST" })
    }

    @MainActor
    func testConnectionChangeWhilePreflightIsSuspendedCannotDelete() async throws {
        let fixture = try await CleanupFixture.make()
        let responseGate = HTTPReplyGate()
        addTeardownBlock { @MainActor in responseGate.open(); try await fixture.close() }
        let target = try fixture.sentinel("Project/selected/keep.txt")
        let sibling = try fixture.sentinel("selected/keep.txt")
        grantExactRoot(fixture)
        try await fixture.bootstrap()
        let controller = try await loadedController(fixture)
        fixture.connection.http.enqueue("/rest/system/status", json: #"{"myID":"fixture-local","uptime":123}"#, gate: responseGate)
        let deletion = Task { await controller.performDeletion(selected: ["selected"]) }
        await fulfillment(of: [responseGate.entered], timeout: 5)
        fixture.connection.settingsFixture.settings.manualAPIKey = "replacement-fixture-key"
        responseGate.open()
        await deletion.value

        XCTAssertEqual(controller.lastOutcome?.succeededCount, 0)
        XCTAssertTrue(controller.obsolete)
        XCTAssertFalse(controller.deleting)
        try fixture.assertSentinel(target, "Project/selected/keep.txt")
        try fixture.assertSentinel(sibling, "selected/keep.txt")
        XCTAssertFalse(fixture.connection.http.requests.contains { $0.httpMethod == "POST" })
        XCTAssertEqual(fixture.scope.stops, fixture.scope.starts)
    }

    @MainActor
    func testCancellationWhilePreflightIsSuspendedPreservesSelectedCandidate() async throws {
        let fixture = try await CleanupFixture.make()
        let responseGate = HTTPReplyGate()
        addTeardownBlock { @MainActor in responseGate.open(); try await fixture.close() }
        let target = try fixture.sentinel("Project/selected/keep.txt")
        let sibling = try fixture.sentinel("selected/keep.txt")
        grantExactRoot(fixture)
        try await fixture.bootstrap()
        let controller = try await loadedController(fixture)
        fixture.connection.http.enqueue("/rest/system/status", json: #"{"myID":"fixture-local","uptime":123}"#, gate: responseGate)
        let deletion = Task { await controller.performDeletion(selected: ["selected"]) }
        await fulfillment(of: [responseGate.entered], timeout: 5)
        deletion.cancel()
        responseGate.open()
        await deletion.value

        XCTAssertEqual(controller.lastOutcome?.succeededCount, 0)
        XCTAssertEqual(controller.candidates.map(\.id), ["selected"])
        XCTAssertTrue(controller.lastError?.contains("cancelled") == true)
        XCTAssertFalse(controller.deleting)
        try fixture.assertSentinel(target, "Project/selected/keep.txt")
        try fixture.assertSentinel(sibling, "selected/keep.txt")
        XCTAssertFalse(fixture.connection.http.requests.contains { $0.httpMethod == "POST" })
        XCTAssertEqual(fixture.scope.stops, fixture.scope.starts)
    }

    @MainActor
    func testFolderIDIsEncodedAsOnePreflightPathComponent() async throws {
        let fixture = try await CleanupFixture.make()
        addTeardownBlock { @MainActor in try await fixture.close() }
        let id = "fixture/folder ?#%"
        let folder = fixture.configuredFolder(id: id)
        try await fixture.refreshFolders([folder])
        fixture.connection.http.enqueue("/rest/system/status", json: #"{"myID":"fixture-local","uptime":123}"#)
        let path = "/rest/config/folders/fixture%2Ffolder%20%3F%23%25"
        var expected = URLComponents(url: fixture.connection.http.baseURL, resolvingAgainstBaseURL: false)!
        expected.percentEncodedPath = path
        let json = String(decoding: try JSONEncoder().encode(folder), as: UTF8.self)
        fixture.connection.http.enqueue(expected.url!.path, json: json)

        let fetched = try await fixture.connection.client.fetchCleanupFolder(id: id,
            revision: fixture.connection.client.cleanupConnectionRevision, deviceID: "fixture-local")

        XCTAssertEqual(fetched.id, id)
        let request = try XCTUnwrap(fixture.connection.http.requests.last)
        let components = try XCTUnwrap(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.percentEncodedPath, path)
        XCTAssertNil(components.query)
        XCTAssertNil(components.fragment)
    }

    @MainActor
    func testReplacingExactGrantWithAncestorInvalidatesReviewedConfirmation() async throws {
        try await assertBookmarkReplacementInvalidatesReview(useAncestor: true)
    }

    @MainActor
    func testReplacingRootDirectoryAtReviewedPathPreservesOldAndNewContents() async throws {
        let fixture = try await CleanupFixture.make()
        addTeardownBlock { @MainActor in try await fixture.close() }
        try fixture.sentinel("Project/selected/old.txt")
        let sibling = try fixture.sentinel("selected/keep.txt")
        fixture.bookmarks.result = .resolved(fixture.directory, isStale: false)
        try await fixture.bootstrap()
        let controller = try await loadedController(fixture)
        let review = try XCTUnwrap(controller.prepareDeletion(selected: ["selected"]))
        let retiredRoot = fixture.directory.appendingPathComponent("RetiredProject")
        try FileManager.default.moveItem(at: fixture.root, to: retiredRoot)
        let oldTarget = retiredRoot.appendingPathComponent("selected/old.txt")
        let newTarget = try fixture.sentinel("Project/selected/new.txt")
        let requestCountBeforeDeletion = fixture.connection.http.requests.count

        await controller.performDeletion(confirmation: review, selected: ["selected"])

        XCTAssertTrue(controller.obsolete)
        XCTAssertNil(controller.confirmation)
        XCTAssertNil(controller.lastOutcome)
        XCTAssertNotNil(controller.lastError)
        XCTAssertFalse(controller.deleting)
        XCTAssertEqual(controller.candidates.map(\.id), ["selected"])
        XCTAssertEqual(fixture.connection.http.requests.count, requestCountBeforeDeletion)
        XCTAssertTrue(fixture.scope.starts.isEmpty)
        XCTAssertEqual(fixture.gate.calls, 0)
        try fixture.assertSentinel(oldTarget, "Project/selected/old.txt")
        try fixture.assertSentinel(newTarget, "Project/selected/new.txt")
        try fixture.assertSentinel(sibling, "selected/keep.txt")
    }

    @MainActor
    func testReplacingGrantForSameScopeInvalidatesReviewedConfirmation() async throws {
        try await assertBookmarkReplacementInvalidatesReview(useAncestor: false)
    }

    @MainActor
    func testSameScopeGrantReplacementDuringSecondPreflightPreservesRemainingItem() async throws {
        let fixture = try await CleanupFixture.make()
        let responseGate = HTTPReplyGate()
        addTeardownBlock { @MainActor in responseGate.open(); try await fixture.close() }
        let first = try fixture.sentinel("Project/a/keep.txt")
        let remaining = try fixture.sentinel("Project/b/keep.txt")
        let sibling = try fixture.sentinel("b/keep.txt")
        grantExactRoot(fixture)
        try await fixture.bootstrap()
        try fixture.enqueueCandidates(["a", "b"])
        let controller = try fixture.controller()
        await controller.loadCandidates()
        let review = try XCTUnwrap(controller.prepareDeletion(selected: ["a", "b"]))
        try fixture.enqueueDeletionPreflight()
        fixture.connection.http.enqueue("/rest/system/status", json: #"{"myID":"fixture-local","uptime":123}"#)
        let json = String(decoding: try JSONEncoder().encode(fixture.configuredFolder()), as: UTF8.self)
        fixture.connection.http.enqueue("/rest/config/folders/fixture-folder", json: json, gate: responseGate)
        let deletion = Task { await controller.performDeletion(confirmation: review, selected: ["a", "b"]) }
        await fulfillment(of: [responseGate.entered], timeout: 5)
        XCTAssertFalse(FileManager.default.fileExists(atPath: first.path))
        try fixture.bookmarks.save(fixture.root, for: "fixture-folder")
        responseGate.open()
        await deletion.value

        XCTAssertEqual(controller.lastOutcome?.succeededCount, 1)
        XCTAssertEqual(controller.lastOutcome?.failed.map(\.name), ["b"])
        XCTAssertEqual(controller.candidates.map(\.id), ["b"])
        XCTAssertNil(controller.confirmation)
        XCTAssertNotNil(controller.lastError)
        XCTAssertFalse(controller.deleting)
        try fixture.assertSentinel(remaining, "Project/b/keep.txt")
        try fixture.assertSentinel(sibling, "b/keep.txt")
        XCTAssertFalse(fixture.connection.http.requests.contains { $0.httpMethod == "POST" })
        XCTAssertEqual(fixture.scope.stops, fixture.scope.starts)
    }

    @MainActor
    func testOwnStaleBookmarkRefreshCanCompleteReviewedDeletion() async throws {
        let fixture = try await CleanupFixture.make()
        addTeardownBlock { @MainActor in try await fixture.close() }
        let target = try fixture.sentinel("Project/selected/keep.txt")
        let sibling = try fixture.sentinel("selected/keep.txt")
        fixture.bookmarks.result = .resolved(fixture.root, isStale: true)
        fixture.bookmarks.replaceTokenOnRefresh = true
        try await fixture.bootstrap()
        let controller = try await loadedController(fixture)
        let review = try XCTUnwrap(controller.prepareDeletion(selected: ["selected"]))
        let oldToken = fixture.bookmarks.authorizationToken(for: "fixture-folder")
        try fixture.enqueueDeletionPreflight()
        try fixture.enqueueReconciliation([])

        await controller.performDeletion(confirmation: review, selected: ["selected"])

        XCTAssertNotEqual(fixture.bookmarks.authorizationToken(for: "fixture-folder"), oldToken)
        XCTAssertEqual(fixture.bookmarks.refreshed, ["fixture-folder"])
        XCTAssertEqual(controller.lastOutcome, DeletionOutcome(succeededCount: 1, failed: []))
        XCTAssertFalse(FileManager.default.fileExists(atPath: target.path))
        try fixture.assertSentinel(sibling, "selected/keep.txt")
        assertCleanupRequests(fixture)
    }

    @MainActor
    func testWindowCancellationWhileConfigPreflightIsSuspendedPreservesSelection() async throws {
        let fixture = try await CleanupFixture.make()
        let responseGate = HTTPReplyGate()
        addTeardownBlock { @MainActor in responseGate.open(); try await fixture.close() }
        let target = try fixture.sentinel("Project/selected/keep.txt")
        let sibling = try fixture.sentinel("selected/keep.txt")
        grantExactRoot(fixture)
        try await fixture.bootstrap()
        let controller = try await loadedController(fixture)
        fixture.connection.http.enqueue("/rest/system/status", json: #"{"myID":"fixture-local","uptime":123}"#)
        let json = String(decoding: try JSONEncoder().encode(fixture.configuredFolder()), as: UTF8.self)
        fixture.connection.http.enqueue("/rest/config/folders/fixture-folder", json: json, gate: responseGate)
        let deletion = Task { await controller.performDeletion(selected: ["selected"]) }
        await fulfillment(of: [responseGate.entered], timeout: 5)
        controller.cancelPendingWork()
        responseGate.open()
        await deletion.value

        XCTAssertEqual(controller.lastOutcome?.succeededCount, 0)
        XCTAssertEqual(controller.candidates.map(\.id), ["selected"])
        XCTAssertNil(controller.confirmation)
        XCTAssertNotNil(controller.lastError)
        XCTAssertFalse(controller.deleting)
        try fixture.assertSentinel(target, "Project/selected/keep.txt")
        try fixture.assertSentinel(sibling, "selected/keep.txt")
        XCTAssertFalse(fixture.connection.http.requests.contains { $0.httpMethod == "POST" })
        XCTAssertEqual(fixture.scope.stops, fixture.scope.starts)
    }

    @MainActor
    private func assertBookmarkReplacementInvalidatesReview(useAncestor: Bool,
                                                            file: StaticString = #filePath, line: UInt = #line) async throws {
        let fixture = try await CleanupFixture.make()
        addTeardownBlock { @MainActor in try await fixture.close() }
        let target = try fixture.sentinel("Project/selected/keep.txt")
        let sibling = try fixture.sentinel("selected/keep.txt")
        grantExactRoot(fixture)
        try await fixture.bootstrap()
        let controller = try await loadedController(fixture)
        let review = try XCTUnwrap(controller.prepareDeletion(selected: ["selected"]))
        // Another window replaces the shared grant after this sheet was reviewed.
        try fixture.bookmarks.save(useAncestor ? fixture.directory : fixture.root, for: "fixture-folder")
        fixture.gate.open()

        await controller.performDeletion(confirmation: review, selected: ["selected"])

        XCTAssertEqual(controller.lastOutcome?.succeededCount ?? 0, 0, file: file, line: line)
        XCTAssertNil(controller.confirmation, file: file, line: line)
        XCTAssertNotNil(controller.lastError, file: file, line: line)
        XCTAssertFalse(fixture.connection.http.requests.contains { $0.httpMethod == "POST" }, file: file, line: line)
        XCTAssertEqual(fixture.gate.calls, 0, file: file, line: line)
        try fixture.assertSentinel(target, "Project/selected/keep.txt", file: file, line: line)
        try fixture.assertSentinel(sibling, "selected/keep.txt", file: file, line: line)
    }

    @MainActor
    private func loadedController(_ fixture: CleanupFixture) async throws -> StuckDeletesController {
        try fixture.enqueueCandidates(["selected"])
        let controller = try fixture.controller()
        await controller.loadCandidates()
        XCTAssertEqual(controller.candidates.map(\.id), ["selected"])
        return controller
    }

    @MainActor
    private func assertObsoleteDeletionBlocked(_ controller: StuckDeletesController, fixture: CleanupFixture,
                                               file: StaticString = #filePath, line: UInt = #line) async {
        // A defective controller may reach reconciliation. Open the deterministic
        // gate so the RED test finishes even after the forbidden mutation.
        fixture.gate.open()
        await controller.performDeletion(selected: ["selected"])
        XCTAssertEqual(controller.lastOutcome?.succeededCount ?? 0, 0, file: file, line: line)
        XCTAssertTrue(controller.accessBlocked || controller.lastError != nil, "Blocked deletion must explain recovery", file: file, line: line)
        XCTAssertFalse(controller.deleting, file: file, line: line)
        XCTAssertEqual(fixture.gate.calls, 0, file: file, line: line)
        XCTAssertFalse(fixture.connection.http.requests.contains { $0.httpMethod == "POST" }, "Obsolete selection must not rescan", file: file, line: line)
    }

    @MainActor
    private func grantExactRoot(_ fixture: CleanupFixture) {
        // Supply the OS result, not a replacement for the controller's access probe.
        fixture.bookmarks.result = .resolved(fixture.root, isStale: false)
    }

    @MainActor
    private func assertCleanupRequests(_ fixture: CleanupFixture, file: StaticString = #filePath, line: UInt = #line) {
        let all = fixture.connection.http.requests
        let loaded = all.firstIndex { $0.url?.path == "/rest/db/need" } ?? all.endIndex
        let preflight = all.dropFirst(loaded).filter {
            ["/rest/system/status", "/rest/config/folders/fixture-folder"].contains($0.url?.path ?? "")
        }
        XCTAssertEqual(preflight.count, 2, file: file, line: line)
        for request in preflight {
            XCTAssertEqual(request.cachePolicy, .reloadIgnoringLocalCacheData, file: file, line: line)
            XCTAssertEqual(request.value(forHTTPHeaderField: "Cache-Control"), "no-cache", file: file, line: line)
        }
        let requests = fixture.connection.http.requests.filter { ["/rest/db/need", "/rest/db/scan"].contains($0.url?.path ?? "") }
        XCTAssertEqual(requests.map { $0.url!.path }, ["/rest/db/need", "/rest/db/scan", "/rest/db/need"], file: file, line: line)
        for request in requests {
            let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            XCTAssertTrue(query.contains(URLQueryItem(name: "folder", value: "fixture-folder")), file: file, line: line)
            if request.httpMethod == "GET" {
                XCTAssertTrue(query.contains(URLQueryItem(name: "perpage", value: "1000")), file: file, line: line)
            }
        }
    }
}
