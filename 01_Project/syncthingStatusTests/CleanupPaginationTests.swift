import Foundation
import XCTest

final class CleanupPaginationTests: XCTestCase {
    private func payload(page: Int = 1, perpage: Int = 1000,
                         progress: [[String: Any]] = [], queued: [[String: Any]] = [],
                         rest: [[String: Any]] = []) throws -> String {
        String(decoding: try JSONSerialization.data(withJSONObject: [
            "page": page, "perpage": perpage, "progress": progress, "queued": queued, "rest": rest
        ]), as: UTF8.self)
    }

    private func item(_ name: String, deleted: Bool = true,
                      type: String = "FILE_INFO_TYPE_DIRECTORY", size: Int64 = 0) -> [String: Any] {
        ["name": name, "deleted": deleted, "type": type, "size": size]
    }

    @MainActor
    private func fixtureAndController() async throws -> (CleanupFixture, StuckDeletesController) {
        let fixture = try await CleanupFixture.make()
        try await fixture.bootstrap()
        return (fixture, try fixture.controller())
    }

    @MainActor
    func testZeroAndMixedBucketsPublishTerminalGeneration() async throws {
        let (fixture, controller) = try await fixtureAndController()
        addTeardownBlock { @MainActor in try await fixture.close() }
        fixture.connection.http.enqueue("/rest/db/need", json: try payload(
            progress: [item("a")], queued: [item("file", type: "FILE_INFO_TYPE_FILE")], rest: [item("b")]))
        await controller.loadCandidates()
        XCTAssertEqual(controller.candidates.map(\.name), ["a", "b"])
        XCTAssertTrue(controller.candidatesActionable)
    }

    @MainActor
    func testOneThousandAndOneItemsRequireSecondPageAndDeduplicateIdenticalEntry() async throws {
        let (fixture, controller) = try await fixtureAndController()
        addTeardownBlock { @MainActor in try await fixture.close() }
        let first = (0..<1000).map { item("item-\($0)") }
        fixture.connection.http.enqueue("/rest/db/need", json: try payload(rest: first))
        fixture.connection.http.enqueue("/rest/db/need", json: try payload(page: 2, rest: [item("item-999"), item("item-1000")]))
        await controller.loadCandidates()
        XCTAssertEqual(controller.candidates.count, 1001)
        XCTAssertTrue(controller.candidatesActionable)
        let pages = fixture.connection.http.requests.filter { $0.url?.path == "/rest/db/need" }
            .compactMap { URLComponents(url: $0.url!, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "page" }?.value }
        XCTAssertEqual(pages, ["1", "2"])
    }

    @MainActor
    func testExactMultipleRequiresEmptyTerminalPage() async throws {
        let (fixture, controller) = try await fixtureAndController()
        addTeardownBlock { @MainActor in try await fixture.close() }
        fixture.connection.http.enqueue("/rest/db/need", json: try payload(rest: (0..<1000).map { item("item-\($0)") }))
        fixture.connection.http.enqueue("/rest/db/need", json: try payload(page: 2))
        await controller.loadCandidates()
        XCTAssertEqual(controller.candidates.count, 1000)
        XCTAssertTrue(controller.candidatesActionable)
    }

    @MainActor
    func testMalformedBucketsAndMetadataFailClosed() async throws {
        for json in [
            #"{"page":1,"perpage":1000,"progress":[],"queued":[]}"#,
            #"{"page":1,"perpage":1000,"progress":{},"queued":[],"rest":[]}"#,
            try payload(page: 2)
        ] {
            let (fixture, controller) = try await fixtureAndController()
            fixture.connection.http.enqueue("/rest/db/need", json: json)
            await controller.loadCandidates()
            XCTAssertFalse(controller.candidatesActionable)
            XCTAssertTrue(controller.candidates.isEmpty)
            XCTAssertNotNil(controller.lastError)
            try await fixture.close()
        }
    }

    @MainActor
    func testConflictingDuplicateFailsClosed() async throws {
        let (fixture, controller) = try await fixtureAndController()
        addTeardownBlock { @MainActor in try await fixture.close() }
        let first = (0..<1000).map { item("item-\($0)") }
        fixture.connection.http.enqueue("/rest/db/need", json: try payload(rest: first))
        fixture.connection.http.enqueue("/rest/db/need", json: try payload(page: 2, rest: [item("item-999", deleted: false)]))
        await controller.loadCandidates()
        XCTAssertFalse(controller.candidatesActionable)
        XCTAssertTrue(controller.candidates.isEmpty)
        XCTAssertTrue(controller.lastError?.contains("conflicting") == true)
    }

    @MainActor
    func testRepeatedFullPageAndPageTwoFailureFailClosed() async throws {
        for secondPage in [
            try payload(page: 2, rest: (0..<1000).map { item("item-\($0)") }),
            "server error"
        ] {
            let (fixture, controller) = try await fixtureAndController()
            fixture.connection.http.enqueue("/rest/db/need", json: try payload(rest: (0..<1000).map { item("item-\($0)") }))
            fixture.connection.http.enqueue("/rest/db/need", json: secondPage,
                                            status: secondPage == "server error" ? 503 : 200)
            await controller.loadCandidates()
            XCTAssertFalse(controller.candidatesActionable)
            XCTAssertTrue(controller.candidates.isEmpty)
            XCTAssertNotNil(controller.lastError)
            try await fixture.close()
        }
    }

    @MainActor
    func testCancellationCannotLeaveOldListActionable() async throws {
        let (fixture, controller) = try await fixtureAndController()
        addTeardownBlock { @MainActor in try await fixture.close() }
        fixture.connection.http.enqueue("/rest/db/need", json: try payload(rest: [item("old")]))
        await controller.loadCandidates()
        XCTAssertTrue(controller.candidatesActionable)

        let gate = HTTPReplyGate()
        fixture.connection.http.enqueue("/rest/db/need", json: try payload(rest: (0..<1000).map { item("new-\($0)") }))
        fixture.connection.http.enqueue("/rest/db/need", json: try payload(page: 2), gate: gate)
        let load = Task { await controller.loadCandidates() }
        await fulfillment(of: [gate.entered], timeout: 2)
        XCTAssertFalse(controller.candidatesActionable)
        XCTAssertTrue(controller.candidates.isEmpty)
        controller.cancelPendingWork()
        gate.open()
        await load.value
        XCTAssertFalse(controller.candidatesActionable)
        XCTAssertTrue(controller.candidates.isEmpty)
    }
}
