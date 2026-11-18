import Foundation

enum PluralCategory: String, Sendable, CaseIterable {
    case zero, one, two, few, many, other
}

/// Small CLDR cardinal-plural helper for integer counts.
/// Exact rules for `en`, `hy` (Armenian: one for i = 0,1) and East-Slavic (`ru`, `uk`, `be`);
/// languages without plural forms → `other`;
/// everything else falls back to the English one/other rule. Lookup always falls back to `_other`.
enum PluralRules {
    static func category(for count: Int, locale: String) -> PluralCategory {
        let language = languageCode(locale)
        let n = abs(count)
        switch language {
        case "ru", "uk", "be":
            let mod10 = n % 10
            let mod100 = n % 100
            if mod10 == 1 && mod100 != 11 { return .one }
            if (2...4).contains(mod10) && !(12...14).contains(mod100) { return .few }
            return .many
        case "hy":
            // CLDR: one → i = 0,1 (integer counts only here); everything else → other.
            return n <= 1 ? .one : .other
        case "ja", "zh", "ko", "vi", "th", "id", "ms":
            return .other
        default:
            return n == 1 ? .one : .other
        }
    }

    static func languageCode(_ locale: String) -> String {
        let normalized = locale.replacingOccurrences(of: "_", with: "-").lowercased()
        return normalized.split(separator: "-").first.map(String.init) ?? normalized
    }
}
