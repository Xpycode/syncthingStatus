import Foundation

// Exact body of StuckDeletesController.validatePath from Client.swift:2184-2202,
// extracted into a standalone harness to avoid touching application state.
func validatePath(_ name: String, folderRoot: URL) -> URL? {
    guard !name.isEmpty else { return nil }
    guard !name.contains("\0") else { return nil }
    guard !name.hasPrefix("/") else { return nil }

    let components = name.split(separator: "/")
    guard !components.contains(".."), !components.contains(".") else { return nil }

    let candidate = folderRoot.appendingPathComponent(name, isDirectory: true)
    let resolvedTarget = candidate.standardizedFileURL.resolvingSymlinksInPath()
    let resolvedRoot = folderRoot.standardizedFileURL.resolvingSymlinksInPath()

    let targetPath = resolvedTarget.path
    let rootPath = resolvedRoot.path
    let rootPrefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
    guard targetPath.hasPrefix(rootPrefix) else { return nil }

    return candidate
}

let fixture = URL(fileURLWithPath: "/private/tmp/syncthingStatus-review-evidence/fixture", isDirectory: true)
let grantedAncestor = fixture.appendingPathComponent("Sync", isDirectory: true)
let configuredFolder = grantedAncestor.appendingPathComponent("Project", isDirectory: true)
let sibling = grantedAncestor.appendingPathComponent("OtherFolder", isDirectory: true)
let intended = configuredFolder.appendingPathComponent("OtherFolder", isDirectory: true)
let fm = FileManager.default

try? fm.removeItem(at: fixture)
try fm.createDirectory(at: configuredFolder, withIntermediateDirectories: true)
try fm.createDirectory(at: sibling, withIntermediateDirectories: true)
try fm.createDirectory(at: intended, withIntermediateDirectories: true)
try Data("sibling fixture".utf8).write(to: sibling.appendingPathComponent("sentinel.txt"))
try Data("configured fixture".utf8).write(to: intended.appendingPathComponent("sentinel.txt"))

// This is grantAccess's ancestor predicate at Client.swift:1896-1898.
let chosenPath = grantedAncestor.standardizedFileURL.resolvingSymlinksInPath().path
let expectedPath = configuredFolder.standardizedFileURL.resolvingSymlinksInPath().path
let ancestorGrantAccepted = chosenPath == expectedPath || expectedPath.hasPrefix(chosenPath + "/")
guard ancestorGrantAccepted else { fatalError("fixture did not model accepted ancestor grant") }

// probeFolderAccess returns the saved bookmark URL. performDeletion passes it as
// folderRoot to validatePath, so model the value flowing through those methods.
guard let actualTarget = validatePath("OtherFolder", folderRoot: grantedAncestor) else {
    fatalError("validation unexpectedly rejected target")
}
precondition(actualTarget.standardizedFileURL == sibling.standardizedFileURL)
precondition(actualTarget.standardizedFileURL != intended.standardizedFileURL)

// Exact delete primitive used by deleteOne after validation (Client.swift:2155).
try fm.removeItem(at: actualTarget)

let siblingExists = fm.fileExists(atPath: sibling.path)
let intendedExists = fm.fileExists(atPath: intended.path)
print("ancestorGrantAccepted=\(ancestorGrantAccepted)")
print("configuredFolder=\(configuredFolder.path)")
print("computedDeletionTarget=\(actualTarget.path)")
print("intendedDeletionTarget=\(intended.path)")
print("siblingExistsAfterDelete=\(siblingExists)")
print("intendedExistsAfterDelete=\(intendedExists)")
precondition(!siblingExists && intendedExists)
