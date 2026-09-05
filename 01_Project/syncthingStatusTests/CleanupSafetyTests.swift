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
        guard case .missing = store.resolve(for: "fixture-folder") else {
            return XCTFail("Fresh fixture should have no bookmark")
        }
        fixture.defaults.set(Data([1]), forKey: "FolderAccessBookmark.fixture-folder")
        fixture.defaults.set(Data([2]), forKey: "FolderAccessBookmark.other-folder")
        store.clear(for: "fixture-folder")
        guard case .missing = store.resolve(for: "fixture-folder") else {
            return XCTFail("Cleared fixture bookmark should be missing")
        }
        XCTAssertEqual(fixture.defaults.data(forKey: "FolderAccessBookmark.other-folder"), Data([2]))
    }

    @MainActor
    private func grantExactRoot(_ fixture: CleanupFixture) {
        // Supply the OS result, not a replacement for the controller's access probe.
        fixture.bookmarks.result = .resolved(fixture.root, isStale: false)
    }

    @MainActor
    private func assertCleanupRequests(_ fixture: CleanupFixture, file: StaticString = #filePath, line: UInt = #line) {
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
