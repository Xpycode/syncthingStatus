import AppKit
import Foundation

final class FixtureProtocol: URLProtocol {
    static var configuredFolder: SyncthingFolder!
    static var candidates = ["candidate"]
    static var failPreflight = false
    static var unexpected = [String]()
    static var requests = [String]()
    static let lock = NSLock()
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lock.lock()
        let path = request.url?.path ?? "nil"
        Self.requests.append("\(request.httpMethod ?? "GET") \(path)")
        var data: Data
        var status = 200
        switch path {
        case "/rest/system/status": data = Data(#"{"myID":"fixture-device","uptime":123}"#.utf8)
        case "/rest/system/config": data = try! JSONEncoder().encode(SyncthingConfig(devices: [], folders: [Self.configuredFolder]))
        case "/rest/system/version": data = Data(#"{"version":"fixture"}"#.utf8)
        case "/rest/system/connections": data = Data(#"{"connections":{}}"#.utf8)
        case "/rest/db/status": data = Data(#"{"state":"idle","needDeletes":1}"#.utf8)
        case "/rest/config/folders/fixture": data = try! JSONEncoder().encode(Self.configuredFolder)
        case "/rest/db/need": data = try! JSONSerialization.data(withJSONObject: ["progress":[], "queued":[], "rest": Self.candidates.map { ["name":$0, "deleted":true, "type":"FILE_INFO_TYPE_DIRECTORY"] }])
        case "/rest/db/scan": Self.candidates = []; data = Data()
        default: Self.unexpected.append(path); data = Data()
        }
        if path == "/rest/config/folders/fixture", Self.failPreflight { status = 503; Self.failPreflight = false }
        Self.lock.unlock()
        let response = HTTPURLResponse(url: request.url!, statusCode: path == "/rest/db/scan" ? 204 : status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type":"application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@MainActor
func runController(mode: String, root: URL, scope: URL) async {
    if mode == "controller-dialog-many" { FixtureProtocol.candidates = (1...80).map { String(format: "candidate-%03d", $0) } }
    let settings = await SettingsFixture.make(baseURL: "https://cleanup-sandbox.invalid")
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [FixtureProtocol.self]
    configuration.urlCache = nil
    configuration.httpCookieStorage = nil
    configuration.urlCredentialStorage = nil
    let session = URLSession(configuration: configuration)
    let client = SyncthingClient(settings: settings.settings, session: session, deliverNotification: { _, done in done(nil) })
    let folder = SyncthingFolder(id: "fixture", label: "Disposable Fixture", path: root.path, devices: [], paused: false)
    FixtureProtocol.configuredFolder = folder
    await client.refresh()
    if mode.hasPrefix("controller-window") {
        if mode == "controller-window-failure" { FixtureProtocol.failPreflight = true }
        if mode == "controller-window-partial" { FixtureProtocol.candidates = ["candidate", "../unsafe"] }
        let wc = StuckDeletesWindowController(folder: folder, syncthingClient: client)
        let closer = FixtureWindowCloser(controller: wc.stuckController)
        wc.window?.delegate = closer
        wc.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        await withCheckedContinuation { closer.continuation = $0 }
        print("windowClosed=true;deleted=\(wc.stuckController.lastOutcome?.succeededCount ?? 0);failed=\(wc.stuckController.lastOutcome?.failed.count ?? 0);unexpectedHTTP=\(FixtureProtocol.unexpected.count);requests=\(FixtureProtocol.requests)")
        await settings.close()
        session.invalidateAndCancel()
        exit(0)
    }
    let controller = StuckDeletesController(folder: folder, client: client, bookmarks: FolderAccessBookmarks(), securityScope: .live, waitForReconciliation: {})
    await controller.loadCandidates()
    print("controllerCandidates=\(controller.candidates.map(\.name));obsolete=\(controller.obsolete);error=\(controller.lastError ?? "none")")
    if mode == "controller-grant" {
        let panel = NSOpenPanel()
        panel.title = "Disposable cleanup access fixture"
        panel.prompt = "Grant Fixture"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = scope
        NSApp.activate(ignoringOtherApps: true)
        let response = await withCheckedContinuation { continuation in panel.begin { continuation.resume(returning: $0) } }
        guard response == .OK, let url = panel.url, url.standardizedFileURL == scope.standardizedFileURL else { print("picker=unexpectedOrCancelled"); exit(8) }
        controller.grantAccess(url)
        _ = UserDefaults.standard.synchronize()
        await Task.yield()
        while controller.loading { await Task.yield() }
        print("controllerGrant=\(!controller.accessBlocked && controller.lastError == nil);obsolete=\(controller.obsolete);error=\(controller.lastError ?? "none")")
    } else {
        let selected = Set(controller.candidates.map(\.id))
        guard let confirmation = controller.prepareDeletion(selected: selected) else { print("confirmation=missing;obsolete=\(controller.obsolete);error=\(controller.lastError ?? "none")"); exit(9) }
        print("confirmationRootMatches=\(URL(fileURLWithPath: confirmation.rootPath).standardizedFileURL == root.standardizedFileURL);names=\(confirmation.names)")
        if mode == "controller-path-change" {
            let changed = SyncthingFolder(id: "fixture", label: "Disposable Fixture", path: root.deletingLastPathComponent().appendingPathComponent("OtherProject").path, devices: [], paused: false)
            // The open controller remains alive, while authoritative daemon configuration moves.
            FixtureProtocol.configuredFolder = changed
        }
        var accepted = true
        if mode.hasPrefix("controller-dialog-") {
            let window = NSWindow(contentRect: NSRect(x: 400, y: 300, width: 640, height: 400), styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = "Disposable cleanup confirmation fixture"
            window.isReleasedWhenClosed = false
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            accepted = await withCheckedContinuation { continuation in
                CleanupConfirmationDialog.present(confirmation, controller: controller, window: window) { continuation.resume(returning: $0) }
                if mode == "controller-dialog-stale" { client.folders = [SyncthingFolder(id: "fixture", label: "Disposable Fixture", path: root.deletingLastPathComponent().appendingPathComponent("OtherProject").path, devices: [], paused: false)] }
            }
            print("dialogAccepted=\(accepted)")
            window.close()
        }
        if accepted { await controller.performDeletion(confirmation: confirmation, selected: selected) }
        else { controller.invalidateConfirmation() }
        print("deleted=\(controller.lastOutcome?.succeededCount ?? 0);failed=\(controller.lastOutcome?.failed.count ?? 0);blocked=\(controller.accessBlocked);obsolete=\(controller.obsolete)")
    }
    print("unexpectedHTTP=\(FixtureProtocol.unexpected.count);requests=\(FixtureProtocol.requests)")
    controller.close()
    await settings.close()
    session.invalidateAndCancel()
    exit(0)
}

@MainActor
final class FixtureWindowCloser: NSObject, NSWindowDelegate {
    let controller: StuckDeletesController
    var continuation: CheckedContinuation<Void, Never>?
    init(controller: StuckDeletesController) { self.controller = controller }
    func windowWillClose(_ notification: Notification) {
        controller.cancelPendingWork()
        continuation?.resume()
        continuation = nil
    }
}
