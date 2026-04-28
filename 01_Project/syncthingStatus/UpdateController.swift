import Foundation
import Sparkle

/// Controller that manages app updates via Sparkle framework.
/// Provides observable properties for SwiftUI integration.
@MainActor
final class UpdateController: ObservableObject {
    private let updaterController: SPUStandardUpdaterController

    /// Whether the updater is currently able to check for updates.
    @Published var canCheckForUpdates = false

    init() {
        // Initialize Sparkle with default configuration
        // startingUpdater: true means it will start checking for updates according to settings
        // updaterDelegate: nil uses default behavior
        // userDriverDelegate: nil uses default UI
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        // Observe when the updater can check for updates
        updaterController.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }

    /// The underlying Sparkle updater for direct property access
    var updater: SPUUpdater {
        updaterController.updater
    }

    /// Triggers a manual check for updates
    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
}
