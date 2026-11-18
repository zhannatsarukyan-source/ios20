import Testing
@testable import Habitly

// Test fixtures below are sample catalog data, not app UI strings.
@Suite("L10n catalog: lookup, interpolation, plurals")
struct L10nCatalogTests {
    private let en = L10nCatalog(locale: "en", messages: [
        "dashboard.greeting": "Hello, {name}",
        "dashboard.progress": "{done} of {total} done",
        "habits.streak_one": "{count} day streak",
        "habits.streak_other": "{count} day streak (other)",
    ])

    private let ru = L10nCatalog(locale: "ru", messages: [
        "habits.streak_one": "{count} день",
        "habits.streak_few": "{count} дня",
        "habits.streak_many": "{count} дней",
        "habits.streak_other": "{count} дня (other)",
        "habits.target_per_week_value_other": "{count} раз(а)",
    ])

    @Test func interpolatesNamedPlaceholders() {
        #expect(en.t(.dashboardGreeting, ["name": "Ada"]) == "Hello, Ada")
        #expect(en.t(.dashboardProgress, ["done": "2", "total": "5"]) == "2 of 5 done")
    }

    @Test func leavesUnknownPlaceholdersIntact() {
        #expect(en.t(.dashboardGreeting) == "Hello, {name}")
        #expect(L10nCatalog.interpolate("{a} {b}", ["a": "1"]) == "1 {b}")
    }

    @Test func missingKeyFallsBackToKeyIdentifier() {
        #expect(en.t(.habitsTitle) == L10nKey.habitsTitle.rawValue)
    }

    @Test func englishPlural() {
        #expect(en.plural(.habitsStreak, count: 1) == "1 day streak")
        #expect(en.plural(.habitsStreak, count: 3) == "3 day streak (other)")
    }

    @Test func russianPluralCategories() {
        #expect(ru.plural(.habitsStreak, count: 1) == "1 день")
        #expect(ru.plural(.habitsStreak, count: 3) == "3 дня")
        #expect(ru.plural(.habitsStreak, count: 5) == "5 дней")
        #expect(ru.plural(.habitsStreak, count: 21) == "21 день")
    }

    @Test func pluralFallsBackToOther() {
        // Only `_other` defined → used for every category.
        #expect(ru.plural(.habitsTargetPerWeekValue, count: 1) == "1 раз(а)")
        #expect(ru.plural(.habitsTargetPerWeekValue, count: 5) == "5 раз(а)")
    }

    @Test func pluralWithMissingKeyReturnsBaseKey() {
        #expect(en.plural(.habitsTargetPerWeekValue, count: 2) == L10nPluralKey.habitsTargetPerWeekValue.rawValue)
    }

    @Test func keysAreWellFormedIdentifiers() {
        // Evaluate outside #expect so the macro never has to capture the (non-Sendable) Regex.
        func isWellFormed(_ raw: String) -> Bool {
            raw.wholeMatch(of: /^[a-z0-9_]+(\.[a-z0-9_]+)+$/) != nil
        }
        for key in L10nKey.allCases {
            let ok = isWellFormed(key.rawValue)
            #expect(ok, "Bad key: \(key.rawValue)")
        }
        for key in L10nPluralKey.allCases {
            let ok = isWellFormed(key.rawValue)
            #expect(ok, "Bad plural key: \(key.rawValue)")
        }
        #expect(Set(L10nKey.allCases.map(\.rawValue)).count == L10nKey.allCases.count)
    }
}
