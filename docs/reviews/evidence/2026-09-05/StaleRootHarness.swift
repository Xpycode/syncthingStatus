import Foundation

// Exact body of StuckDeletesController.validatePath from Client.swift:2184-2202.
func validatePath(_ name: String, folderRoot: URL) -> URL? {
    guard !name.isEmpty else { return nil }
    guard !name.contains("\0") else { return nil }
    guard !name.hasPrefix("/") else { return nil }
    let components = name.split(separator: "/")
    guard !components.contains(".."), !components.contains(".") else { return nil }
    let candidate = folderRoot.appendingPathComponent(name, isDirectory: true)
    let resolvedTarget = candidate.standardizedFileURL.resolvingSymlinksInPath()
    let resolvedRoot = folderRoot.standardizedFileURL.resolvingSymlinksInPath()
    let rootPrefix = resolvedRoot.path.hasSuffix("/") ? resolvedRoot.path : resolvedRoot.path + "/"
    guard resolvedTarget.path.hasPrefix(rootPrefix) else { return nil }
    return candidate
}

let fixture = URL(fileURLWithPath: "/private/tmp/syncthingStatus-review-evidence/stale-fixture", isDirectory: true)
let oldBookmarkRoot = fixture.appendingPathComponent("OldLocalFolder", isDirectory: true)
let currentConfiguredRoot = fixture.appendingPathComponent("NewLocalFolder", isDirectory: true)
let oldCandidate = oldBookmarkRoot.appendingPathComponent("candidate", isDirectory: true)
let currentCandidate = currentConfiguredRoot.appendingPathComponent("candidate", isDirectory: true)
let fm = FileManager.default

try? fm.removeItem(at: fixture)
try fm.createDirectory(at: oldCandidate, withIntermediateDirectories: true)
try fm.createDirectory(at: currentCandidate, withIntermediateDirectories: true)
try Data("old fixture".utf8).write(to: oldCandidate.appendingPathComponent("sentinel.txt"))
try Data("new fixture".utf8).write(to: currentCandidate.appendingPathComponent("sentinel.txt"))

// Model probeFolderAccess after bookmark resolution: it returns .granted(url)
// without comparing `url` to `folder.realURL` (Client.swift:2000-2011).
guard let actualTarget = validatePath("candidate", folderRoot: oldBookmarkRoot) else {
    fatalError("validation unexpectedly rejected target")
}
precondition(actualTarget.standardizedFileURL == oldCandidate.standardizedFileURL)
precondition(actualTarget.standardizedFileURL != currentCandidate.standardizedFileURL)
try fm.removeItem(at: actualTarget)

let oldExists = fm.fileExists(atPath: oldCandidate.path)
let currentExists = fm.fileExists(atPath: currentCandidate.path)
print("savedBookmarkRoot=\(oldBookmarkRoot.path)")
print("currentConfiguredRoot=\(currentConfiguredRoot.path)")
print("computedDeletionTarget=\(actualTarget.path)")
print("oldCandidateExistsAfterDelete=\(oldExists)")
print("currentCandidateExistsAfterDelete=\(currentExists)")
precondition(!oldExists && currentExists)
