import Foundation
import Observation

@MainActor
@Observable
final class AuthStore {
    enum Phase: Equatable {
        case checking
        case signedOut
        case signedIn
    }

    private(set) var phase: Phase = .checking
    private(set) var user: User?

    @ObservationIgnored private let api: APIClient
    @ObservationIgnored private let tokens: TokenStore
    @ObservationIgnored private var handlerInstalled = false

    init(api: APIClient, tokens: TokenStore) {
        self.api = api
        self.tokens = tokens
    }

    /// Restores the session from the Keychain. Offline-friendly: a stored session is trusted
    /// until the backend says otherwise (refresh failure → `handleSessionExpired`).
    /// Idempotent and cancellation-safe: may be called again (e.g. the `.task` restarts) and never leaves
    /// `phase == .checking` behind — any early exit falls back to `.signedOut`.
    func start() async {
        if !handlerInstalled {
            await api.setSessionExpiredHandler { [weak self] in
                await self?.handleSessionExpired()
            }
            handlerInstalled = true
        }
        guard phase == .checking else { return }
        defer {
            if phase == .checking { phase = .signedOut }
        }
        let hasSession = await tokens.hasSession
        guard !Task.isCancelled else { return }
        phase = hasSession ? .signedIn : .signedOut
        if hasSession {
            await reloadUser()
        }
    }

    func reloadUser() async {
        do {
            user = try await api.me()
        } catch {
            // Session expiry is handled by the API client callback; network errors keep cached state.
        }
    }

    func login(email: String, password: String) async throws {
        let response = try await api.login(LoginInput(email: email, password: password))
        try await establish(response)
    }

    func register(email: String, password: String, displayName: String, locale: String) async throws {
        let response = try await api.register(
            RegisterInput(email: email, password: password, displayName: displayName, locale: locale)
        )
        try await establish(response)
    }

    func updateProfile(displayName: String? = nil, locale: String? = nil) async throws {
        user = try await api.updateMe(UpdateMeInput(displayName: displayName, locale: locale))
    }

    func logout() async {
        let refreshToken = await tokens.refreshToken
        await tokens.clear()
        user = nil
        phase = .signedOut
        if let refreshToken {
            try? await api.logout(refreshToken: refreshToken)
        }
    }

    func handleSessionExpired() {
        guard phase != .signedOut else { return }
        user = nil
        phase = .signedOut
    }

    private func establish(_ response: AuthResponse) async throws {
        guard let refreshToken = response.refreshToken else { throw APIError.invalidResponse }
        await tokens.update(AuthTokens(accessToken: response.accessToken, refreshToken: refreshToken))
        user = response.user
        phase = .signedIn
    }
}
