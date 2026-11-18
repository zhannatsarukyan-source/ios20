import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

/// Habitly palette (SPEC §4).
enum Palette {
    static let coral = Color(hex: 0xFF6B5B)
    static let amber = Color(hex: 0xFFB547)
    static let mint = Color(hex: 0x3DD9A4)
    static let sky = Color(hex: 0x4DA8FF)
    static let violet = Color(hex: 0x8E7CFF)
    static let rose = Color(hex: 0xFF6FAE)

    static let brand = coral
    /// Computed (not a stored static): `LinearGradient` isn't `Sendable`, so a global `static let` would be
    /// a Swift 6 concurrency error.
    static var brandGradient: LinearGradient {
        LinearGradient(colors: [coral, rose, amber], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static let nightBase = Color(hex: 0x0E0B1A)
    static let dayBase = Color(hex: 0xFFF7F2)
}

enum Metrics {
    static let cornerRadius: CGFloat = 24
    static let smallCornerRadius: CGFloat = 18
    static let padding: CGFloat = 16
    static let spacing: CGFloat = 16
}

extension HabitColor {
    var color: Color {
        switch self {
        case .coral: Palette.coral
        case .amber: Palette.amber
        case .mint: Palette.mint
        case .sky: Palette.sky
        case .violet: Palette.violet
        case .rose: Palette.rose
        }
    }

    var l10nKey: L10nKey {
        switch self {
        case .coral: .colorCoral
        case .amber: .colorAmber
        case .mint: .colorMint
        case .sky: .colorSky
        case .violet: .colorViolet
        case .rose: .colorRose
        }
    }
}

extension HabitIcon {
    /// SF Symbol for each contract icon.
    var symbolName: String {
        switch self {
        case .run: "figure.run"
        case .book: "book.fill"
        case .water: "drop.fill"
        case .sleep: "moon.zzz.fill"
        case .meditate: "figure.mind.and.body"
        case .code: "chevron.left.forwardslash.chevron.right"
        case .heart: "heart.fill"
        case .leaf: "leaf.fill"
        }
    }

    var l10nKey: L10nKey {
        switch self {
        case .run: .iconRun
        case .book: .iconBook
        case .water: .iconWater
        case .sleep: .iconSleep
        case .meditate: .iconMeditate
        case .code: .iconCode
        case .heart: .iconHeart
        case .leaf: .iconLeaf
        }
    }
}

/// Appearance preference (Settings → theme). Raw values are storage identifiers, not UI text.
enum AppTheme: String, CaseIterable, Identifiable, Sendable {
    case system, light, dark

    static let storageKey = "habitly.theme"

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var l10nKey: L10nKey {
        switch self {
        case .system: .settingsThemeSystem
        case .light: .settingsThemeLight
        case .dark: .settingsThemeDark
        }
    }

    var symbolName: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        }
    }
}
