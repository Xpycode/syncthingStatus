import Foundation
import XCTest

final class FolderPauseTests: XCTestCase {
    private static func config(_ states: [(String, Bool)]) -> String {
        let folders = states.map { id, paused in
            #"{"id":"\#(id)","label":"\#(id)","path":"/\#(id)","devices":[],"paused":\#(paused)}"#
        }.joined(separator: ",")
        return "{\"devices\":[],\"folders\":[\(folders)]}"
    }

    @MainActor
    private func configured(_ states: [(String, Bool)]) async -> ClientFixture {
        let fixture = await ClientFixture.make()
        fixture.enqueueRefresh(config: Self.config(states))
        for _ in states { fixture.http.enqueue("/rest/db/status", json: try! SyncStatusTests.payload()) }
        await fixture.client.refresh()
        return fixture
    }

    @MainActor
    func testPatchContainsOnlyPausedAndEncodesFolderID() async throws {
        let fixture = await configured([("folder / one", false)])
        addTeardownBlock { @MainActor in await fixture.close() }
        fixture.http.enqueue("PATCH", "/rest/config/folders/folder / one", json: "{}", status: 200)
        fixture.enqueueRefresh(config: Self.config([("folder / one", true)]))
        fixture.http.enqueue("/rest/db/status", json: try SyncStatusTests.payload())
        await fixture.client.pauseFolder(folderID: "folder / one")

        let request = try XCTUnwrap(fixture.http.requests.first { $0.httpMethod == "PATCH" })
        XCTAssertEqual(request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false)?.percentEncodedPath },
                       "/rest/config/folders/folder%20%2F%20one")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
        XCTAssertEqual(try JSONSerialization.jsonObject(with: try XCTUnwrap(request.httpBody)) as? [String: Bool], ["paused": true])
        XCTAssertFalse(fixture.http.requests.contains { $0.httpMethod == "POST" && $0.url?.path == "/rest/system/config" })
        XCTAssertTrue(fixture.client.folders[0].paused)
    }

    @MainActor
    func testSameFolderOppositeIntentWaitsForAppliedRequestThenReconcilesLatest() async {
        let fixture = await configured([("one", false)])
        addTeardownBlock { @MainActor in await fixture.close() }
        let firstGate = HTTPReplyGate()
        fixture.http.enqueue("PATCH", "/rest/config/folders/one", json: "{}", gate: firstGate)
        fixture.http.enqueue("PATCH", "/rest/config/folders/one", json: "{}")
        fixture.enqueueRefresh(config: Self.config([("one", true)]))
        fixture.http.enqueue("/rest/db/status", json: try! SyncStatusTests.payload())
        fixture.enqueueRefresh(config: Self.config([("one", false)]))
        fixture.http.enqueue("/rest/db/status", json: try! SyncStatusTests.payload())

        let first = Task { await fixture.client.pauseFolder(folderID: "one") }
        await fulfillment(of: [firstGate.entered], timeout: 2)
        let second = Task { await fixture.client.resumeFolder(folderID: "one") }
        await Task.yield()
        XCTAssertEqual(fixture.http.requests.filter { $0.httpMethod == "PATCH" }.count, 1)
        firstGate.open()
        await first.value
        await second.value

        let bodies = fixture.http.requests.filter { $0.httpMethod == "PATCH" }.compactMap(\.httpBody)
        XCTAssertEqual(bodies.count, 2)
        XCTAssertEqual(try? JSONSerialization.jsonObject(with: bodies[0]) as? [String: Bool], ["paused": true])
        XCTAssertEqual(try? JSONSerialization.jsonObject(with: bodies[1]) as? [String: Bool], ["paused": false])
        XCTAssertFalse(fixture.client.folders[0].paused)
    }

    @MainActor
    func testDifferentFoldersPatchIndependentlyAndFailureDoesNotNotifySuccess() async {
        let fixture = await configured([("one", false), ("two", false)])
        addTeardownBlock { @MainActor in await fixture.close() }
        let gate = HTTPReplyGate()
        fixture.http.enqueue("PATCH", "/rest/config/folders/one", json: "{}", gate: gate)
        fixture.http.enqueue("PATCH", "/rest/config/folders/two", json: "{}", status: 403)
        fixture.enqueueRefresh(config: Self.config([("one", true), ("two", false)]))
        for _ in 0..<2 { fixture.http.enqueue("/rest/db/status", json: try! SyncStatusTests.payload()) }

        let one = Task { await fixture.client.pauseFolder(folderID: "one") }
        await fulfillment(of: [gate.entered], timeout: 2)
        await fixture.client.pauseFolder(folderID: "two")
        XCTAssertEqual(fixture.http.requests.filter { $0.httpMethod == "PATCH" }.count, 2)
        XCTAssertTrue(fixture.client.lastErrorMessage?.contains("HTTP 403") == true)
        XCTAssertFalse(fixture.notifications.contains { $0.content.body.contains("two") })
        gate.open()
        await one.value
    }
}
