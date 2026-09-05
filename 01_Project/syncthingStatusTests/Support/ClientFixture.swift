import Foundation
import UserNotifications
import XCTest

@MainActor
final class ClientFixture {
    let settingsFixture: SettingsFixture
    let http: HTTPFixture
    let session: URLSession
    private(set) var notifications: [UNNotificationRequest] = []
    private(set) var client: SyncthingClient!

    private init(settingsFixture: SettingsFixture, http: HTTPFixture) {
        self.settingsFixture = settingsFixture
        self.http = http
        session = http.makeSession()
        client = SyncthingClient(settings: settingsFixture.settings, session: session,
                                deliverNotification: { [weak self] request, completion in
            self?.notifications.append(request)
            completion(nil)
        })
    }

    static func make() async -> ClientFixture {
        let http = HTTPFixture()
        let settings = await SettingsFixture.make(baseURL: http.baseURL.absoluteString)
        return ClientFixture(settingsFixture: settings, http: http)
    }

    func enqueueRefresh(config: String = #"{"devices":[],"folders":[]}"#) {
        http.enqueue("/rest/system/status", json: #"{"myID":"fixture-local","uptime":123}"#)
        http.enqueue("/rest/system/config", json: config)
        http.enqueue("/rest/system/version", json: #"{"version":"fixture-version"}"#)
        http.enqueue("/rest/system/connections", json: #"{"connections":{}}"#)
    }

    func close(expectedUnexpected: [String] = [], file: StaticString = #filePath, line: UInt = #line) async {
        // Callers await every client/controller operation before teardown. Release
        // subscriptions before draining settings so no refresh can outlive the fixture.
        client = nil
        await settingsFixture.close()
        session.invalidateAndCancel()
        http.assertFinished(expectedUnexpected: expectedUnexpected, file: file, line: line)
        http.close()
    }
}
