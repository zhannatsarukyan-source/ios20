import Foundation

/// Pure, thread-safe message lookup + interpolation (the testable core of `L10n`).
struct L10nCatalog: Sendable, Equatable {
    var locale: String
    var messages: [String: String]

    static let empty = L10nCatalog(locale: "en", messages: [:])

    var isEmpty: Bool { messages.isEmpty }

    /// Missing key → the key identifier itself (visible signal for developers, never hardcoded text).
    func t(_ key: L10nKey, _ params: [String: String] = [:]) -> String {
        Self.interpolate(messages[key.rawValue] ?? key.rawValue, params)
    }

    func plural(_ key: L10nPluralKey, count: Int, _ params: [String: String] = [:]) -> String {
        let category = PluralRules.category(for: count, locale: locale)
        let template = messages["\(key.rawValue)_\(category.rawValue)"]
            ?? messages["\(key.rawValue)_other"]
            ?? key.rawValue
        var all = params
        if all["count"] == nil {
            all["count"] = count.formatted(.number.locale(Locale(identifier: locale)))
        }
        return Self.interpolate(template, all)
    }

    func string(forRawKey key: String) -> String? {
        messages[key]
    }

    /// Replaces `{name}` placeholders. Unknown placeholders are left untouched.
    static func interpolate(_ template: String, _ params: [String: String]) -> String {
        guard !params.isEmpty, template.contains("{") else { return template }
        var result = template
        for (name, value) in params {
            result = result.replacingOccurrences(of: "{\(name)}", with: value)
        }
        return result
    }
}
