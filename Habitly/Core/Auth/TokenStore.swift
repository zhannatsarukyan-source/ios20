import Foundation

struct AuthTokens: Codable, Sendable, Equatable {
    let accessToken: String
    let refreshToken: String
}

protocol TokenPersistence: Sendable {
    func load() -> AuthTokens?
    func save(_ tokens: AuthTokens)
    func clear()
}

/// Production persistence: JSON-encoded tokens in the Keychain.
struct KeychainTokenPersistence: TokenPersistence {
    private let keychain: KeychainStore
    private let account = "auth.tokens"

    init(keychain: KeychainStore = KeychainStore()) {
        self.keychain = keychain
    }

    func load() -> AuthTokens? {
        guard let data = keychain.data(for: account) else { return nil }
        return try? JSONDecoder().decode(AuthTokens.self, from: data)
    }

    func save(_ tokens: AuthTokens) {
        guard let data = try? JSONEncoder().encode(tokens) else { return }
        keychain.set(data, for: account)
    }

    func clear() {
        keychain.delete(account)
    }
}

/// Tests / previews.
final class InMemoryTokenPersistence: TokenPersistence, @unchecked Sendable {
    private let lock = NSLock()
    private var tokens: AuthTokens?

    init(initial: AuthTokens? = nil) {
        tokens = initial
    }

    func load() -> AuthTokens? { lock.withLock { tokens } }
    func save(_ tokens: AuthTokens) { lock.withLock { self.tokens = tokens } }
    func clear() { lock.withLock { tokens = nil } }
}

/// Owns the current token pair and guarantees a single in-flight refresh.
actor TokenStore {
    private let persistence: any TokenPersistence
    private var tokens: AuthTokens?
    private var refreshTask: Task<AuthTokens, any Error>?

    init(persistence: any TokenPersistence) {
        self.persistence = persistence
        self.tokens = persistence.load()
    }

    var accessToken: String? { tokens?.accessToken }
    var refreshToken: String? { tokens?.refreshToken }
    var hasSession: Bool { tokens != nil }

    func update(_ newTokens: AuthTokens) {
        tokens = newTokens
        persistence.save(newTokens)
    }

    func clear() {
        refreshTask?.cancel()
        refreshTask = nil
        refreshID = nil
        tokens = nil
        persistence.clear()
    }

    /// Identifies the refresh currently stored in `refreshTask` (guards against stale completions).
    private var refreshID: UUID?

    /// Single-flight refresh.
    /// - The token that failed is no longer current (someone refreshed meanwhile) → return the current one.
    /// - A refresh is IN FLIGHT (`refreshTask` is cleared inside the actor the moment it finishes) → join it.
    /// - Otherwise start exactly one refresh; concurrent callers share it. A completed task is never reused,
    ///   so a freshly issued token that gets rejected later triggers a new refresh instead of replaying the old result.
    func refreshAccessToken(
        failedAccessToken: String?,
        using refresher: @escaping @Sendable (String) async throws -> AuthTokens
    ) async throws -> String {
        if let current = tokens?.accessToken, current != failedAccessToken {
            return current
        }
        if let inFlight = refreshTask {
            return try await inFlight.value.accessToken
        }
        guard let refreshToken = tokens?.refreshToken else {
            throw APIError.sessionExpired
        }

        let id = UUID()
        refreshID = id
        let task = Task<AuthTokens, any Error> {
            try await self.runRefresh(id: id, refreshToken: refreshToken, refresher: refresher)
        }
        refreshTask = task
        return try await task.value.accessToken
    }

    /// Actor-isolated body of the refresh task: stores the new pair and clears `refreshTask`
    /// atomically (no suspension between the two), so nobody can join a finished refresh.
    private func runRefresh(
        id: UUID,
        refreshToken: String,
        refresher: @Sendable (String) async throws -> AuthTokens
    ) async throws -> AuthTokens {
        do {
            let fresh = try await refresher(refreshToken)
            // Logged out (clear()) while refreshing → don't resurrect the session.
            try Task.checkCancellation()
            guard refreshID == id else { throw CancellationError() }
            update(fresh)
            refreshTask = nil
            refreshID = nil
            return fresh
        } catch {
            if refreshID == id {
                refreshTask = nil
                refreshID = nil
            }
            throw error
        }
    }
}
