import Foundation
import Observation

@MainActor
@Observable
final class StatsStore {
    private(set) var summary: StatsSummary?
    private(set) var isLoading = false
    private(set) var failed = false

    @ObservationIgnored private let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    func load() async throws {
        isLoading = true
        defer { isLoading = false }
        do {
            summary = try await api.statsSummary()
            failed = false
        } catch {
            failed = summary == nil
            throw error
        }
    }

    func reset() {
        summary = nil
        failed = false
    }
}
