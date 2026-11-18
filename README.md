# Habitly iOS

SwiftUI client for **Habitly** — a habit tracker with streaks, check-ins and stats — built for **iOS 26** with Liquid Glass.

- Swift 6 (strict concurrency), SwiftUI + Observation, Swift Charts, Keychain, `URLSession` async/await — no third-party dependencies.
- Every user-facing string is served by the backend (`/api/v1/i18n/*`) and cached; the app contains only typed keys.
- Xcode project generated with XcodeGen.

## Quick start (macOS + Xcode 26)
```bash
brew install xcodegen
xcodegen generate
open Habitly.xcodeproj        # run the "Habitly" scheme on an iOS 26 simulator
```
The Debug build talks to `http://localhost:8080` (start the Habitly API locally). Change it in `Config/Debug.xcconfig`
or a git-ignored `Config/Local.xcconfig`.

## Tests
```bash
xcodebuild test -project Habitly.xcodeproj -scheme Habitly \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' CODE_SIGNING_ALLOWED=NO
```

See [CLAUDE.md](CLAUDE.md) for architecture, conventions (no UI literals!) and Liquid Glass guidelines.
