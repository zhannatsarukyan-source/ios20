import Testing
@testable import Habitly

@Suite("CLDR plural rules")
struct PluralRulesTests {
    // Explicitly typed argument tables (no heterogeneous-literal inference inside the @Test macro).
    static let englishCases: [(Int, PluralCategory)] = [
        (0, .other), (1, .one), (2, .other), (5, .other), (11, .other), (21, .other), (101, .other),
    ]

    static let russianCases: [(Int, PluralCategory)] = [
        (0, .many), (1, .one), (2, .few), (3, .few), (4, .few), (5, .many),
        (11, .many), (12, .many), (14, .many), (21, .one), (22, .few), (25, .many),
        (101, .one), (111, .many), (112, .many), (122, .few),
    ]

    @Test("English: one/other", arguments: PluralRulesTests.englishCases)
    func english(count: Int, expected: PluralCategory) {
        #expect(PluralRules.category(for: count, locale: "en") == expected)
        #expect(PluralRules.category(for: count, locale: "en-US") == expected)
    }

    @Test("Russian: one/few/many", arguments: PluralRulesTests.russianCases)
    func russian(count: Int, expected: PluralCategory) {
        #expect(PluralRules.category(for: count, locale: "ru") == expected)
        #expect(PluralRules.category(for: count, locale: "ru_RU") == expected)
    }

    @Test func languagesWithoutPluralsUseOther() {
        #expect(PluralRules.category(for: 1, locale: "ja") == .other)
    }

    @Test func languageCodeNormalization() {
        #expect(PluralRules.languageCode("pt-BR") == "pt")
        #expect(PluralRules.languageCode("ru_RU") == "ru")
        #expect(PluralRules.languageCode("EN") == "en")
    }
}
