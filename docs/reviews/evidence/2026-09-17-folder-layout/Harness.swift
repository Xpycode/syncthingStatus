import AppKit
import SwiftUI
final class SyncthingClient {
    func resumeFolder(folderID: String) async {}
    func pauseFolder(folderID: String) async {}
    func rescanFolder(folderID: String) async {}
}
final class SyncthingSettings {
    var syncCompletionThreshold: Double = 100
    var syncRemainingBytesThreshold: Int64 = 0
}
@main struct LayoutCheck {
    @MainActor static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let label = CommandLine.arguments[1]
        for width in [356.0, 400.0] {
            for state in ["idle", "scanning", "syncing", "sync-preparing", "missing"] {
                for long in [false, true] {
                    let name = long ? String(repeating: "syncthingStatus-LongFolderNameDeformsTheDropdown", count: 4) : "SYNCsim"
                    let folder = SyncthingFolder(id: "fixture", label: name, path: "/Users/fixture/Desktop/"+name, devices: [], paused: false)
                    let pending = state == "syncing" || state == "sync-preparing"
                    let status: SyncthingFolderStatus? = state == "missing" ? nil : .init(globalFiles: 220619, globalBytes: 40030000000, localFiles: 220619, localBytes: 40030000000, needFiles: pending ? 3 : 0, needBytes: pending ? 16000 : 0, needDeletes: pending ? 13590 : 0, needTotalItems: pending ? 13593 : 0, state: state, lastScan: nil)
                    let view = FixtureRow(folder: folder, status: status).padding(6).frame(width: width).background(Color(nsColor: .windowBackgroundColor))
                    let host = NSHostingView(rootView: view)
                    let size = host.fittingSize
                    host.frame = NSRect(origin: .zero, size: size)
                    let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
                    window.contentView = host
                    window.orderFront(nil)
                    host.layoutSubtreeIfNeeded()
                    RunLoop.current.run(until: Date().addingTimeInterval(0.05))
                    print("\(label) width=\(width) state=\(state) long=\(long) height=\(size.height)")
                    if width == 356 && long {
                        if let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
                            host.cacheDisplay(in: host.bounds, to: rep)
                            try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "/private/tmp/syncthing-layout-check/\(label)-\(state).png"))
                        }
                    }
                    window.orderOut(nil)
                }
            }
        }
    }
}
