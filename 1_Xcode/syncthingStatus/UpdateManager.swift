//
//  UpdateManager.swift
//  syncthingStatus
//
//  Manages app update checking and notifications
//

import Foundation
import Combine

// MARK: - GitHub Release Models

struct GitHubRelease: Codable {
    let tagName: String
    let name: String
    let body: String
    let htmlUrl: String
    let publishedAt: String
    let prerelease: Bool
    let assets: [GitHubAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlUrl = "html_url"
        case publishedAt = "published_at"
        case prerelease
        case assets
    }
}

struct GitHubAsset: Codable {
    let name: String
    let browserDownloadUrl: String
    let size: Int

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadUrl = "browser_download_url"
        case size
    }
}

// MARK: - Update Check Frequency

enum UpdateCheckFrequency: String, CaseIterable, Codable {
    case disabled = "Disabled"
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"

    var interval: TimeInterval? {
        switch self {
        case .disabled:
            return nil
        case .daily:
            return 24 * 60 * 60 // 1 day
        case .weekly:
            return 7 * 24 * 60 * 60 // 7 days
        case .monthly:
            return 30 * 24 * 60 * 60 // 30 days
        }
    }

    var displayName: String {
        return self.rawValue
    }
}

// MARK: - Update Manager

@MainActor
class UpdateManager: ObservableObject {
    // Published state
    @Published var availableVersion: String?
    @Published var isCheckingForUpdates = false
    @Published var lastCheckDate: Date?
    @Published var releaseNotes: String?
    @Published var downloadURL: String?
    @Published var checkError: String?

    // Settings reference
    private let settings: SyncthingSettings

    // Update check timer
    private var updateCheckTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // Constants
    private let githubAPIURL = "https://api.github.com/repos/Xpycode/syncthingStatus/releases/latest"
    private let currentVersion: String

    init(settings: SyncthingSettings) {
        self.settings = settings

        // Get current version from bundle
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            self.currentVersion = version
        } else {
            self.currentVersion = "1.4" // Fallback
        }

        // Subscribe to update frequency changes
        settings.$updateCheckFrequency
            .sink { [weak self] _ in
                self?.schedulePeriodicChecks()
            }
            .store(in: &cancellables)

        // Check on first launch if enabled
        schedulePeriodicChecks()

        // Perform initial check if appropriate
        if settings.updateCheckFrequency != .disabled {
            Task {
                await checkIfNeeded()
            }
        }
    }

    // MARK: - Public Methods

    /// Manually check for updates (always executes regardless of schedule)
    func checkForUpdatesManually() async {
        await checkForUpdates(force: true)
    }

    /// Check for updates only if the scheduled interval has passed
    func checkIfNeeded() async {
        guard settings.updateCheckFrequency != .disabled else { return }

        if let lastCheck = settings.lastUpdateCheckDate,
           let interval = settings.updateCheckFrequency.interval {
            let nextCheckDate = lastCheck.addingTimeInterval(interval)
            if Date() < nextCheckDate {
                // Too soon to check again
                return
            }
        }

        await checkForUpdates(force: false)
    }

    /// Open the release page in the default browser
    func openReleasePage() {
        if let urlString = downloadURL,
           let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }

    /// Dismiss the update notification
    func dismissUpdate() {
        availableVersion = nil
        releaseNotes = nil
        downloadURL = nil
    }

    // MARK: - Private Methods

    private func checkForUpdates(force: Bool) async {
        guard force || settings.updateCheckFrequency != .disabled else { return }

        isCheckingForUpdates = true
        checkError = nil

        defer {
            isCheckingForUpdates = false
        }

        do {
            let release = try await fetchLatestRelease()

            // Update last check date
            settings.lastUpdateCheckDate = Date()
            lastCheckDate = Date()

            // Compare versions
            let latestVersion = normalizeVersion(release.tagName)
            let current = normalizeVersion(currentVersion)

            if isNewerVersion(latest: latestVersion, current: current) {
                // New version available
                availableVersion = latestVersion
                releaseNotes = release.body
                downloadURL = release.htmlUrl

                // Find DMG asset if available
                if let dmgAsset = release.assets.first(where: { $0.name.hasSuffix(".dmg") }) {
                    downloadURL = dmgAsset.browserDownloadUrl
                }
            } else {
                // Already on latest version
                if force {
                    availableVersion = nil
                    releaseNotes = "You're running the latest version (\(currentVersion))"
                }
            }

        } catch {
            checkError = "Failed to check for updates: \(error.localizedDescription)"
            print("Update check error: \(error)")
        }
    }

    private func fetchLatestRelease() async throws -> GitHubRelease {
        guard let url = URL(string: githubAPIURL) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(GitHubRelease.self, from: data)
    }

    private func normalizeVersion(_ version: String) -> String {
        // Remove 'v' prefix if present
        var normalized = version.lowercased().hasPrefix("v")
            ? String(version.dropFirst())
            : version

        // Remove any build metadata (e.g., "1.4.0-beta" -> "1.4.0")
        if let dashIndex = normalized.firstIndex(of: "-") {
            normalized = String(normalized[..<dashIndex])
        }

        return normalized
    }

    private func isNewerVersion(latest: String, current: String) -> Bool {
        let latestComponents = latest.split(separator: ".").compactMap { Int($0) }
        let currentComponents = current.split(separator: ".").compactMap { Int($0) }

        let maxLength = max(latestComponents.count, currentComponents.count)

        for i in 0..<maxLength {
            let latestPart = i < latestComponents.count ? latestComponents[i] : 0
            let currentPart = i < currentComponents.count ? currentComponents[i] : 0

            if latestPart > currentPart {
                return true
            } else if latestPart < currentPart {
                return false
            }
        }

        return false
    }

    private func schedulePeriodicChecks() {
        // Cancel existing timer
        updateCheckTimer?.invalidate()
        updateCheckTimer = nil

        guard let interval = settings.updateCheckFrequency.interval else {
            return
        }

        // Schedule new timer (check every hour, but only proceed if interval has passed)
        updateCheckTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.checkIfNeeded()
            }
        }
    }

    deinit {
        updateCheckTimer?.invalidate()
    }
}
