import Foundation
import XCTest

/// Only bookmarks, OS scope and HTTP are substituted. Folder configuration and
/// candidates decode through the real client; controller probes and removal use
/// the real filesystem, confined to this fixture's unique temporary directory.
@MainActor
final class CleanupFixture {
    let directory: URL
    let root: URL
    let connection: ClientFixture
    let bookmarks = MemoryFolderBookmarks()
    let scope = ScopeRecorder()
    let gate = ReconciliationGate()

    private init(directory: URL, connection: ClientFixture) {
        self.directory = directory
        root = directory.appendingPathComponent("Project", isDirectory: true)
        self.connection = connection
    }

    static func make() async throws -> CleanupFixture {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("syncthingStatusTests-\(UUID().uuidString)", isDirectory: true)
            .standardizedFileURL.resolvingSymlinksInPath()
        try FileManager.default.createDirectory(at: directory.appendingPathComponent("Project"),
                                                withIntermediateDirectories: true)
        return await CleanupFixture(directory: directory, connection: ClientFixture.make())
    }

    func bootstrap() async throws {
        let config = SyncthingConfig(devices: [], folders: [
            SyncthingFolder(id: "fixture-folder", label: "Fixture", path: root.path, devices: [], paused: false)
        ])
        let json = String(decoding: try JSONEncoder().encode(config), as: UTF8.self)
        connection.enqueueRefresh(config: json)
        connection.http.enqueue("/rest/db/status", json: #"{"state":"idle","needDeletes":1}"#)
        await connection.client.refresh()
        XCTAssertEqual(connection.client.folders.first?.path, root.path)
    }

    func controller() throws -> StuckDeletesController {
        let folder = try XCTUnwrap(connection.client.folders.first)
        return StuckDeletesController(folder: folder, client: connection.client,
                                      bookmarks: bookmarks, securityScope: scope.operations,
                                      waitForReconciliation: { [gate] in await gate.wait() })
    }

    func enqueueCandidates(_ names: [String]) throws {
        let items: [[String: Any]] = names.map { ["name": $0, "deleted": true, "type": "FILE_INFO_TYPE_DIRECTORY"] }
        // Include non-candidates to verify production filtering remains in the path.
        let payload: [String: Any] = [
            "progress": [], "queued": [],
            "rest": items + [["name": "ordinary-file", "deleted": true, "type": "FILE_INFO_TYPE_FILE"],
                             ["name": "live-directory", "deleted": false, "type": "FILE_INFO_TYPE_DIRECTORY"]]
        ]
        let json = String(decoding: try JSONSerialization.data(withJSONObject: payload), as: UTF8.self)
        connection.http.enqueue("/rest/db/need", json: json)
    }

    @discardableResult
    func sentinel(_ relativePath: String) throws -> URL {
        let url = directory.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("sentinel:\(relativePath)".utf8).write(to: url)
        return url
    }

    func assertSentinel(_ url: URL, _ relativePath: String, file: StaticString = #filePath, line: UInt = #line) throws {
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "sentinel:\(relativePath)", file: file, line: line)
    }

    func close() async throws {
        gate.open()
        await connection.close()
        try FileManager.default.removeItem(at: directory)
    }
}

final class MemoryFolderBookmarks: FolderBookmarkStore {
    var result: FolderAccessBookmarks.ResolutionResult = .missing
    private(set) var refreshed: [String] = []

    func resolve(for folderID: String) -> FolderAccessBookmarks.ResolutionResult { result }
    func save(_ url: URL, for folderID: String) throws { result = .resolved(url, isStale: false) }
    func refresh(_ url: URL, for folderID: String) { refreshed.append(folderID) }
    func clear(for folderID: String) { result = .missing }
}

final class ScopeRecorder {
    var startSucceeds = true
    private(set) var starts: [URL] = []
    private(set) var stops: [URL] = []
    var operations: FolderSecurityScope {
        FolderSecurityScope(start: { [self] url in
            starts.append(url)
            return startSucceeds
        }, stop: { [self] url in stops.append(url) })
    }
}

@MainActor
final class ReconciliationGate {
    let entered = XCTestExpectation(description: "Deletion reached reconciliation wait")
    private var continuation: CheckedContinuation<Void, Never>?
    private var isOpen = false
    private(set) var calls = 0

    func wait() async {
        calls += 1
        entered.fulfill()
        guard !isOpen else { return }
        await withCheckedContinuation { continuation = $0 }
    }

    func open() {
        isOpen = true
        continuation?.resume()
        continuation = nil
    }
}
