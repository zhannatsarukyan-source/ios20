import Foundation
import Testing
@testable import Habitly

@Suite("DTO decoding (contract samples)")
struct DTODecodingTests {
    private let decoder = JSONCoding.makeDecoder()

    @Test func decodesAuthResponse() throws {
        let json = """
        {
          "accessToken": "a.b.c",
          "refreshToken": "rt-1",
          "expiresIn": 900,
          "user": {
            "id": "u1", "email": "ada@example.com", "displayName": "Ada",
            "locale": "en", "createdAt": "2026-11-17T08:30:00.000Z"
          }
        }
        """
        let response = try decoder.decode(AuthResponse.self, from: Data(json.utf8))
        #expect(response.accessToken == "a.b.c")
        #expect(response.refreshToken == "rt-1")
        #expect(response.expiresIn == 900)
        #expect(response.user.displayName == "Ada")
    }

    @Test func decodesAuthResponseWithoutRefreshToken() throws {
        let json = """
        {"accessToken":"x","expiresIn":900,"user":{"id":"u1","email":"a@b.co","displayName":"A","locale":"ru","createdAt":"2026-11-17T08:30:00Z"}}
        """
        let response = try decoder.decode(AuthResponse.self, from: Data(json.utf8))
        #expect(response.refreshToken == nil)
        #expect(response.user.locale == "ru")
    }

    @Test func decodesHabitList() throws {
        let json = """
        {"items":[
          {"id":"h1","name":"Run","description":null,"color":"mint","icon":"run","targetPerWeek":3,
           "createdAt":"2026-11-01T10:00:00.000Z","updatedAt":"2026-11-02T10:00:00.123Z",
           "currentStreak":4,"checkedInToday":true,"weekCount":2},
          {"id":"h2","name":"Read","description":"20 pages","color":"ultraviolet","icon":"unknown-icon","targetPerWeek":7,
           "createdAt":"2026-11-01T10:00:00Z","updatedAt":"2026-11-01T10:00:00Z",
           "currentStreak":0,"checkedInToday":false,"weekCount":0}
        ]}
        """
        let response = try decoder.decode(ItemsResponse<HabitWithProgress>.self, from: Data(json.utf8))
        #expect(response.items.count == 2)
        let run = try #require(response.items.first)
        #expect(run.color == .mint)
        #expect(run.icon == .run)
        #expect(run.description == nil)
        #expect(run.currentStreak == 4)
        #expect(run.checkedInToday)
        // Unknown enum values degrade gracefully instead of failing the whole list.
        #expect(response.items[1].color == .coral)
        #expect(response.items[1].icon == .leaf)
    }

    @Test func decodesStatsSummary() throws {
        let json = """
        {"totalHabits":3,"completedToday":1,"bestStreak":9,"weeklyCompletionRate":0.42,
         "last7Days":[{"date":"2026-11-11","completed":1,"total":3},{"date":"2026-11-12","completed":3,"total":3}]}
        """
        let summary = try decoder.decode(StatsSummary.self, from: Data(json.utf8))
        #expect(summary.bestStreak == 9)
        #expect(summary.weeklyCompletionRate == 0.42)
        #expect(summary.last7Days.map(\.id) == ["2026-11-11", "2026-11-12"])
    }

    @Test func decodesErrorEnvelope() throws {
        let json = """
        {"error":{"code":"VALIDATION_ERROR","messageKey":"errors.validation","message":"Invalid",
          "details":[{"field":"name","messageKey":"validation.required","message":"Required"}],"requestId":"req-1"}}
        """
        let envelope = try decoder.decode(ApiErrorEnvelope.self, from: Data(json.utf8))
        #expect(envelope.error.code == "VALIDATION_ERROR")
        #expect(envelope.error.details?.first?.field == "name")
        #expect(envelope.error.requestId == "req-1")
    }

    @Test func decodesLocalesAndBundle() throws {
        let locales = try decoder.decode(LocalesResponse.self, from: Data("""
        {"default":"en","locales":[{"code":"en","name":"English"},{"code":"ru","name":"Русский"}]}
        """.utf8))
        #expect(locales.defaultLocale == "en")
        #expect(locales.locales.map(\.code) == ["en", "ru"])

        let bundle = try decoder.decode(I18nBundle.self, from: Data("""
        {"locale":"ru","version":"abc123","messages":{"nav.habits":"Привычки"}}
        """.utf8))
        #expect(bundle.version == "abc123")
        #expect(bundle.messages["nav.habits"] != nil)
    }

    @Test func encodesPartialUpdateWithoutNulls() throws {
        let data = try JSONCoding.makeEncoder().encode(UpdateHabitInput(name: "Walk"))
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object.keys.sorted() == ["name"])
    }

    @Test func dayKeyRoundTrip() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Moscow"))
        let date = try #require(DayKey.date(from: "2026-03-09", calendar: calendar))
        #expect(DayKey.string(from: date, calendar: calendar) == "2026-03-09")
    }

    @Test func heatmapHasFiveFullWeeksEndingThisWeek() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        calendar.firstWeekday = 2 // Monday
        let today = try #require(DayKey.date(from: "2026-11-18", calendar: calendar)) // Wednesday
        let weeks = HeatmapLayout.weeks(count: 5, endingAt: today, calendar: calendar)
        #expect(weeks.count == 5)
        #expect(weeks.allSatisfy { $0.count == 7 })
        #expect(DayKey.string(from: weeks[4][0], calendar: calendar) == "2026-11-16")
        #expect(DayKey.string(from: weeks[0][0], calendar: calendar) == "2026-10-19")
    }
}
