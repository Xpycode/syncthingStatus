import Foundation
import XCTest

/// One script per session host. Every HTTP(S) request is intercepted, including
/// unexpected URLs; this protocol never opens a connection or forwards a request.
final class StubURLProtocol: URLProtocol {
    private let deliveryLock = NSLock()
    private var stopped = false
    private static let registryLock = NSLock()
    private static var scripts: [String: HTTPFixture] = [:]

    static func register(_ script: HTTPFixture) {
        registryLock.lock()
        defer { registryLock.unlock() }
        scripts[script.host] = script
    }

    static func unregister(_ script: HTTPFixture) {
        registryLock.lock()
        defer { registryLock.unlock() }
        scripts.removeValue(forKey: script.host)
    }

    override class func canInit(with request: URLRequest) -> Bool {
        ["http", "https"].contains(request.url?.scheme?.lowercased() ?? "")
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.registryLock.lock()
        let script = Self.scripts[request.url?.host ?? ""]
        Self.registryLock.unlock()
        guard let script else {
            XCTFail("HTTP request escaped its fixture host: \(request.url?.absoluteString ?? "nil")")
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        guard let reply = script.consume(request) else {
            client?.urlProtocol(self, didFailWithError: URLError(.resourceUnavailable))
            return
        }
        let deliver = { [weak self] in
            guard let self else { return }
            self.deliveryLock.lock()
            let shouldDeliver = !self.stopped
            self.deliveryLock.unlock()
            guard shouldDeliver else { return }
            let response = HTTPURLResponse(url: self.request.url!, statusCode: reply.status,
                                           httpVersion: "HTTP/1.1",
                                           headerFields: ["Content-Type": "application/json"])!
            self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            self.client?.urlProtocol(self, didLoad: reply.body)
            self.client?.urlProtocolDidFinishLoading(self)
        }
        if let gate = reply.gate { gate.submit(deliver) } else { deliver() }
    }

    override func stopLoading() {
        deliveryLock.lock()
        stopped = true
        deliveryLock.unlock()
    }
}

/// Suspends a scripted HTTP response at an observable boundary. Tests release
/// every gate explicitly; cancellation never creates a fallback network path.
final class HTTPReplyGate {
    let entered = XCTestExpectation(description: "HTTP response reached controlled gate")
    private let lock = NSLock()
    private var delivery: (() -> Void)?
    private var isOpen = false

    func submit(_ action: @escaping () -> Void) {
        lock.lock()
        let deliverNow = isOpen
        if !deliverNow { delivery = action }
        lock.unlock()
        entered.fulfill()
        if deliverNow { action() }
    }

    func open() {
        lock.lock()
        isOpen = true
        let action = delivery
        delivery = nil
        lock.unlock()
        action?()
    }
}

final class HTTPFixture {
    struct Reply {
        let status: Int
        let body: Data
        let gate: HTTPReplyGate?
    }

    let host = UUID().uuidString.lowercased() + ".invalid"
    var baseURL: URL { URL(string: "https://\(host)")! }
    private let lock = NSLock()
    private var replies: [String: [Reply]] = [:]
    private var recorded: [URLRequest] = []
    private var unhandled: [String] = []

    init() { StubURLProtocol.register(self) }

    func enqueue(_ path: String, json: String, status: Int = 200, gate: HTTPReplyGate? = nil) {
        enqueue("GET", path, json: json, status: status, gate: gate)
    }

    func enqueue(_ method: String, _ path: String, json: String, status: Int = 200, gate: HTTPReplyGate? = nil) {
        lock.lock()
        defer { lock.unlock() }
        replies["\(method) \(path)", default: []].append(Reply(status: status, body: Data(json.utf8), gate: gate))
    }

    fileprivate func consume(_ request: URLRequest) -> Reply? {
        lock.lock()
        defer { lock.unlock() }
        recorded.append(request)
        let key = "\(request.httpMethod ?? "GET") \(request.url?.path ?? "")"
        guard var queue = replies[key], !queue.isEmpty else {
            unhandled.append(key)
            return nil
        }
        let reply = queue.removeFirst()
        replies[key] = queue
        return reply
    }

    var requests: [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }

    var unexpectedRequests: [String] {
        lock.lock()
        defer { lock.unlock() }
        return unhandled
    }

    func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        config.urlCache = nil
        config.httpCookieStorage = nil
        config.urlCredentialStorage = nil
        return URLSession(configuration: config)
    }

    func assertFinished(expectedUnexpected: [String] = [], file: StaticString = #filePath, line: UInt = #line) {
        lock.lock()
        let remaining = replies.filter { !$0.value.isEmpty }.mapValues(\.count)
        let unexpected = unhandled
        lock.unlock()
        XCTAssertEqual(unexpected, expectedUnexpected, file: file, line: line)
        XCTAssertTrue(remaining.isEmpty, "Unconsumed HTTP responses: \(remaining)", file: file, line: line)
    }

    func close() { StubURLProtocol.unregister(self) }
}
