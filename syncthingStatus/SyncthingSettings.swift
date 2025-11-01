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
    }

    private func persistDefaultsIfNeeded() {
        guard !isLoading else { return }
        defaults.set(useAutomaticDiscovery, forKey: Keys.useAutomaticDiscovery)
        defaults.set(baseURLString, forKey: Keys.baseURL)
        defaults.set(syncCompletionThreshold, forKey: Keys.syncCompletionThreshold)
        defaults.set(syncRemainingBytesThreshold, forKey: Keys.syncRemainingBytesThreshold)
        defaults.set(showSyncNotifications, forKey: Keys.showSyncNotifications)
        defaults.set(refreshInterval, forKey: Keys.refreshInterval)
    }

    private func persistKeychainIfNeeded() {
        guard !isLoading else { return }
        if manualAPIKey.isEmpty {
            keychain.delete()
        } else {
            keychain.save(manualAPIKey)
        }
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
