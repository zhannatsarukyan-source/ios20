---
name: i18n-keys
description: Add or use an i18n key in the Habitly iOS app (backend-served bundles, typed L10nKey/L10nPluralKey, plurals, placeholders, no literals). Use whenever UI text, accessibility labels, errors or plurals are added or changed in ios/.
---

# i18n keys (Habitly iOS)

Source of truth: backend `image/apps/api/src/i18n/locales/<locale>.json` (flat `key → string`). The app ships **no** strings
(no Localizable.strings, no .xcstrings, no literals in SwiftUI).

## Adding a key
1. Add it to the backend `en.json` **and** `ru.json` (and every other locale file); run `npm run i18n:keys` in `image/`.
   Placeholders use `{name}`; plurals use suffixes `_one`, `_few`, `_many`, `_other` (always provide `_other`).
2. Mirror it in `Habitly/Core/I18n/L10nKey.swift`:
   - normal key → `case habitsFooBar = "habits.foo_bar"` in `L10nKey` (camelCase of the dotted key);
   - plural → base key without suffix in `L10nPluralKey`.
3. `L10nCatalogTests.keysAreWellFormedIdentifiers` checks format and uniqueness.

## Using keys
```swift
@Environment(L10n.self) private var l10n

Text(verbatim: l10n.t(.dashboardGreeting, ["name": user.displayName]))
Text(verbatim: l10n.plural(.habitsStreak, count: habit.currentStreak))   // {count} injected, locale-formatted
Text(verbatim: l10n.t(.dashboardProgress, ["done": l10n.number(done), "total": l10n.number(total)]))
.accessibilityLabel(Text(verbatim: l10n.t(.commonRetry)))
errorMessage = l10n.message(for: error)  // backend error.message → messageKey → errors.network / common.error_generic
```
- Always `Text(verbatim:)` — `Text(someString)` may be treated as a LocalizedStringKey.
- Dates/numbers: platform formatters with `l10n.swiftLocale` (never concatenate words).
- A missing key renders the key identifier — a visible developer signal; never ship that.
- Plural categories come from `PluralRules` (en; ru/uk/be exact; CJK → other; everything else en-style). Lookup falls back to `_other`.
- Adding a language = one JSON file on the backend (with `meta.language_name`). The app lists it from `/i18n/locales`
  automatically; if its plural rules differ from en-style, extend `PluralRules.category`.

## Bootstrap behaviour
`L10n.bootstrap()` loads cached locales/bundle from Application Support → renders immediately → revalidates with
`If-None-Match` (304 keeps the cache). With no cache and no network: logo + icon-only retry button (no text).
Switching language in Settings calls `l10n.switchLocale(code)` (live re-render) and `PATCH /me {locale}`.
