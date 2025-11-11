import Foundation
import Security
import Combine

final class SyncthingSettings: ObservableObject {
    @Published var useAutomaticDiscovery: Bool {
        didSet { persistDefaultsIfNeeded() }
    }

    @Published var baseURLString: String {
        didSet { persistDefaultsIfNeeded() }
    }

    @Published var manualAPIKey: String {
        didSet { persistKeychainIfNeeded() }
    }

    @Published var syncCompletionThreshold: Double {
        didSet { persistDefaultsIfNeeded() }
    }

    @Published var syncRemainingBytesThreshold: Int64 {
        didSet { persistDefaultsIfNeeded() }
    }

    @Published var showSyncNotifications: Bool {
        didSet { persistDefaultsIfNeeded() }
    }

    @Published var refreshInterval: Double {
        didSet { persistDefaultsIfNeeded() }
    }

    @Published var showDeviceConnectNotifications: Bool {
        didSet { persistDefaultsIfNeeded() }
    }
    
    @Published var showDeviceDisconnectNotifications: Bool {
        didSet { persistDefaultsIfNeeded() }
    }

    @Published var showPauseResumeNotifications: Bool {
        didSet { persistDefaultsIfNeeded() }
    }

    @Published var showStalledSyncNotifications: Bool {
        didSet { persistDefaultsIfNeeded() }
    }

    @Published var stalledSyncTimeoutMinutes: Double {
        didSet { persistDefaultsIfNeeded() }
    }
    
    @Published var notificationEnabledFolderIDs: [String] {
        didSet { persistDefaultsIfNeeded() }
    }

    @Published var configBookmarkData: Data? {
        didSet { persistBookmarkIfNeeded() }
    }

    @Published var configBookmarkPath: String? {
        didSet { persistBookmarkIfNeeded() }
    }

    @Published var launchAtLogin: Bool = LaunchAtLoginHelper.isEnabled {
        didSet {
            LaunchAtLoginHelper.isEnabled = launchAtLogin
        }
    }

    @Published var popoverMaxHeightPercentage: Double {
        didSet { persistDefaultsIfNeeded() }
    }

    private let defaults: UserDefaults
    private let keychain: KeychainHelper
    private var isLoading = false

    private enum Keys {
        static let useAutomaticDiscovery = "SyncthingSettings.useAutomaticDiscovery"
        static let baseURL = "SyncthingSettings.baseURL"
        static let syncCompletionThreshold = "SyncthingSettings.syncCompletionThreshold"
        static let syncRemainingBytesThreshold = "SyncthingSettings.syncRemainingBytesThreshold"
        static let showSyncNotifications = "SyncthingSettings.showSyncNotifications"
        static let refreshInterval = "SyncthingSettings.refreshInterval"
        static let showDeviceConnectNotifications = "SyncthingSettings.showDeviceConnectNotifications"
        static let showDeviceDisconnectNotifications = "SyncthingSettings.showDeviceDisconnectNotifications"
        static let showPauseResumeNotifications = "SyncthingSettings.showPauseResumeNotifications"
        static let showStalledSyncNotifications = "SyncthingSettings.showStalledSyncNotifications"
        static let stalledSyncTimeoutMinutes = "SyncthingSettings.stalledSyncTimeoutMinutes"
        static let notificationEnabledFolderIDs = "SyncthingSettings.notificationEnabledFolderIDs"
        static let configBookmarkData = "SyncthingSettings.configBookmarkData"
        static let configBookmarkPath = "SyncthingSettings.configBookmarkPath"
        static let popoverMaxHeightPercentage = "SyncthingSettings.popoverMaxHeightPercentage"
    }

    init(defaults: UserDefaults = .standard, keychainService: String = "SyncthingStatusSettings") {
        self.defaults = defaults
        self.keychain = KeychainHelper(service: keychainService, account: "ManualAPIKey")
        isLoading = true
        useAutomaticDiscovery = defaults.object(forKey: Keys.useAutomaticDiscovery) as? Bool ?? true
        baseURLString = defaults.string(forKey: Keys.baseURL) ?? "http://127.0.0.1:8384"
        manualAPIKey = keychain.read() ?? ""
        syncCompletionThreshold = defaults.object(forKey: Keys.syncCompletionThreshold) as? Double ?? 95.0
        syncRemainingBytesThreshold = defaults.object(forKey: Keys.syncRemainingBytesThreshold) as? Int64 ?? 1_048_576 // 1 MB
        showSyncNotifications = defaults.object(forKey: Keys.showSyncNotifications) as? Bool ?? true
        refreshInterval = defaults.object(forKey: Keys.refreshInterval) as? Double ?? 10.0
        showDeviceConnectNotifications = defaults.object(forKey: Keys.showDeviceConnectNotifications) as? Bool ?? false
        showDeviceDisconnectNotifications = defaults.object(forKey: Keys.showDeviceDisconnectNotifications) as? Bool ?? false
        showPauseResumeNotifications = defaults.object(forKey: Keys.showPauseResumeNotifications) as? Bool ?? true
        showStalledSyncNotifications = defaults.object(forKey: Keys.showStalledSyncNotifications) as? Bool ?? false
        stalledSyncTimeoutMinutes = defaults.object(forKey: Keys.stalledSyncTimeoutMinutes) as? Double ?? 5.0
        notificationEnabledFolderIDs = defaults.object(forKey: Keys.notificationEnabledFolderIDs) as? [String] ?? []
        configBookmarkData = defaults.data(forKey: Keys.configBookmarkData)
        configBookmarkPath = defaults.string(forKey: Keys.configBookmarkPath)
        popoverMaxHeightPercentage = defaults.object(forKey: Keys.popoverMaxHeightPercentage) as? Double ?? 70.0
        isLoading = false
    }

    var trimmedBaseURL: String {
        baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var resolvedManualAPIKey: String? {
        let trimmed = manualAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func resetToDefaults() {
        useAutomaticDiscovery = true
        baseURLString = "http://127.0.0.1:8384"
        manualAPIKey = ""
        syncCompletionThreshold = 95.0
        syncRemainingBytesThreshold = 1_048_576 // 1 MB
        showSyncNotifications = true
        refreshInterval = 10.0
        showDeviceConnectNotifications = false
        showDeviceDisconnectNotifications = false
        showPauseResumeNotifications = true
        showStalledSyncNotifications = false
        stalledSyncTimeoutMinutes = 5.0
        notificationEnabledFolderIDs = []
        popoverMaxHeightPercentage = 70.0
        clearConfigBookmark()
    }

    private func persistDefaultsIfNeeded() {
        guard !isLoading else { return }
        defaults.set(useAutomaticDiscovery, forKey: Keys.useAutomaticDiscovery)
        defaults.set(baseURLString, forKey: Keys.baseURL)
        defaults.set(syncCompletionThreshold, forKey: Keys.syncCompletionThreshold)
        defaults.set(syncRemainingBytesThreshold, forKey: Keys.syncRemainingBytesThreshold)
        defaults.set(showSyncNotifications, forKey: Keys.showSyncNotifications)
        defaults.set(refreshInterval, forKey: Keys.refreshInterval)
        defaults.set(showDeviceConnectNotifications, forKey: Keys.showDeviceConnectNotifications)
        defaults.set(showDeviceDisconnectNotifications, forKey: Keys.showDeviceDisconnectNotifications)
        defaults.set(showPauseResumeNotifications, forKey: Keys.showPauseResumeNotifications)
        defaults.set(showStalledSyncNotifications, forKey: Keys.showStalledSyncNotifications)
        defaults.set(stalledSyncTimeoutMinutes, forKey: Keys.stalledSyncTimeoutMinutes)
        defaults.set(notificationEnabledFolderIDs, forKey: Keys.notificationEnabledFolderIDs)
        defaults.set(popoverMaxHeightPercentage, forKey: Keys.popoverMaxHeightPercentage)
    }

    private func persistKeychainIfNeeded() {
        guard !isLoading else { return }
        if manualAPIKey.isEmpty {
            keychain.delete()
        } else {
            keychain.save(manualAPIKey)
        }
    }

    private func persistBookmarkIfNeeded() {
        guard !isLoading else { return }
        if let data = configBookmarkData {
            defaults.set(data, forKey: Keys.configBookmarkData)
        } else {
            defaults.removeObject(forKey: Keys.configBookmarkData)
        }

        if let path = configBookmarkPath {
            defaults.set(path, forKey: Keys.configBookmarkPath)
        } else {
            defaults.removeObject(forKey: Keys.configBookmarkPath)
        }
    }

    func updateConfigBookmark(with url: URL) throws {
        let bookmark = try url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
        configBookmarkData = bookmark
        configBookmarkPath = url.path
    }

    func clearConfigBookmark() {
        configBookmarkData = nil
        configBookmarkPath = nil
    }

    var hasConfigBookmark: Bool {
        configBookmarkData != nil
    }

    var configBookmarkDisplayPath: String? {
        guard let path = configBookmarkPath else { return nil }
        return (path as NSString).abbreviatingWithTildeInPath
    }
}

// MARK: - Keychain Helper
private struct KeychainHelper {
    let service: String
    let account: String

    init(service: String, account: String) {
        self.service = service
        self.account = account
    }

    func save(_ value: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var newQuery = query
            newQuery[kSecValueData as String] = data
            SecItemAdd(newQuery as CFDictionary, nil)
        }
    }

    func read() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
