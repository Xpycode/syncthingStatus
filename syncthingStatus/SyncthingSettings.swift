import Foundation
import Security
import Combine

final class SyncthingSettings: ObservableObject {
    @Published var useAutomaticDiscovery: Bool
    @Published var baseURLString: String
    @Published var manualAPIKey: String
    @Published var syncCompletionThreshold: Double
    @Published var syncRemainingBytesThreshold: Int64
    @Published var showSyncNotifications: Bool
    @Published var refreshInterval: Double
    @Published var showDeviceConnectNotifications: Bool
    @Published var showDeviceDisconnectNotifications: Bool
    @Published var showPauseResumeNotifications: Bool
    @Published var showStalledSyncNotifications: Bool
    @Published var stalledSyncTimeoutMinutes: Double
    @Published var notificationEnabledFolderIDs: [String]
    @Published var configBookmarkData: Data?
    @Published var configBookmarkPath: String?
    @Published var launchAtLogin: Bool = LaunchAtLoginHelper.isEnabled {
        didSet {
            LaunchAtLoginHelper.isEnabled = launchAtLogin
        }
    }
    @Published var popoverMaxHeightPercentage: Double

    private let defaults: UserDefaults
    private let keychain: KeychainHelper
    private var isLoading = false
    private var cancellables = Set<AnyCancellable>()
    private var saveWorkItem: DispatchWorkItem?
    private let keychainQueue = DispatchQueue(
        label: "com.syncthingstatus.keychain",
        qos: .userInitiated
    )

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

        // Load all values
        useAutomaticDiscovery = defaults.object(forKey: Keys.useAutomaticDiscovery) as? Bool ?? true
        baseURLString = defaults.string(forKey: Keys.baseURL) ?? "http://127.0.0.1:8384"
        manualAPIKey = ""  // Will be loaded async after init
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

        // Set up debounced auto-save observers
        setupAutoSave()

        // Load API key async after init completes
        loadAPIKeyAsync()
    }

    private func loadAPIKeyAsync() {
        keychainQueue.async { [weak self] in
            guard let self = self else { return }
            let key = self.keychain.read() ?? ""
            DispatchQueue.main.async {
                self.manualAPIKey = key
            }
        }
    }

    private func setupAutoSave() {
        // Observe UserDefaults-backed properties
        Publishers.CombineLatest4(
            $useAutomaticDiscovery,
            $baseURLString,
            $syncCompletionThreshold,
            $syncRemainingBytesThreshold
        )
        .dropFirst()
        .sink { [weak self] _, _, _, _ in
            self?.scheduleSave()
        }
        .store(in: &cancellables)

        Publishers.CombineLatest4(
            $showSyncNotifications,
            $refreshInterval,
            $showDeviceConnectNotifications,
            $showDeviceDisconnectNotifications
        )
        .dropFirst()
        .sink { [weak self] _, _, _, _ in
            self?.scheduleSave()
        }
        .store(in: &cancellables)

        Publishers.CombineLatest4(
            $showPauseResumeNotifications,
            $showStalledSyncNotifications,
            $stalledSyncTimeoutMinutes,
            $popoverMaxHeightPercentage
        )
        .dropFirst()
        .sink { [weak self] _, _, _, _ in
            self?.scheduleSave()
        }
        .store(in: &cancellables)

        $notificationEnabledFolderIDs
            .dropFirst()
            .sink { [weak self] _ in
                self?.scheduleSave()
            }
            .store(in: &cancellables)

        // Observe keychain-backed property
        $manualAPIKey
            .dropFirst()
            .sink { [weak self] _ in
                self?.scheduleKeychainSave()
            }
            .store(in: &cancellables)

        // Observe bookmark properties
        Publishers.CombineLatest(
            $configBookmarkData,
            $configBookmarkPath
        )
        .dropFirst()
        .sink { [weak self] _, _ in
            self?.scheduleBookmarkSave()
        }
        .store(in: &cancellables)
    }

    private func scheduleSave() {
        // Cancel pending save
        saveWorkItem?.cancel()

        // Schedule new save after delay
        let workItem = DispatchWorkItem { [weak self] in
            self?.persistAllDefaults()
        }
        saveWorkItem = workItem

        // Debounce: wait 300ms after last change
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
    }

    private func scheduleKeychainSave() {
        // Cancel pending save
        saveWorkItem?.cancel()

        // Schedule new save after delay
        let workItem = DispatchWorkItem { [weak self] in
            self?.persistKeychainIfNeeded()
        }
        saveWorkItem = workItem

        // Debounce: wait 300ms after last change
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
    }

    private func scheduleBookmarkSave() {
        // Cancel pending save
        saveWorkItem?.cancel()

        // Schedule new save after delay
        let workItem = DispatchWorkItem { [weak self] in
            self?.persistBookmarkIfNeeded()
        }
        saveWorkItem = workItem

        // Debounce: wait 300ms after last change
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
    }

    private func persistAllDefaults() {
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

    private func persistKeychainIfNeeded() {
        let key = manualAPIKey  // Capture value on main thread

        // Perform keychain operations on background queue
        keychainQueue.async { [weak self] in
            guard let self = self else { return }
            if key.isEmpty {
                self.keychain.delete()
            } else {
                self.keychain.save(key)
            }
        }
    }

    private func persistBookmarkIfNeeded() {
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
