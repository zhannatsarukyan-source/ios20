import Foundation

// DTOs mirror `packages/contracts` (camelCase JSON). Timestamps are ISO-8601 strings,
// calendar days (`date`) are plain "YYYY-MM-DD" strings — see `DayKey`.

// MARK: - Auth / Me

struct User: Codable, Sendable, Equatable, Identifiable {
    let id: String
    let email: String
    var displayName: String
    var locale: String
    let createdAt: Date
}

struct AuthResponse: Codable, Sendable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int
    let user: User
}

struct RegisterInput: Encodable, Sendable {
    let email: String
    let password: String
    let displayName: String
    let locale: String?
}

struct LoginInput: Encodable, Sendable {
    let email: String
    let password: String
}

struct RefreshInput: Encodable, Sendable {
    let refreshToken: String
}

struct UpdateMeInput: Encodable, Sendable {
    var displayName: String?
    var locale: String?
}

// MARK: - Habits

enum HabitColor: String, Codable, Sendable, CaseIterable, Identifiable, Hashable {
    case coral, amber, mint, sky, violet, rose

    var id: String { rawValue }

    init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = HabitColor(rawValue: raw) ?? .coral
    }
}

enum HabitIcon: String, Codable, Sendable, CaseIterable, Identifiable, Hashable {
    case run, book, water, sleep, meditate, code, heart, leaf

    var id: String { rawValue }

    init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = HabitIcon(rawValue: raw) ?? .leaf
    }
}

/// `HabitWithProgress` from the contract (`Habit` & progress fields).
struct HabitWithProgress: Codable, Sendable, Identifiable, Hashable {
    let id: String
    var name: String
    var description: String?
    var color: HabitColor
    var icon: HabitIcon
    var targetPerWeek: Int
    let createdAt: Date
    var updatedAt: Date
    var currentStreak: Int
    var checkedInToday: Bool
    var weekCount: Int
}

struct CreateHabitInput: Encodable, Sendable {
    let name: String
    let description: String?
    let color: HabitColor
    let icon: HabitIcon
    let targetPerWeek: Int
}

/// Partial update — `nil` fields are omitted from the JSON body.
struct UpdateHabitInput: Encodable, Sendable {
    var name: String?
    var description: String?
    var color: HabitColor?
    var icon: HabitIcon?
    var targetPerWeek: Int?
}

struct CheckIn: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let habitId: String
    let date: String
    let createdAt: Date
}

struct CheckInInput: Encodable, Sendable {
    let date: String
}

struct ItemsResponse<Item: Decodable & Sendable>: Decodable, Sendable {
    let items: [Item]
}

// MARK: - Stats

struct DayStat: Codable, Sendable, Identifiable, Hashable {
    let date: String
    let completed: Int
    let total: Int

    var id: String { date }
}

struct StatsSummary: Codable, Sendable, Equatable {
    let totalHabits: Int
    let completedToday: Int
    let bestStreak: Int
    let weeklyCompletionRate: Double
    let last7Days: [DayStat]
}

// MARK: - i18n

struct LocaleInfo: Codable, Sendable, Identifiable, Hashable {
    let code: String
    let name: String

    var id: String { code }
}

struct LocalesResponse: Codable, Sendable, Equatable {
    let defaultLocale: String
    let locales: [LocaleInfo]

    enum CodingKeys: String, CodingKey {
        case defaultLocale = "default"
        case locales
    }
}

struct I18nBundle: Codable, Sendable, Equatable {
    let locale: String
    let version: String
    let messages: [String: String]
}

// MARK: - Errors

struct ApiErrorDetail: Codable, Sendable, Equatable {
    let field: String?
    let messageKey: String?
    let message: String?
}

struct ApiErrorBody: Codable, Sendable, Equatable {
    let code: String
    let messageKey: String?
    let message: String?
    let details: [ApiErrorDetail]?
    let requestId: String?
}

struct ApiErrorEnvelope: Codable, Sendable, Equatable {
    let error: ApiErrorBody
}

struct EmptyResponse: Decodable, Sendable {}
