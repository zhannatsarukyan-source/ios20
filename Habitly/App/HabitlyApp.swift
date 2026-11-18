import SwiftUI

@main
struct HabitlyApp: App {
    private let environment = AppEnvironment.shared
    @AppStorage(AppTheme.storageKey) private var theme: AppTheme = .system

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(environment.l10n)
                .environment(environment.auth)
                .environment(environment.habits)
                .environment(environment.stats)
                .preferredColorScheme(theme.colorScheme)
                .tint(Palette.brand)
        }
    }
}
