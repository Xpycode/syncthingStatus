import AppKit
import Foundation

@main
struct Harness {
    @MainActor static func main() {
        setbuf(stdout, nil)
        let args = CommandLine.arguments
        guard args.count == 4 else { exit(2) }
        let mode = args[1]
        let root = URL(fileURLWithPath: args[2], isDirectory: true)
        let scope = URL(fileURLWithPath: args[3], isDirectory: true)
        guard root.path.hasPrefix("/private/tmp/syncthingStatus-sandbox-probe/fixtures/"), scope.path.hasPrefix("/private/tmp/syncthingStatus-sandbox-probe/fixtures/") else { exit(3) }
        let store = FolderAccessBookmarks()
        func probe(_ label: String) {
            do {
                _ = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
                print("\(label)=readable")
            } catch { print("\(label)=denied;code=\((error as NSError).code)") }
        }
        probe("before")
        var info = stat()
        let statResult = stat(root.path, &info)
        print("statBefore=\(statResult);errno=\(errno)")
        if mode == "clear" {
            store.clear(for: "fixture")
            _ = UserDefaults.standard.synchronize()
            print("bookmark=cleared")
            exit(0)
        }
        if mode == "resolve" {
            switch store.resolve(for: "fixture") {
            case .missing: print("bookmark=missing")
            case .failed(let error): print("bookmark=failed;code=\((error as NSError).code)")
            case .resolved(let url, let stale):
                print("bookmark=resolved;stale=\(stale);scopeMatches=\(url.standardizedFileURL == scope.standardizedFileURL)")
                let started = url.startAccessingSecurityScopedResource()
                print("start=\(started)")
                probe("scoped")
                if started { url.stopAccessingSecurityScopedResource() }
            }
            exit(0)
        }
        if mode.hasPrefix("controller-") {
            let app = NSApplication.shared
            app.setActivationPolicy(.regular)
            Task { await runController(mode: mode, root: root, scope: scope) }
            app.run()
            return
        }
        guard mode == "grant" else { exit(4) }
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let delegate = Delegate(root: root, scope: scope, store: store)
        app.delegate = delegate
        app.run()
        withExtendedLifetime(delegate) {}
    }
}

@MainActor
final class Delegate: NSObject, NSApplicationDelegate {
    let root: URL
    let scope: URL
    let store: FolderAccessBookmarks
    init(root: URL, scope: URL, store: FolderAccessBookmarks) { self.root = root; self.scope = scope; self.store = store }
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.title = "Disposable cleanup access fixture"
        panel.message = "Grant only the displayed disposable fixture directory."
        panel.prompt = "Grant Fixture"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = scope
        panel.begin { [self] result in
            guard result == .OK, let url = panel.url else { print("picker=cancelled"); NSApp.terminate(nil); return }
            guard url.standardizedFileURL == scope.standardizedFileURL else { print("picker=unexpectedScope"); NSApp.terminate(nil); return }
            do {
                try store.save(url, for: "fixture")
                _ = UserDefaults.standard.synchronize()
                let start = url.startAccessingSecurityScopedResource()
                print("picker=granted;start=\(start)")
                _ = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
                print("root=readable")
                if start { url.stopAccessingSecurityScopedResource() }
            } catch { print("picker=error;code=\((error as NSError).code)") }
            NSApp.terminate(nil)
        }
    }
}
