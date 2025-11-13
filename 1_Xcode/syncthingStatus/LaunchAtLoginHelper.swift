import Foundation
import ServiceManagement

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
                    print("Failed to update Launch at Login status: \(error)")
                }
            }
        }
    }
}