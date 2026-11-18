import Foundation

/// URLProtocol stub driven by an async handler. Register via `URLSession.mocked()`.
final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    typealias Handler = @Sendable (URLRequest) async throws -> (HTTPURLResponse, Data)

    static let registry = HandlerRegistry()

    private var loadingTask: Task<Void, Never>?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let request = self.request
        guard let handler = Self.registry.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        // URLProtocol / URLProtocolClient are not Sendable in the SDK, so `self` must not be captured by the
        // `sending` Task closure. Box exactly what the task needs; URLSession only calls back through `client`.
        let context = UncheckedSendable(value: (protocolInstance: self as URLProtocol, client: client))
        loadingTask = Task {
            let instance = context.value.protocolInstance
            let client = context.value.client
            do {
                let (response, data) = try await handler(request)
                client?.urlProtocol(instance, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(instance, didLoad: data)
                client?.urlProtocolDidFinishLoading(instance)
            } catch {
                client?.urlProtocol(instance, didFailWithError: error)
            }
        }
    }

    override func stopLoading() {
        loadingTask?.cancel()
    }
}

/// Test-only escape hatch for handing non-Sendable Foundation objects to a Task.
struct UncheckedSendable<Value>: @unchecked Sendable {
    let value: Value
}

final class HandlerRegistry: @unchecked Sendable {
    private let lock = NSLock()
    private var current: MockURLProtocol.Handler?

    var handler: MockURLProtocol.Handler? {
        lock.withLock { current }
    }

    func set(_ handler: MockURLProtocol.Handler?) {
        lock.withLock { current = handler }
    }
}

extension URLSession {
    static func mocked() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

enum Stub {
    static func json(_ status: Int, _ body: String, url: URL?, headers: [String: String] = [:]) -> (HTTPURLResponse, Data) {
        var allHeaders = ["Content-Type": "application/json"]
        allHeaders.merge(headers) { _, new in new }
        let response = HTTPURLResponse(
            url: url ?? URL(string: "http://test.local")!,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: allHeaders
        )!
        return (response, Data(body.utf8))
    }

    static func authResponse(access: String, refresh: String) -> String {
        """
        {"accessToken":"\(access)","refreshToken":"\(refresh)","expiresIn":900,
         "user":{"id":"u1","email":"ada@example.com","displayName":"Ada","locale":"en","createdAt":"2026-11-17T08:30:00.000Z"}}
        """
    }

    static func error(code: String, key: String) -> String {
        #"{"error":{"code":"\#(code)","messageKey":"\#(key)","message":"x","requestId":"r"}}"#
    }
}
