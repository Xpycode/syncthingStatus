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

    @MainActor
    func testDeniedPermissionPublishesSettingsRecoveryWithoutRequestingAgain() async throws {
        var requests = 0
        var observed: [UNAuthorizationStatus] = []
        let coordinator = NotificationAuthorizationCoordinator(
            statusProvider: { .denied },
            requestAuthorization: { requests += 1; return true },
            observeStatus: { observed.append($0) }
        )

        await coordinator.refreshStatus()
        try await coordinator.handle(.explicitIntent, notificationsEnabled: true)

        XCTAssertEqual(requests, 0)
        XCTAssertEqual(observed, [.denied, .denied])
    }

    @MainActor
    func testConcurrentEligibleEventsRequestAuthorizationOnlyOnce() async throws {
        var firstStatusContinuation: CheckedContinuation<UNAuthorizationStatus, Never>?
        var statusChecks = 0
        var requests = 0
        let firstStatusCheckStarted = expectation(description: "first status check started")
        let coordinator = NotificationAuthorizationCoordinator(
            statusProvider: {
                statusChecks += 1
                guard statusChecks == 1 else { return .notDetermined }
                firstStatusCheckStarted.fulfill()
                return await withCheckedContinuation { firstStatusContinuation = $0 }
            },
            requestAuthorization: { requests += 1; return true }
        )

        let first = Task {
            try await coordinator.handle(.firstSuccessfulConnection, notificationsEnabled: true)
        }
        let second = Task {
            try await coordinator.handle(.explicitIntent, notificationsEnabled: true)
        }

        await fulfillment(of: [firstStatusCheckStarted], timeout: 1)
        try await second.value
        firstStatusContinuation?.resume(returning: .notDetermined)
        try await first.value

        XCTAssertEqual(requests, 1)
    }

    @MainActor
    func testExplicitIntentIsNotDroppedBehindIneligibleConnectionStatusLookup() async throws {
        var firstStatusContinuation: CheckedContinuation<UNAuthorizationStatus, Never>?
        var statusChecks = 0
        var requests = 0
        let firstStatusCheckStarted = expectation(description: "first status check started")
        let coordinator = NotificationAuthorizationCoordinator(
            statusProvider: {
                statusChecks += 1
                guard statusChecks == 1 else { return .notDetermined }
                firstStatusCheckStarted.fulfill()
                return await withCheckedContinuation { firstStatusContinuation = $0 }
            },
            requestAuthorization: { requests += 1; return true }
        )

        let connection = Task {
            try await coordinator.handle(.firstSuccessfulConnection, notificationsEnabled: false)
        }
        await fulfillment(of: [firstStatusCheckStarted], timeout: 1)
        try await coordinator.handle(.explicitIntent, notificationsEnabled: true)
        firstStatusContinuation?.resume(returning: .notDetermined)
        try await connection.value

        XCTAssertEqual(requests, 1)
    }

    @MainActor
    func testRefreshStatusClearsPreviouslyObservedDenialAfterSettingsGrant() async {
        var status: UNAuthorizationStatus = .denied
        var observed: [UNAuthorizationStatus] = []
        let coordinator = NotificationAuthorizationCoordinator(
            statusProvider: { status },
            requestAuthorization: { true },
            observeStatus: { observed.append($0) }
        )

        await coordinator.refreshStatus()
        status = .authorized
        await coordinator.refreshStatus()

        XCTAssertEqual(observed, [.denied, .authorized])
    }
}
