import Foundation

/// Composition root: wires networking, auth, i18n and feature stores.
@MainActor
final class AppEnvironment {
    let tokens: TokenStore
    let api: APIClient
    let l10n: L10n
    let auth: AuthStore
    let habits: HabitsStore
    let stats: StatsStore

    init(tokens: TokenStore, api: APIClient) {
        self.tokens = tokens
        self.api = api
        self.l10n = L10n(api: api)
        self.auth = AuthStore(api: api, tokens: tokens)
        self.habits = HabitsStore(api: api)
        self.stats = StatsStore(api: api)
    }

    /// The single app-wide instance (created once, on first access, on the main actor).
    static let shared = AppEnvironment.live()

    private static func live() -> AppEnvironment {
        let persistence = KeychainTokenPersistence()
        resetKeychainOnFreshInstall(persistence)
        let tokens = TokenStore(persistence: persistence)
        let api = APIClient(baseURL: AppConfig.apiBaseURL, tokens: tokens)
        return AppEnvironment(tokens: tokens, api: api)
    }

    /// Keychain items survive app deletion — drop stale tokens on the first launch after install.
    private static func resetKeychainOnFreshInstall(_ persistence: some TokenPersistence) {
        let key = "habitly.hasLaunched"
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: key) {
            persistence.clear()
            defaults.set(true, forKey: key)
        }
    }
}
