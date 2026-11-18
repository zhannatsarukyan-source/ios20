import SwiftUI

/// Routes between bootstrap (i18n), auth and the main tabs.
struct RootView: View {
    private enum Screen: Equatable {
        case bootstrap
        case auth
        case main
    }

    @Environment(L10n.self) private var l10n
    @Environment(AuthStore.self) private var auth
    @Environment(HabitsStore.self) private var habits
    @Environment(StatsStore.self) private var stats

    var body: some View {
        ZStack {
            switch screen {
            case .bootstrap:
                BootstrapView()
                    .transition(.opacity)
            case .auth:
                AuthView()
                    .transition(.blurReplace)
            case .main:
                MainTabView()
                    .transition(.blurReplace)
            }
        }
        .animation(.smooth(duration: 0.45), value: screen)
        // Platform formatters (dates, numbers, Charts axes) follow the selected backend locale.
        .environment(\.locale, l10n.swiftLocale)
        .task { await l10n.bootstrap() }
        .task { await auth.start() }
        .onChange(of: auth.phase) { _, phase in
            if phase == .signedOut {
                habits.reset()
                stats.reset()
            }
        }
    }

    private var screen: Screen {
        guard l10n.phase == .ready else { return .bootstrap }
        switch auth.phase {
        case .checking: return .bootstrap
        case .signedOut: return .auth
        case .signedIn: return .main
        }
    }
}
