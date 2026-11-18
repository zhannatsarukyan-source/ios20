---
name: add-swiftui-screen
description: Add a new SwiftUI screen/feature to the Habitly iOS app (folder layout, @Observable store, L10n-only text, Liquid Glass styling, mesh background, error banner, pull-to-refresh, tests). Use when asked to create a new view, tab, sheet or feature in ios/.
---

# Add a SwiftUI screen (Habitly iOS)

1. **Location** — `Habitly/Features/<Feature>/<Feature>View.swift` (+ `<Feature>Store.swift` if it owns state).
   New files are picked up automatically by XcodeGen: run `xcodegen generate` (never edit the .xcodeproj).
2. **State** — `@MainActor @Observable final class <Feature>Store` holding `private(set)` UI state and an
   `@ObservationIgnored private let api: APIClient`. Mutations are `async throws`; views catch errors.
   Register it in `App/AppEnvironment.swift` and inject with `.environment(store)` in `HabitlyApp`.
3. **Networking** — add the endpoint to the `extension APIClient` block in `Core/Networking/APIClient.swift`
   and DTOs (`Codable, Sendable`, camelCase as in the contract) to `Core/Networking/DTOs.swift`.
4. **Text** — NO literals. Every visible/accessibility string:
   `Text(verbatim: l10n.t(.someKey))`, `Label { Text(verbatim: …) } icon: { Image(systemName: …) }`,
   `.navigationTitle(Text(verbatim: …))`, `.accessibilityLabel(Text(verbatim: …))`.
   Need a new key? Follow the `i18n-keys` skill first.
5. **Layout skeleton**
   ```swift
   struct FooView: View {
       @Environment(L10n.self) private var l10n
       @Environment(FooStore.self) private var store
       @State private var errorMessage: String?

       var body: some View {
           NavigationStack {
               ScrollView {
                   VStack(spacing: Metrics.spacing) { /* .glassCard() sections */ }
                       .padding(.horizontal, Metrics.padding)
               }
               .background { HabitlyBackground() }
               .refreshable { await reload() }
               .navigationTitle(Text(verbatim: l10n.t(.fooTitle)))
               .errorBanner($errorMessage)
           }
       }

       private func reload() async {
           do { try await store.load() } catch { errorMessage = l10n.message(for: error) }
       }
   }
   ```
6. **Glass** — follow the `liquid-glass-patterns` skill (cards via `.glassCard()`, controls via
   `.buttonStyle(.glass/.glassProminent)` or `.glassEffect(.regular.interactive(), in: …)`).
7. **Formatting** — dates/numbers with `.formatted(… .locale(l10n.swiftLocale))`, `l10n.number(_:)`, `l10n.percent(_:)`.
8. **Tests** — put pure logic in a testable type (see `HeatmapLayout`, `L10nCatalog`) and cover it with Swift Testing in `HabitlyTests/`.
9. **Verify** — `swiftlint lint` (NO-LITERALS custom rules) → `xcodegen generate` → build + test (commands in CLAUDE.md).
   On a Mac with the XcodeBuildMCP server you can also build/run in the simulator and take screenshots.
