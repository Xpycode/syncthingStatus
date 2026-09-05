import Foundation

/// Every settings effect uses fixture-owned storage. The real asynchronous load and
/// debounced persistence paths still run, and close drains them before deleting the suite.
@MainActor
final class SettingsFixture {
    let suiteName: String
    let defaults: UserDefaults
    let credentials: MemoryCredentialStore
    let login: FakeLoginState
    let settings: SyncthingSettings

    private init(apiKey: String?, baseURL: String, launchAtLogin: Bool, legacyDefaults: UserDefaults?) {
        suiteName = "syncthingStatusTests.settings.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.set(false, forKey: "SyncthingSettings.useAutomaticDiscovery")
        defaults.set(baseURL, forKey: "SyncthingSettings.baseURL")
        credentials = MemoryCredentialStore(value: apiKey)
        login = FakeLoginState(isEnabled: launchAtLogin)
        let login = login
        settings = SyncthingSettings(
            defaults: defaults,
            credentialStore: credentials,
            legacyDefaultsProvider: { legacyDefaults },
            readLaunchAtLogin: { login.read() },
            writeLaunchAtLogin: { login.write($0) }
        )
    }

    static func make(
        apiKey: String? = "fixture-api-key",
        baseURL: String = "https://syncthing.invalid",
        launchAtLogin: Bool = false,
        legacyDefaults: UserDefaults? = nil
    ) async -> SettingsFixture {
        let fixture = SettingsFixture(apiKey: apiKey, baseURL: baseURL, launchAtLogin: launchAtLogin, legacyDefaults: legacyDefaults)
        await fixture.settings.waitUntilCredentialsLoaded()
        return fixture
    }

    func close() async {
        await settings.flushPendingPersistence()
        defaults.removePersistentDomain(forName: suiteName)
    }
}

final class MemoryCredentialStore: SettingsCredentialStore, @unchecked Sendable {
    enum Operation: Equatable {
        case read
        case save(String)
        case delete
    }

    private let lock = NSLock()
    private var storedValue: String?
    private var recordedOperations: [Operation] = []

    init(value: String?) { storedValue = value }

    var value: String? { lock.withLock { storedValue } }
    var operations: [Operation] { lock.withLock { recordedOperations } }

    func read() -> String? {
        lock.withLock {
            recordedOperations.append(.read)
            return storedValue
        }
    }

    func save(_ value: String) -> Bool {
        lock.withLock {
            recordedOperations.append(.save(value))
            storedValue = value
            return true
        }
    }

    func delete() -> Bool {
        lock.withLock {
            recordedOperations.append(.delete)
            storedValue = nil
            return true
        }
    }
}

@MainActor
final class FakeLoginState {
    private(set) var isEnabled: Bool
    private(set) var readCount = 0
    private(set) var writes: [Bool] = []

    init(isEnabled: Bool) { self.isEnabled = isEnabled }

    func read() -> Bool {
        readCount += 1
        return isEnabled
    }

    func write(_ enabled: Bool) {
        writes.append(enabled)
        isEnabled = enabled
    }
}
