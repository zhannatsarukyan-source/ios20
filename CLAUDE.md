# Habitly — iOS client

SwiftUI habit tracker for iOS 26 with Liquid Glass. Talks to the Habitly REST API (`/api/v1`, contract in the
backend repo `image/packages/contracts`). **All UI text comes from the backend i18n bundles — never from this repo.**

## Toolchain (exact)
| Item | Version |
|---|---|
| Xcode | **26.x** (26.0 or newer; CI uses latest stable 26.x on `macos-26`) |
| Swift | Swift 6.2 toolchain, **Swift 6 language mode** (`SWIFT_VERSION = 6.0`, `SWIFT_STRICT_CONCURRENCY = complete`) |
| iOS deployment target | **26.0** (iPhone + iPad, portrait on iPhone) |
| XcodeGen | **≥ 2.44** (`brew install xcodegen`) — the `.xcodeproj` is generated and git-ignored |
| SwiftLint | ≥ 0.59 (`brew install swiftlint`) — config `.swiftlint.yml` (includes NO-LITERALS rules) |
| SwiftFormat | ≥ 0.55 (optional, `brew install swiftformat`) — config `.swiftformat` |
| Frameworks | SwiftUI, Observation, Charts, Security (Keychain), Foundation `URLSession`. No third-party packages. |
| Tests | Swift Testing (`import Testing`) in `HabitlyTests` (hosted unit-test bundle) |

## Commands
```bash
brew install xcodegen swiftlint            # once
xcodegen generate                           # after adding/removing files or editing project.yml
open Habitly.xcodeproj                      # optional

# Build (Debug, simulator)
xcodebuild build -project Habitly.xcodeproj -scheme Habitly -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.0' CODE_SIGNING_ALLOWED=NO

# Test
xcodebuild test -project Habitly.xcodeproj -scheme Habitly \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.0' CODE_SIGNING_ALLOWED=NO

# Single test suite (Swift Testing identifiers)
xcodebuild test -project Habitly.xcodeproj -scheme Habitly \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.0' -only-testing:HabitlyTests/RefreshSingleFlightTests

swiftlint lint                               # must be clean of errors (NO-LITERALS rules are errors)
swiftformat .                                # optional formatting
```
List available simulators with `xcrun simctl list devices available`; if `iPhone 17 / OS=26.0` is missing, use `OS=latest` or another iOS 26 device.

**CI equivalent** (`.github/workflows/ios.yml`, runner `macos-26`): setup Xcode latest-stable → `brew install xcodegen swiftlint` →
`swiftlint lint --quiet` → `xcodegen generate` → `xcodebuild build-for-testing` → `xcodebuild test-without-building`
with destination `platform=iOS Simulator,name=iPhone 17,OS=latest`, `CODE_SIGNING_ALLOWED=NO`, result bundle uploaded as artifact.

**Backend for local runs:** start the API on the Mac (`docker run -p 8080:8080 …` or `npm run dev` in `image/`).
Debug builds use `API_BASE_URL = http://localhost:8080` (Config/Debug.xcconfig). For a physical device create the git-ignored
`Config/Local.xcconfig` with `API_BASE_URL = http:/$()/<mac-ip>:8080` (note the `/$()/` trick — `//` starts an xcconfig comment).

On Windows there is no compiler: edit carefully, verify APIs with context7, and run the commands above on a Mac
(or via the `XcodeBuildMCP` server from `.mcp.json`).

## Project structure
```
ios/
├── project.yml                 XcodeGen spec (targets Habitly + HabitlyTests, Swift 6, iOS 26)
├── Config/
│   ├── Shared.xcconfig         MARKETING_VERSION / CURRENT_PROJECT_VERSION
│   ├── Debug.xcconfig          API_BASE_URL=http://localhost:8080, Info-Debug.plist, optional Local.xcconfig
│   ├── Release.xcconfig        API_BASE_URL=https://…, Info-Release.plist
│   ├── Info-Debug.plist        API_BASE_URL key + ATS exception for localhost (Debug only)
│   └── Info-Release.plist      API_BASE_URL key, no ATS exceptions
├── Habitly/
│   ├── App/                    HabitlyApp (@main), AppEnvironment (composition root), RootView (bootstrap/auth/main routing), MainTabView (glass tab bar)
│   ├── Core/
│   │   ├── Networking/         APIClient actor (+ endpoints), DTOs (contract mirror), APIError, JSONCoding (ISO dates, DayKey), AppConfig
│   │   ├── Auth/               KeychainStore (Security), TokenStore actor (single-flight refresh), AuthStore (@Observable session)
│   │   ├── I18n/               L10n (@Observable service), L10nCatalog (pure lookup/interpolation), L10nKey/L10nPluralKey, PluralRules, I18nCache
│   │   └── DesignSystem/       Palette (+ HabitColor/HabitIcon → Color/SF Symbol, AppTheme), HabitlyBackground (mesh), GlassComponents
│   ├── Features/
│   │   ├── Bootstrap/          Logo + spinner; icon-only retry (no text before the bundle loads)
│   │   ├── Auth/               Login / Register (morphing glass fields, validation, server field errors)
│   │   ├── Dashboard/          Greeting, progress ring, today's habits with one-tap check-in
│   │   ├── Habits/             HabitsStore, list (swipe/context actions), detail (streak, 5-week heatmap), editor sheet, delete confirm
│   │   ├── Stats/              StatsStore, summary cards, Swift Charts last-7-days bars
│   │   └── Settings/           Profile name, theme (system/light/dark), language picker (live reload + PATCH /me), about, logout
│   └── Resources/              Assets.xcassets (AppIcon placeholder, AccentColor), PrivacyInfo.xcprivacy
├── HabitlyTests/               Swift Testing: plural rules, catalog interpolation, DTO decoding, refresh single-flight (MockURLProtocol)
├── .claude/skills/             add-swiftui-screen, liquid-glass-patterns, i18n-keys
├── .github/workflows/ios.yml   CI
└── .mcp.json                   context7, github (docker), XcodeBuildMCP
```

## Architecture
- **Concurrency:** Swift 6 strict. UI state = `@MainActor @Observable final class` stores injected via `.environment(_:)` and read with
  `@Environment(Type.self)`. Networking/auth state = `actor`s (`APIClient`, `TokenStore`, `I18nCache`). DTOs are `Sendable` structs.
  Don't use `DispatchQueue`; use `async/await`, `.task {}`, `.refreshable {}`.
- **APIClient** adds `Authorization: Bearer`, `Accept-Language` (current bundle locale), `X-Timezone` (`TimeZone.current.identifier`)
  and `X-Client: ios`. On `401 TOKEN_EXPIRED` it calls `TokenStore.refreshAccessToken(failedAccessToken:)` and retries once:
  - token that failed is no longer current → reuse the current one (someone already refreshed);
  - a refresh is in flight → join it (`refreshTask` is cleared inside the actor in the same step that stores the new tokens,
    so a *completed* refresh is never re-joined);
  - otherwise start exactly one refresh (a freshly issued token rejected later triggers a new refresh, not a replay).
  Refresh rejected (4xx) → tokens cleared → `AuthStore.handleSessionExpired()` → login screen. Offline / 5xx / 429 during refresh
  keeps the session and surfaces the error.
- **AppEnvironment.shared** is the single composition root (created once); `AuthStore.start()` is idempotent and cancellation-safe
  (never leaves `.checking`).
- **Locales** come from `GET /i18n/locales` (currently `en` default, `ru`, `hy`); the picker and initial choice are data-driven.
  Initial locale: saved preference → first device language whose language code matches an available locale (`hy-AM` → `hy`) → backend default.
- **i18n cache** files are keyed by the *requested* locale code (normalized lowercase), not by `bundle.locale`.
- **Tokens** live in the Keychain (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`); cleared on first launch after reinstall.
- **Dates:** timestamps decode from ISO-8601 (with/without fractional seconds); calendar days are `"YYYY-MM-DD"` strings via `DayKey` (device time zone, matches `X-Timezone`).
- **Errors:** show `l10n.message(for:)` — backend-localized `error.message`, else `messageKey` lookup, network → `errors.network`, else `common.error_generic`.

## ABSOLUTE RULE — no UI literals
- No user-facing string literals anywhere in Swift: not in `Text`, `Label`, `Button`, titles, prompts, alerts, accessibility labels/hints/values, errors.
- No `Localizable.strings`, no String Catalogs (`.xcstrings`), no `NSLocalizedString` / `String(localized:)` / `LocalizedStringKey(...)`.
  (`LOCALIZATION_PREFERS_STRING_CATALOGS = NO`, `SWIFT_EMIT_LOC_STRINGS = NO`.) The only shipped human text is the launcher name `Habitly` (`PRODUCT_NAME`).
- Always `Text(verbatim: l10n.t(.key))` so SwiftUI never interprets our strings as localization keys. Same for `Label { Text(verbatim:) } icon: { … }`,
  `.navigationTitle(Text(verbatim:))`, `.accessibilityLabel(Text(verbatim:))`, `TextField(text:prompt:label:)` with `Text(verbatim:)`.
- Non-language data is fine verbatim: user content (habit names), numbers via `l10n.number`, dates via `.formatted(….locale(l10n.swiftLocale))`, SF Symbol names, API paths.
- Enforced by SwiftLint custom rules (`no_text_literal`, `no_literal_modifiers`, `no_localized_string`, `text_needs_verbatim`).

## How to use L10n
```swift
@Environment(L10n.self) private var l10n
Text(verbatim: l10n.t(.habitsTitle))
Text(verbatim: l10n.t(.dashboardGreeting, ["name": user.displayName]))
Text(verbatim: l10n.plural(.habitsStreak, count: streak))     // _one/_few/_many/_other, {count} auto-filled
l10n.number(5); l10n.percent(0.42); l10n.swiftLocale          // locale-aware formatting
```
Placeholder contract (agreed with backend): `dashboard.greeting {name}`, `dashboard.progress {done} {total}`,
`habits.this_week {done} {target}`, `habits.created {date}`, `habits.delete_confirm_message {name}`,
`validation.password_min {min}`, `validation.too_long {max}`, `validation.target_range {min} {max}`, plurals `{count}` (categories: en one/other, hy one for 0–1 / other, ru one/few/many; fallback `_other`).
Adding a key: add it to backend `en.json` + `ru.json` + `hy.json` first, then a `case` in `L10nKey` (or base key in `L10nPluralKey`). See `.claude/skills/i18n-keys`.
Bootstrap: cached bundle (Application Support/Habitly/i18n) renders instantly, then `If-None-Match` revalidation; no cache + offline → logo + icon-only retry.

## Liquid Glass guidelines (as used here)
- Native glass first: `TabView` + `Tab(value:content:label:)` with `.tabBarMinimizeBehavior(.onScrollDown)`; toolbar buttons; sheets with `.presentationDetents`.
- Primary actions `.buttonStyle(.glassProminent).tint(color)`; secondary `.buttonStyle(.glass)`; icon toggles `.glassEffect(.regular.interactive(), in: .circle)`.
- Surfaces: `.glassCard(tint:)` (= `.glassEffect(.regular.tint(...), in: .rect(cornerRadius: 24))`).
- `GlassEffectContainer` only around clusters meant to blend/morph; morph with `@Namespace` + `.glassEffectID(_:in:)` + `withAnimation`.
- Every screen sits on `HabitlyBackground()` (palette `MeshGradient`, ~12 fps timeline, paused with Reduce Motion) so glass has color to refract;
  `List`/`Form` use `.scrollContentBackground(.hidden)`.
- Put `.glassEffectID(_:in:)` directly on the view that carries `.glassEffect` (after it), inside the `GlassEffectContainer`.
- Motion: symbol effects (`.bounce`, `.replace`, `.pulse`), `.numericText` transitions, springs; haptics via `.sensoryFeedback`. Respect Reduce Motion.
- Details & snippets: `.claude/skills/liquid-glass-patterns`.

## Code style
- 4-space indent, max ~140 cols, trailing commas in multi-line literals, `swiftformat` config in repo.
- Types `UpperCamelCase`, members `lowerCamelCase`; L10n keys `L10nKey.featureKeyName` ↔ `"feature.key_name"`.
- One primary type per file; views are `struct …View`; stores `…Store` (`@MainActor @Observable final class`, `private(set)` state,
  `@ObservationIgnored` for dependencies). Actors for shared mutable non-UI state. Everything crossing actors is `Sendable`.
- No stored `static let` of non-`Sendable` SwiftUI values (gradients, shape styles) — use computed `static var` (Swift 6).
- Prefer `private` helpers/computed sub-views over giant bodies; no force unwraps in app code (tests/fixtures may).
- Accessibility: icon-only controls must have `accessibilityLabel` from L10n; decorative images `accessibilityHidden(true)`.
- Do not commit generated files (`*.xcodeproj`, DerivedData). Do not commit/push unless asked.
