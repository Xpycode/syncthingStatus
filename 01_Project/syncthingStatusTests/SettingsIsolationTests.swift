import Foundation
import XCTest

final class SettingsIsolationTests: XCTestCase {
    @MainActor
    func testInitializationPublishesInjectedCredentialAndReadsFakeLogin() async {
        let fixture = await SettingsFixture.make(apiKey: "synthetic-initial-key", launchAtLogin: true)
        XCTAssertFalse(fixture.settings.useAutomaticDiscovery)
        XCTAssertEqual(fixture.settings.baseURLString, "https://syncthing.invalid")
        XCTAssertEqual(fixture.settings.manualAPIKey, "synthetic-initial-key")
        XCTAssertEqual(fixture.credentials.operations.first, .read)
        XCTAssertTrue(fixture.settings.launchAtLogin)
        XCTAssertEqual(fixture.login.readCount, 1)
        XCTAssertEqual(fixture.login.writes, [])
        await fixture.close()
    }

    @MainActor
    func testFlushPersistsLatestValuesAndDeletesEmptyCredential() async {
        let fixture = await SettingsFixture.make()
        fixture.settings.manualAPIKey = "superseded-key"
        fixture.settings.manualAPIKey = "synthetic-replacement-key"
        fixture.settings.refreshInterval = 42
        // Opaque fixture data exercises defaults persistence without creating a real bookmark.
        fixture.settings.configBookmarkData = Data([1, 2, 3])
        fixture.settings.configBookmarkPath = FileManager.default.temporaryDirectory
            .appendingPathComponent(fixture.suiteName).appendingPathComponent("config.xml").path
        await fixture.settings.flushPendingPersistence()
        XCTAssertEqual(fixture.credentials.value, "synthetic-replacement-key")
        XCTAssertFalse(fixture.credentials.operations.contains(.save("superseded-key")))
        XCTAssertEqual(fixture.defaults.double(forKey: "SyncthingSettings.refreshInterval"), 42)
        XCTAssertEqual(fixture.defaults.data(forKey: "SyncthingSettings.configBookmarkData"), Data([1, 2, 3]))
        fixture.settings.manualAPIKey = ""
        fixture.settings.clearConfigBookmark()
        await fixture.settings.flushPendingPersistence()
        XCTAssertNil(fixture.credentials.value)
        XCTAssertEqual(fixture.credentials.operations.last, .delete)
        XCTAssertNil(fixture.defaults.object(forKey: "SyncthingSettings.configBookmarkData"))
        XCTAssertNil(fixture.defaults.object(forKey: "SyncthingSettings.configBookmarkPath"))
        await fixture.close()
    }

    @MainActor
    func testResetUsesInjectedStoresAndLoginToggleUsesFakeSetter() async {
        let fixture = await SettingsFixture.make()
        fixture.settings.launchAtLogin = true
        fixture.settings.launchAtLogin = false
        XCTAssertEqual(fixture.login.writes, [true, false])
        XCTAssertFalse(fixture.login.isEnabled)
        fixture.settings.refreshInterval = 77
        fixture.settings.resetToDefaults()
        await fixture.settings.flushPendingPersistence()
        XCTAssertNil(fixture.credentials.value)
        XCTAssertTrue(fixture.defaults.bool(forKey: "SyncthingSettings.useAutomaticDiscovery"))
        XCTAssertEqual(fixture.defaults.double(forKey: "SyncthingSettings.refreshInterval"), 10)
        XCTAssertEqual(fixture.defaults.string(forKey: "SyncthingSettings.baseURL"), "http://127.0.0.1:8384")
        await fixture.close()
    }

    @MainActor
    func testMigrationReadsDisposableLegacySuiteWithoutMigratingBookmarks() async {
        let oldSuite = "syncthingStatusTests.legacy.\(UUID().uuidString)"
        let oldDefaults = UserDefaults(suiteName: oldSuite)!
        oldDefaults.set(false, forKey: "SyncthingSettings.useAutomaticDiscovery")
        oldDefaults.set("https://legacy.syncthing.invalid", forKey: "SyncthingSettings.baseURL")
        oldDefaults.set(37.0, forKey: "SyncthingSettings.refreshInterval")
        oldDefaults.set(Data([9]), forKey: "SyncthingSettings.configBookmarkData")
        let fixture = await SettingsFixture.make(legacyDefaults: oldDefaults)
        XCTAssertFalse(fixture.settings.useAutomaticDiscovery)
        XCTAssertEqual(fixture.settings.baseURLString, "https://legacy.syncthing.invalid")
        XCTAssertEqual(fixture.settings.refreshInterval, 37)
        XCTAssertNil(fixture.settings.configBookmarkData)
        XCTAssertTrue(fixture.defaults.bool(forKey: "SyncthingSettings.migrationFromOldBundleIDCompleted"))
        XCTAssertEqual(oldDefaults.data(forKey: "SyncthingSettings.configBookmarkData"), Data([9]))
        await fixture.close()
        oldDefaults.removePersistentDomain(forName: oldSuite)
    }

    @MainActor
    func testCompletedMigrationDoesNotOpenLegacySource() async {
        let fixture = await SettingsFixture.make()
        var legacyReadCount = 0
        let reloaded = SyncthingSettings(
            defaults: fixture.defaults,
            credentialStore: fixture.credentials,
            legacyDefaultsProvider: {
                legacyReadCount += 1
                return nil
            },
            readLaunchAtLogin: { fixture.login.read() },
            writeLaunchAtLogin: { fixture.login.write($0) }
        )
        await reloaded.waitUntilCredentialsLoaded()
        XCTAssertEqual(legacyReadCount, 0)
        XCTAssertEqual(reloaded.manualAPIKey, "fixture-api-key")
        await reloaded.flushPendingPersistence()
        await fixture.close()
    }

    @MainActor
    func testCloseDrainsPendingSavesBeforeRemovingOnlyOwnedSuite() async {
        let fixture = await SettingsFixture.make()
        let other = await SettingsFixture.make(apiKey: "other-synthetic-key")
        fixture.settings.manualAPIKey = "pending-at-close"
        fixture.settings.refreshInterval = 91
        await fixture.close()
        XCTAssertEqual(fixture.credentials.value, "pending-at-close")
        XCTAssertTrue(fixture.defaults.persistentDomain(forName: fixture.suiteName)?.isEmpty ?? true)
        await fixture.settings.flushPendingPersistence()
        XCTAssertTrue(fixture.defaults.persistentDomain(forName: fixture.suiteName)?.isEmpty ?? true)
        XCTAssertEqual(other.settings.manualAPIKey, "other-synthetic-key")
        XCTAssertFalse(other.defaults.persistentDomain(forName: other.suiteName)?.isEmpty ?? true)
        await other.close()
    }
}
