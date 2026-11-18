import SwiftUI

/// Slowly drifting mesh gradient built from the Habitly palette. Gives Liquid Glass
/// something colorful to refract — place it behind content with `.background { HabitlyBackground() }`.
/// Cheap by design: the timeline ticks at ~12 fps (motion is very slow, so it reads smooth), pauses with
/// Reduce Motion, and SwiftUI pauses timelines of off-screen tabs.
struct HabitlyBackground: View {
    var accent: Color?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            (colorScheme == .dark ? Palette.nightBase : Palette.dayBase)
            TimelineView(.animation(minimumInterval: 1.0 / 12.0, paused: reduceMotion)) { context in
                let time = Float(context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600))
                MeshGradient(width: 3, height: 3, points: points(time), colors: colors)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private var colors: [Color] {
        let strength = colorScheme == .dark ? 0.55 : 0.45
        let top = accent ?? Palette.coral
        return [
            top.opacity(strength), Palette.amber.opacity(strength * 0.8), Palette.rose.opacity(strength),
            Palette.violet.opacity(strength * 0.6), .clear, Palette.sky.opacity(strength * 0.6),
            Palette.mint.opacity(strength * 0.5), Palette.sky.opacity(strength * 0.5), Palette.violet.opacity(strength * 0.7),
        ]
    }

    private func points(_ time: Float) -> [SIMD2<Float>] {
        let amplitude: Float = reduceMotion ? 0 : 0.08
        return [
            SIMD2(0, 0), SIMD2(0.5 + amplitude * sin(time * 0.31), 0), SIMD2(1, 0),
            SIMD2(0, 0.5 + amplitude * cos(time * 0.27)),
            SIMD2(0.5 + amplitude * sin(time * 0.43), 0.5 + amplitude * cos(time * 0.37)),
            SIMD2(1, 0.5 + amplitude * sin(time * 0.29)),
            SIMD2(0, 1), SIMD2(0.5 + amplitude * cos(time * 0.33), 1), SIMD2(1, 1),
        ]
    }
}
