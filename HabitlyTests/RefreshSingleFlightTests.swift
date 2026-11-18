import Foundation
import Testing
@testable import Habitly

private actor Counter {
    private(set) var refreshCalls = 0
    private(set) var habitsCalls = 0
    private(set) var expiredCalls = 0
    private(set) var headers: [String: String] = [:]

    func refresh() { refreshCalls += 1 }
    func habits() { habitsCalls += 1 }
    func expired() { expiredCalls += 1 }
    func record(_ request: URLRequest) {
        headers = request.allHTTPHeaderFields ?? [:]
    }
}

/// Issues "new1", "new2", … and accepts only the latest non-revoked token.
private actor TokenServer {
    private(set) var refreshCount = 0
    private var accepted: String?

    func issue() -> String {
        refreshCount += 1
        let token = "new\(refreshCount)"
        accepted = token
        return token
    }

    func revokeCurrent() { accepted = nil }

    func accepts(_ authorization: String) -> Bool {
        guard let accepted else { return false }
        return authorization == "Bearer \(accepted)"
    }
}

/// MockURLProtocol uses a global handler → run serially.
@Suite("APIClient token refresh", .serialized)
struct RefreshSingleFlightTests {
    private let baseURL = URL(string: "http://test.local")!

    private func makeClient(tokens: AuthTokens?) -> (APIClient, TokenStore) {
        let store = TokenStore(persistence: InMemoryTokenPersistence(initial: tokens))
        let client = APIClient(baseURL: baseURL, tokens: store, session: .mocked())
        return (client, store)
    }

    @Test func concurrentExpiredRequestsShareOneRefresh() async throws {
        let counter = Counter()
        MockURLProtocol.registry.set { request in
            let path = request.url?.path ?? ""
            if path == "/api/v1/auth/refresh" {
                await counter.refresh()
                try await Task.sleep(for: .milliseconds(150)) // keep the refresh in flight
                return Stub.json(200, Stub.authResponse(access: "new", refresh: "r2"), url: request.url)
            }
            if path == "/api/v1/habits" {
                await counter.habits()
                if request.value(forHTTPHeaderField: "Authorization") == "Bearer new" {
                    return Stub.json(200, #"{"items":[]}"#, url: request.url)
                }
                return Stub.json(401, Stub.error(code: "TOKEN_EXPIRED", key: "errors.token_expired"), url: request.url)
            }
            return Stub.json(404, Stub.error(code: "NOT_FOUND", key: "errors.not_found"), url: request.url)
        }
        defer { MockURLProtocol.registry.set(nil) }

        let (client, store) = makeClient(tokens: AuthTokens(accessToken: "old", refreshToken: "r1"))

        try await withThrowingTaskGroup(of: Int.self) { group in
            for _ in 0..<5 {
                group.addTask { try await client.habits().count }
            }
            for try await count in group {
                #expect(count == 0)
            }
        }

        #expect(await counter.refreshCalls == 1)
        let habitsCalls = await counter.habitsCalls
        #expect((5...10).contains(habitsCalls)) // ≤ 5 × 401 + 5 retries
        #expect(await store.accessToken == "new")
        #expect(await store.refreshToken == "r2")
    }

    /// After a refresh has COMPLETED, a rejection of the freshly issued token must start a new refresh
    /// (never replay the finished task's result, which would loop into a spurious logout).
    @Test func rejectedFreshTokenTriggersNewRefresh() async throws {
        let server = TokenServer()
        MockURLProtocol.registry.set { request in
            let path = request.url?.path ?? ""
            if path == "/api/v1/auth/refresh" {
                let issued = await server.issue()
                return Stub.json(200, Stub.authResponse(access: issued, refresh: "r-\(issued)"), url: request.url)
            }
            let auth = request.value(forHTTPHeaderField: "Authorization") ?? ""
            if await server.accepts(auth) {
                return Stub.json(200, #"{"items":[]}"#, url: request.url)
            }
            return Stub.json(401, Stub.error(code: "TOKEN_EXPIRED", key: "errors.token_expired"), url: request.url)
        }
        defer { MockURLProtocol.registry.set(nil) }

        let (client, store) = makeClient(tokens: AuthTokens(accessToken: "old", refreshToken: "r1"))
        let expired = Counter()
        await client.setSessionExpiredHandler { await expired.expired() }

        _ = try await client.habits()
        #expect(await server.refreshCount == 1)
        #expect(await store.accessToken == "new1")

        // Server now rejects new1 as expired.
        await server.revokeCurrent()
        _ = try await client.habits()

        #expect(await server.refreshCount == 2)
        #expect(await store.accessToken == "new2")
        #expect(await expired.expiredCalls == 0)
    }

    @Test func refreshFailureExpiresSession() async throws {
        let counter = Counter()
        MockURLProtocol.registry.set { request in
            if request.url?.path == "/api/v1/auth/refresh" {
                await counter.refresh()
                return Stub.json(401, Stub.error(code: "UNAUTHORIZED", key: "errors.unauthorized"), url: request.url)
            }
            return Stub.json(401, Stub.error(code: "TOKEN_EXPIRED", key: "errors.token_expired"), url: request.url)
        }
        defer { MockURLProtocol.registry.set(nil) }

        let (client, store) = makeClient(tokens: AuthTokens(accessToken: "old", refreshToken: "revoked"))
        await client.setSessionExpiredHandler { await counter.expired() }

        await #expect(throws: APIError.sessionExpired) {
            _ = try await client.habits()
        }
        #expect(await counter.refreshCalls == 1)
        #expect(await counter.expiredCalls >= 1)
        #expect(await store.accessToken == nil)
    }

    @Test func sendsStandardHeaders() async throws {
        let counter = Counter()
        MockURLProtocol.registry.set { request in
            await counter.record(request)
            return Stub.json(200, #"{"items":[]}"#, url: request.url)
        }
        defer { MockURLProtocol.registry.set(nil) }

        let (client, _) = makeClient(tokens: AuthTokens(accessToken: "tok", refreshToken: "r"))
        await client.setLanguage("ru")
        _ = try await client.habits()

        let headers = await counter.headers
        #expect(headers["Authorization"] == "Bearer tok")
        #expect(headers["Accept-Language"] == "ru")
        #expect(headers["X-Timezone"] == TimeZone.current.identifier)
        #expect(headers["X-Client"] == "ios")
    }

    @Test func serverErrorKeepsLocalizedMessage() async throws {
        MockURLProtocol.registry.set { request in
            Stub.json(404, Stub.error(code: "HABIT_NOT_FOUND", key: "errors.habit_not_found"), url: request.url)
        }
        defer { MockURLProtocol.registry.set(nil) }

        let (client, _) = makeClient(tokens: AuthTokens(accessToken: "tok", refreshToken: "r"))
        do {
            _ = try await client.habit(id: "missing")
            Issue.record("Expected an error")
        } catch let error as APIError {
            #expect(error.code == "HABIT_NOT_FOUND")
        }
    }
}
