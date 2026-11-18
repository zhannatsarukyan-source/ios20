---
name: liquid-glass-patterns
description: iOS 26 Liquid Glass recipes used in Habitly — glassEffect, GlassEffectContainer, glassEffectID morphing, glass button styles, glass tab bar and toolbars, sheets, mesh backgrounds. Use when styling or reviewing SwiftUI UI in ios/.
---

# Liquid Glass patterns (iOS 26, SwiftUI)

Verify unfamiliar APIs with context7 (`/websites/developer_apple_swiftui`) — the repo is often edited on Windows without a compiler.

## Core APIs
- `view.glassEffect()` — default `.regular` glass in a capsule.
- `view.glassEffect(.regular.tint(color.opacity(0.25)).interactive(), in: .rect(cornerRadius: 24))`
  (`Glass`: `.regular`, `.clear`, `.identity`; modifiers `.tint(_:)`, `.interactive(_:)`). Shapes: `.circle`, `.capsule`, `.rect(cornerRadius:)`.
- `GlassEffectContainer(spacing: 10) { … }` renders sibling glass together and lets shapes blend/morph.
  Only wrap elements that should merge (a control cluster). Do not wrap separate cards whose gap is at or below `spacing` — they blob together.
- Morphing: `@Namespace var ns` + `.glassEffectID(id, in: ns)` on glass views inside the same container; insert/remove inside `withAnimation(.bouncy)`.
  Used in: Bootstrap (spinner ↔ retry), Auth (display-name field appears), Dashboard row (streak pill grows out of the check button), Settings (save-name button), editor color picker.
- Buttons: `.buttonStyle(.glass)` (secondary), `.buttonStyle(.glassProminent)` + `.tint(color)` (primary).
  Circular icon toggles: `Button { … } label: { Image(…).frame(width: 54, height: 54).contentShape(.circle) }.buttonStyle(.plain).glassEffect(.regular.interactive(), in: .circle)`.
- Tab bar: native `TabView(selection:)` + `Tab(value:content:label:)` → system glass tab bar; `.tabBarMinimizeBehavior(.onScrollDown)`.
- Toolbars: plain `ToolbarItem` buttons get glass automatically; use `.buttonStyle(.glassProminent)` for the confirm action.
- Sheets: `.presentationDetents([.medium, .large])` — don't set a sheet background so the system glass shows on partial detents.

## Repo helpers (`Habitly/Core/DesignSystem`)
- `HabitlyBackground(accent:)` — animated `MeshGradient` from the palette (respects Reduce Motion). Put it behind every screen:
  `.background { HabitlyBackground() }`; for `List`/`Form` also `.scrollContentBackground(.hidden)`.
- `.glassCard(tint:cornerRadius:interactive:padding:)`, `HabitIconBadge`, `ProgressRing`, `WeekDots`,
  `.errorBanner($message)`, `.successBanner($message)`, `LogoMark`.

## Rules
- Glass is for the control/navigation layer and floating cards. Avoid glass-on-glass stacks.
- Pair state changes with motion: `.contentTransition(.symbolEffect(.replace))`, `.contentTransition(.numericText(value:))`, `.symbolEffect(.bounce, value:)`.
- Haptics: `.sensoryFeedback(trigger:) { _, new in new ? .success : .impact(weight: .light) }` on check-in; `.selection` for pickers.
- Accessibility: every icon-only control gets `.accessibilityLabel(Text(verbatim: l10n.t(…)))`; decorative glass/backgrounds `.accessibilityHidden(true)`.
- Light/dark: palette colors + `.primary/.secondary`; white foreground only on tinted/prominent glass.
