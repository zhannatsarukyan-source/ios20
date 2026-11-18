import SwiftUI

enum AppTab: Hashable {
    case dashboard, habits, stats, settings
}

/// Native iOS 26 TabView — the system renders the Liquid Glass tab bar.
struct MainTabView: View {
    @Environment(L10n.self) private var l10n
    @Environment(HabitsStore.self) private var habits
    @Environment(StatsStore.self) private var stats

    @State private var selection: AppTab = .dashboard

    var body: some View {
        TabView(selection: $selection) {
            Tab(value: AppTab.dashboard) {
                DashboardView()
            } label: {
                tabLabel(.navDashboard, symbol: "sun.max.fill")
            }

            Tab(value: AppTab.habits) {
                HabitsListView()
            } label: {
                tabLabel(.navHabits, symbol: "checklist")
            }

            Tab(value: AppTab.stats) {
                StatsView()
            } label: {
                tabLabel(.navStats, symbol: "chart.bar.fill")
            }

            Tab(value: AppTab.settings) {
                SettingsView()
            } label: {
                tabLabel(.navSettings, symbol: "gearshape.fill")
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .sensoryFeedback(.selection, trigger: selection)
        // Two independent `.task`s → both requests run concurrently.
        .task { try? await habits.load() }
        .task { try? await stats.load() }
    }

    private func tabLabel(_ key: L10nKey, symbol: String) -> some View {
        Label {
            Text(verbatim: l10n.t(key))
        } icon: {
            Image(systemName: symbol)
        }
    }
}
