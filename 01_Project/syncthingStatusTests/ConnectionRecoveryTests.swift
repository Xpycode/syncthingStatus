import Foundation
import UserNotifications
import XCTest

final class ConnectionRecoveryTests: XCTestCase {
    @MainActor
    func testTypedRecoveryDoesNotDependOnLocalizedMessages() {
        XCTAssertEqual(SyncthingClient.recovery(for: SyncthingClientError.configAccessDenied,
                                                automaticDiscovery: true),
                       ConnectionRecovery(kind: .configAccess, action: .selectConfig))
        XCTAssertEqual(SyncthingClient.recovery(for: SyncthingClientError.configMissingKey,
                                                automaticDiscovery: true),
                       ConnectionRecovery(kind: .credentials, action: .selectConfig))
        XCTAssertEqual(SyncthingClient.recovery(for: SyncthingClientError.httpStatus(code: 401, endpoint: "status"),
                                                automaticDiscovery: false),
                       ConnectionRecovery(kind: .credentials, action: .openSettings))
        XCTAssertEqual(SyncthingClient.recovery(for: URLError(.badURL), automaticDiscovery: false),
                       ConnectionRecovery(kind: .url, action: .openSettings))
        XCTAssertEqual(SyncthingClient.recovery(for: URLError(.cannotConnectToHost), automaticDiscovery: false),
                       ConnectionRecovery(kind: .transport, action: .retry))
    }

    @MainActor
    func testInvalidBaseURLPublishesTypedRecoveryAndFullError() async {
        for invalidURL in ["", "relative/path", "ftp://example.invalid"] {
            let settings = await SettingsFixture.make(baseURL: invalidURL)
            let http = HTTPFixture()
            let client = SyncthingClient(settings: settings.settings, session: http.makeSession())
            await client.refresh()
            XCTAssertEqual(client.connectionRecovery, ConnectionRecovery(kind: .url, action: .openSettings))
            XCTAssertEqual(client.lastErrorMessage, "Syncthing base URL is invalid or empty.")
            await settings.close()
            http.assertFinished()
            http.close()
        }
    }

    @MainActor
    func testPermissionPolicyRequestsOnlyForNotDeterminedEligibleEvents() async throws {
        for status in [UNAuthorizationStatus.authorized, .denied, .provisional] {
            var requests = 0
            let coordinator = NotificationAuthorizationCoordinator(
                statusProvider: { status },
                requestAuthorization: { requests += 1; return true }
            )
            try await coordinator.handle(.firstSuccessfulConnection, notificationsEnabled: true)
            try await coordinator.handle(.explicitIntent, notificationsEnabled: true)
            XCTAssertEqual(requests, 0, "status \(status.rawValue)")
        }

        var status = UNAuthorizationStatus.notDetermined
        var requests = 0
        let coordinator = NotificationAuthorizationCoordinator(
            statusProvider: { status },
            requestAuthorization: { requests += 1; status = .authorized; return true }
        )
        try await coordinator.handle(.firstSuccessfulConnection, notificationsEnabled: false)
        XCTAssertEqual(requests, 0)
        try await coordinator.handle(.explicitIntent, notificationsEnabled: true)
        XCTAssertEqual(requests, 1)
        try await coordinator.handle(.explicitIntent, notificationsEnabled: true)
        XCTAssertEqual(requests, 1)
    }

    @MainActor
    func testFirstSuccessfulConnectionRequestsWhenNotificationsEnabled() async throws {
        var requests = 0
        let coordinator = NotificationAuthorizationCoordinator(
            statusProvider: { .notDetermined },
            requestAuthorization: { requests += 1; return true }
        )
        try await coordinator.handle(.firstSuccessfulConnection, notificationsEnabled: true)
        XCTAssertEqual(requests, 1)
    }
}
