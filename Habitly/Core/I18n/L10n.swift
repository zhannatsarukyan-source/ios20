import Foundation
import Observation

/// Runtime localization service. All UI text comes from backend bundles:
///   `GET /api/v1/i18n/locales`, `GET /api/v1/i18n/{locale}` (ETag / If-None-Match),
/// cached on disk so subsequent launches render instantly (and offline).
///
/// Usage in views: `Text(verbatim: l10n.t(.habitsTitle))` — always `verbatim:` so SwiftUI
/// never treats our strings as localization keys.
@MainActor
@Observable
final class L10n {
    enum Phase: Equatable {
        case loading
        case ready
        case failed
    }

    private(set) var phase: Phase = .loading
    private(set) var catalog: L10nCatalog = .empty
    private(set) var locales: [LocaleInfo] = []
    private(set) var defaultLocale = "en"
    private(set) var isSwitching = false

    @ObservationIgnored private let api: APIClient
    @ObservationIgnored private let cache: I18nCache
    @ObservationIgnored private let defaults: UserDefaults
    private static let preferenceKey = "habitly.locale"

    init(api: APIClient, cache: I18nCache = I18nCache(), defaults: UserDefaults = .standard) {
        self.api = api
        self.cache = cache
        self.defaults = defaults
    }

    // MARK: - Lookup

    var locale: String { catalog.locale }
    var swiftLocale: Locale { Locale(identifier: catalog.locale) }
    var hasBundle: Bool { !catalog.isEmpty }

    func t(_ key: L10nKey, _ params: [String: String] = [:]) -> String {
        catalog.t(key, params)
    }

    func plural(_ key: L10nPluralKey, count: Int, _ params: [String: String] = [:]) -> String {
        catalog.plural(key, count: count, params)
    }

    /// Locale-aware number formatting for interpolation params.
    func number(_ value: Int) -> String {
        value.formatted(.number.locale(swiftLocale))
    }

    func percent(_ fraction: Double) -> String {
        fraction.formatted(.percent.precision(.fractionLength(0)).locale(swiftLocale))
    }

    /// User-facing message for any error: backend-localized `error.message` first, then its key,
    /// network failures → `errors.network`, everything else → `common.error_generic`.
    func message(for error: any Error) -> String {
        switch error {
        case let apiError as APIError:
            switch apiError {
            case .server(_, let body):
                if let message = body?.message, !message.isEmpty { return message }
                if let key = body?.messageKey, let text = catalog.string(forRawKey: key) { return text }
                return t(.commonErrorGeneric)
            case .network:
                return t(.errorsNetwork)
            case .sessionExpired:
                return t(.errorsTokenExpired)
            case .decoding, .invalidResponse:
                return t(.commonErrorGeneric)
            }
        case is URLError:
            return t(.errorsNetwork)
        default:
            return t(.commonErrorGeneric)
        }
    }

    // MARK: - Loading

    func bootstrap() async {
        if !hasBundle { phase = .loading }

        // 1. Instant start from cache.
        if let cachedLocales = await cache.loadLocales() {
            apply(locales: cachedLocales)
        }
        let initial = resolveLocale(available: locales.map(\.code))
        if !hasBundle, let cached = await cache.loadBundle(requestedLocale: initial) {
            await apply(bundle: cached.bundle)
            phase = .ready
        }

        // 2. Revalidate against the backend.
        do {
            let response = try await api.locales()
            apply(locales: response)
            await cache.saveLocales(response)
            try await loadBundle(resolveLocale(available: response.locales.map(\.code)))
            phase = .ready
        } catch {
            phase = hasBundle ? .ready : .failed
        }
    }

    /// Switches language live (re-renders every view reading `l10n`).
    func switchLocale(_ code: String) async throws {
        guard code != locale else { return }
        isSwitching = true
        defer { isSwitching = false }
        try await loadBundle(code)
        defaults.set(code, forKey: Self.preferenceKey)
    }

    private func loadBundle(_ code: String) async throws {
        let cached = await cache.loadBundle(requestedLocale: code)
        let result = try await api.fetchBundle(locale: code, etag: cached?.etag)
        switch result {
        case .notModified:
            if let cached {
                await apply(bundle: cached.bundle)
            } else if case .updated(let bundle, let etag) = try await api.fetchBundle(locale: code, etag: nil) {
                await cache.saveBundle(CachedBundle(etag: etag, bundle: bundle), requestedLocale: code)
                await apply(bundle: bundle)
            }
        case .updated(let bundle, let etag):
            await cache.saveBundle(CachedBundle(etag: etag, bundle: bundle), requestedLocale: code)
            await apply(bundle: bundle)
        }
    }

    private func apply(bundle: I18nBundle) async {
        catalog = L10nCatalog(locale: bundle.locale, messages: bundle.messages)
        await api.setLanguage(bundle.locale)
    }

    private func apply(locales response: LocalesResponse) {
        locales = response.locales
        defaultLocale = response.defaultLocale
    }

    /// Saved preference → first matching device language → backend default.
    /// Matching is by language code against whatever `/i18n/locales` returns (en, ru, hy, …), so a device
    /// language like `hy-AM` or `ru_RU` maps to `hy` / `ru` with no hardcoded locale list.
    private func resolveLocale(available: [String]) -> String {
        if let saved = defaults.string(forKey: Self.preferenceKey), available.isEmpty || available.contains(saved) {
            return saved
        }
        for preferred in Locale.preferredLanguages {
            let language = PluralRules.languageCode(preferred)
            if let match = available.first(where: { PluralRules.languageCode($0) == language }) {
                return match
            }
        }
        return available.contains(defaultLocale) || available.isEmpty ? defaultLocale : (available.first ?? defaultLocale)
    }
}
