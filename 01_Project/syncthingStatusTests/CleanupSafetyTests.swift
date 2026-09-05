import Foundation
import XCTest

final class CleanupSafetyTests: XCTestCase {
    func testValidatePathRejectsTraversalOutsideTemporaryRoot() throws {
        let temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("CleanupSafetyTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryRoot) }

        // Baseline for the existing validator only. Controller selection and deletion
        // are covered after the settings and system-service boundaries are isolated.
        XCTAssertNil(StuckDeletesController.validatePath("../outside", folderRoot: temporaryRoot))
    }
}
