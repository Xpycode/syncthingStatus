import Foundation
import XCTest

final class NotificationSelectionTests: XCTestCase {
    @MainActor
    func testLegacyMissingOrEmptySelectionMigratesToAll() async {
        for ids in [nil, []] as [[String]?] {
            let fixture = await SettingsFixture.make()
            if let ids { fixture.defaults.set(ids, forKey: "SyncthingSettings.notificationEnabledFolderIDs") }
            let reloaded = SyncthingSettings(defaults: fixture.defaults,
                                             credentialStore: fixture.credentials,
                                             legacyDefaultsProvider: { nil },
                                             readLaunchAtLogin: { false },
                                             writeLaunchAtLogin: { _ in })
            await reloaded.waitUntilCredentialsLoaded()
            XCTAssertEqual(reloaded.folderNotificationSelectionMode, .all)
            XCTAssertTrue(reloaded.folderNotificationsEnabled(for: "new-folder"))
            await reloaded.flushPendingPersistence()
            await fixture.close()
        }
    }

    @MainActor
    func testLegacyNonemptySelectionMigratesToSelectedAndDeduplicatesOnSave() async {
        let fixture = await SettingsFixture.make()
        fixture.defaults.set(["one", "one", "two"], forKey: "SyncthingSettings.notificationEnabledFolderIDs")
        fixture.defaults.removeObject(forKey: "SyncthingSettings.folderNotificationSelectionMode")
        let settings = SyncthingSettings(defaults: fixture.defaults,
                                         credentialStore: fixture.credentials,
                                         legacyDefaultsProvider: { nil },
                                         readLaunchAtLogin: { false },
                                         writeLaunchAtLogin: { _ in })
        await settings.waitUntilCredentialsLoaded()
        XCTAssertEqual(settings.folderNotificationSelectionMode, .selected)
        XCTAssertEqual(settings.notificationEnabledFolderIDs, ["one", "two"])
        XCTAssertFalse(settings.folderNotificationsEnabled(for: "new-folder"))
        await settings.flushPendingPersistence()
        XCTAssertEqual(fixture.defaults.string(forKey: "SyncthingSettings.folderNotificationSelectionMode"), "selected")
        XCTAssertEqual(fixture.defaults.stringArray(forKey: "SyncthingSettings.notificationEnabledFolderIDs"), ["one", "two"])
        await fixture.close()
    }

    @MainActor
    func testAllOneNoneReloadAndReset() async {
        let fixture = await SettingsFixture.make()
        let settings = fixture.settings
        settings.setFolderNotificationEnabled(false, folderID: "two", availableFolderIDs: ["one", "two", "one"])
        XCTAssertEqual(settings.folderNotificationSelectionMode, .selected)
        XCTAssertEqual(settings.notificationEnabledFolderIDs, ["one"])
        settings.setFolderNotificationEnabled(false, folderID: "one", availableFolderIDs: ["one", "two"])
        XCTAssertFalse(settings.folderNotificationsEnabled(for: "one"))
        XCTAssertFalse(settings.folderNotificationsEnabled(for: "two"))
        await settings.flushPendingPersistence()

        let reloaded = SyncthingSettings(defaults: fixture.defaults,
                                         credentialStore: fixture.credentials,
                                         legacyDefaultsProvider: { nil },
                                         readLaunchAtLogin: { false },
                                         writeLaunchAtLogin: { _ in })
        await reloaded.waitUntilCredentialsLoaded()
        XCTAssertEqual(reloaded.folderNotificationSelectionMode, .selected)
        XCTAssertTrue(reloaded.notificationEnabledFolderIDs.isEmpty)
        reloaded.resetToDefaults()
        XCTAssertEqual(reloaded.folderNotificationSelectionMode, .all)
        XCTAssertTrue(reloaded.folderNotificationsEnabled(for: "future"))
        await reloaded.flushPendingPersistence()
        await fixture.close()
    }

    @MainActor
    func testOldBundleNonemptySelectionMigratesToSelected() async {
        let suite = "syncthingStatusTests.notificationLegacy.\(UUID().uuidString)"
        let legacy = UserDefaults(suiteName: suite)!
        legacy.set(false, forKey: "SyncthingSettings.useAutomaticDiscovery")
        legacy.set(["legacy-folder"], forKey: "SyncthingSettings.notificationEnabledFolderIDs")
        let fixture = await SettingsFixture.make(legacyDefaults: legacy)
        XCTAssertEqual(fixture.settings.folderNotificationSelectionMode, .selected)
        XCTAssertEqual(fixture.settings.notificationEnabledFolderIDs, ["legacy-folder"])
        await fixture.close()
        legacy.removePersistentDomain(forName: suite)
    }

    @MainActor
    func testSelectedNoneSuppressesFolderDeliveryButNotGlobalNotice() async throws {
        let fixture = await ClientFixture.make()
        addTeardownBlock { @MainActor in await fixture.close() }
        let folder = SyncthingFolder(id: "fixture-folder", label: "Fixture", path: "/fixture",
                                     devices: [], paused: false)
        let config = String(decoding: try JSONEncoder().encode(SyncthingConfig(devices: [], folders: [folder])), as: UTF8.self)
        fixture.enqueueRefresh(config: config)
        fixture.http.enqueue("/rest/db/status", json: try SyncStatusTests.payload())
        await fixture.client.refresh()
        fixture.settingsFixture.settings.showSyncNotifications = true
        fixture.settingsFixture.settings.folderNotificationSelectionMode = .selected
        fixture.settingsFixture.settings.notificationEnabledFolderIDs = []

        fixture.http.enqueue("/rest/db/status", json: try SyncStatusTests.payload([
            "state": "syncing", "needFiles": 1, "needBytes": 1
        ]))
        await fixture.client.fetchFolderStatus()
        fixture.http.enqueue("/rest/db/status", json: try SyncStatusTests.payload())
        await fixture.client.fetchFolderStatus()
        XCTAssertFalse(fixture.notifications.contains { $0.content.title == "Sync Complete" })

        fixture.client.handleGlobalSyncComplete()
        XCTAssertEqual(fixture.notifications.filter { $0.content.title == "All Synced" }.count, 1)
    }
}
