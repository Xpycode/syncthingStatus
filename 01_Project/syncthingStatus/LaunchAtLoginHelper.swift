import Foundation
import ServiceManagement
import OSLog

private let launchAtLoginLog = Logger(subsystem: "com.lucesumbrarum.syncthingStatus", category: "LaunchAtLogin")

struct LaunchAtLoginHelper {
    // The app registers itself (single target, no embedded login-item helper),
    // so this must be `mainApp` — `loginItem(identifier:)` requires a helper
    // bundle at Contents/Library/LoginItems and always fails without one.
    static var isEnabled: Bool {
        get {
            SMAppService.mainApp.status == .enabled
        }
        set {
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                launchAtLoginLog.error("Failed to update Launch at Login status: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}