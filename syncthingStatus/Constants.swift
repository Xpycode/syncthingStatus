import Foundation

/// Application-wide constants and configuration values
enum AppConstants {
    // MARK: - Network & Performance
    enum Network {
        /// Activity threshold for considering transfer as active (1 KB/s)
        static let activityThresholdBytes: Double = 1024

        /// Request timeout in seconds
        static let requestTimeoutSeconds: TimeInterval = 10

        /// Total resource timeout in seconds
        static let resourceTimeoutSeconds: TimeInterval = 30

        /// Default refresh interval in seconds
        static let defaultRefreshIntervalSeconds: Double = 10.0
    }

    // MARK: - Sync Thresholds
    enum Sync {
        /// Default completion threshold percentage
        static let defaultCompletionThreshold: Double = 95.0

        /// Default remaining bytes threshold (1 MB)
        static let defaultRemainingBytesThreshold: Int64 = 1_048_576

        /// Default stalled sync timeout in minutes
        static let defaultStalledTimeoutMinutes: Double = 5.0
    }

    // MARK: - UI Configuration
    enum UI {
        /// Maximum popover height as percentage of screen
        static let defaultPopoverMaxHeightPercentage: Double = 70.0

        /// Minimum change threshold for view height updates (in points)
        static let viewHeightUpdateThreshold: CGFloat = 5

        /// Maximum events to keep in sync history
        static let maxSyncEvents = 50

        /// Maximum data points for transfer history charts (10 minutes at 10s intervals)
        static let maxTransferDataPoints = 60
    }

    // MARK: - Polling & Retry
    enum Polling {
        /// Initial polling delay for Syncthing availability (milliseconds)
        static let initialPollingDelayMs: UInt64 = 250_000_000

        /// Maximum polling delay (milliseconds)
        static let maxPollingDelayMs: UInt64 = 2_000_000_000

        /// Maximum number of polling attempts
        static let maxPollingAttempts = 10
    }

    // MARK: - Debouncing
    enum Debounce {
        /// Settings save debounce delay in seconds
        static let settingsSaveDelaySeconds: TimeInterval = 0.3

        /// Settings change debounce in milliseconds
        static let settingsChangeDelayMs: Int = 250
    }

    // MARK: - Data Conversion
    enum DataSize {
        /// Bytes per kilobyte
        static let bytesPerKB: Double = 1024

        /// Bytes per megabyte
        static let bytesPerMB: Int64 = 1_048_576

        /// Bytes per gigabyte
        static let bytesPerGB: Int64 = 1_073_741_824
    }
}
