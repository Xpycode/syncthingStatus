import Foundation
import XCTest

final class ClientIsolationTests: XCTestCase {
    @MainActor
    func testRefreshUsesOnlyScriptedSessionAndSyntheticCredentials() async {
        let fixture = await ClientFixture.make()
        addTeardownBlock { @MainActor in await fixture.close() }
        fixture.enqueueRefresh()

        await fixture.client.refresh()

        XCTAssertTrue(fixture.client.isConnected)
        XCTAssertEqual(fixture.client.systemStatus?.myID, "fixture-local")
        XCTAssertEqual(fixture.client.syncthingVersion, "fixture-version")
        XCTAssertEqual(fixture.http.requests.count, 4)
        for request in fixture.http.requests {
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.url?.host, fixture.http.host)
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-API-Key"), "fixture-api-key")
        }
        XCTAssertTrue(fixture.notifications.isEmpty)
    }

    @MainActor
    func testPauseActionCapturesNotificationWithoutSystemCenter() async {
        let fixture = await ClientFixture.make()
        addTeardownBlock { @MainActor in await fixture.close() }
        fixture.enqueueRefresh()
        await fixture.client.refresh()
        fixture.http.enqueue("POST", "/rest/system/pause", json: "", status: 204)
        fixture.enqueueRefresh()

        await fixture.client.pauseDevice(deviceID: "fixture-peer")

        XCTAssertEqual(fixture.notifications.count, 1)
        let notification = fixture.notifications.first
        XCTAssertEqual(notification?.content.title, "Device Paused")
        XCTAssertEqual(notification?.content.userInfo["id"] as? String, "fixture-peer")
        XCTAssertEqual(notification?.content.categoryIdentifier, NotificationCategory.devicePaused.rawValue)
        let pause = fixture.http.requests.filter { $0.httpMethod == "POST" }
        XCTAssertEqual(pause.count, 1)
        let query = pause.first?.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false)?.queryItems }
        XCTAssertEqual(query, [URLQueryItem(name: "device", value: "fixture-peer")])
    }

    @MainActor
    func testUnscriptedRequestFailsLocallyAndIsRecorded() async {
        let fixture = await ClientFixture.make()
        addTeardownBlock { @MainActor in
            await fixture.close(expectedUnexpected: ["GET /rest/system/status"])
        }

        // Intentionally omit the response. Ordinary fixtures fail teardown if any
        // request is unexpected; this test proves that the transport fails closed.
        await fixture.client.refresh()

        XCTAssertFalse(fixture.client.isConnected)
        XCTAssertNotNil(fixture.client.lastErrorMessage)
        XCTAssertEqual(fixture.http.requests.count, 1)
        XCTAssertEqual(fixture.http.unexpectedRequests, ["GET /rest/system/status"])
    }
}
