import Foundation
import ServiceManagement
import OSLog

private let launchAtLoginLog = Logger(subsystem: "com.lucesumbrarum.syncthingStatus", category: "LaunchAtLogin")

struct LaunchAtLoginHelper {
    private static let appIdentifier = "LucesUmbrarum.syncthingStatus"

    static var isEnabled: Bool {
        get {
            if #available(macOS 13.0, *) {
                return SMAppService.loginItem(identifier: appIdentifier).status == .enabled
            } else {
                return false
            }
        }
        set {
            if #available(macOS 13.0, *) {
                do {
                    if newValue {
                        try SMAppService.loginItem(identifier: appIdentifier).register()
                    } else {
                        try SMAppService.loginItem(identifier: appIdentifier).unregister()
                    }
                } catch {
                    launchAtLoginLog.error("Failed to update Launch at Login status: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }
}