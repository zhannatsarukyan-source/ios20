import Foundation
import Observation

/// Shared habits state for Dashboard + Habits tabs.
@MainActor
@Observable
final class HabitsStore {
    private(set) var habits: [HabitWithProgress] = []
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    private(set) var pendingCheckIns: Set<String> = []
    /// Increments when a habit is created — screens show `habits.created_toast`.
    private(set) var createdRevision = 0

    @ObservationIgnored private let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    var doneToday: Int { habits.filter(\.checkedInToday).count }
    var progressToday: Double { habits.isEmpty ? 0 : Double(doneToday) / Double(habits.count) }

    func habit(id: String) -> HabitWithProgress? {
        habits.first { $0.id == id }
    }

    func load() async throws {
        isLoading = true
        defer { isLoading = false }
        habits = try await api.habits()
        hasLoaded = true
    }

    func create(_ input: CreateHabitInput) async throws -> HabitWithProgress {
        let created = try await api.createHabit(input)
        habits.append(created)
        createdRevision += 1
        return created
    }

    func update(id: String, _ input: UpdateHabitInput) async throws {
        let updated = try await api.updateHabit(id: id, input)
        replace(updated)
    }

    func delete(id: String) async throws {
        try await api.deleteHabit(id: id)
        habits.removeAll { $0.id == id }
    }

    /// Optimistic toggle of today's check-in; reconciles with the server copy afterwards.
    func toggleCheckIn(id: String) async throws {
        guard let original = habit(id: id), !pendingCheckIns.contains(id) else { return }
        pendingCheckIns.insert(id)
        defer { pendingCheckIns.remove(id) }

        let wasChecked = original.checkedInToday
        var optimistic = original
        optimistic.checkedInToday = !wasChecked
        optimistic.weekCount = max(0, original.weekCount + (wasChecked ? -1 : 1))
        optimistic.currentStreak = max(0, original.currentStreak + (wasChecked ? -1 : 1))
        replace(optimistic)

        let today = DayKey.today
        do {
            if wasChecked {
                try await api.undoCheckIn(habitId: id, date: today)
            } else {
                _ = try await api.checkIn(habitId: id, date: today)
            }
        } catch {
            replace(original)
            throw error
        }
        // Server is the source of truth for streak/weekCount.
        if let fresh = try? await api.habit(id: id) {
            replace(fresh)
        }
    }

    func checkIns(habitId: String, from: String, to: String) async throws -> [CheckIn] {
        try await api.checkIns(habitId: habitId, from: from, to: to)
    }

    func reset() {
        habits = []
        hasLoaded = false
        pendingCheckIns = []
    }

    private func replace(_ habit: HabitWithProgress) {
        if let index = habits.firstIndex(where: { $0.id == habit.id }) {
            habits[index] = habit
        }
    }
}
