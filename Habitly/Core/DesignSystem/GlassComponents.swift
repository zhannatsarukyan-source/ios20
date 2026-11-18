import SwiftUI

// MARK: - Glass card

struct GlassCardModifier: ViewModifier {
    var tint: Color?
    var cornerRadius: CGFloat = Metrics.cornerRadius
    var interactive = false
    var padding: CGFloat = Metrics.padding

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(glass, in: .rect(cornerRadius: cornerRadius))
    }

    private var glass: Glass {
        var glass = Glass.regular
        if let tint { glass = glass.tint(tint.opacity(0.22)) }
        return glass.interactive(interactive)
    }
}

extension View {
    /// Rounded Liquid Glass surface. Group sibling cards in a `GlassEffectContainer`.
    func glassCard(
        tint: Color? = nil,
        cornerRadius: CGFloat = Metrics.cornerRadius,
        interactive: Bool = false,
        padding: CGFloat = Metrics.padding
    ) -> some View {
        modifier(GlassCardModifier(tint: tint, cornerRadius: cornerRadius, interactive: interactive, padding: padding))
    }
}

// MARK: - Habit icon badge

struct HabitIconBadge: View {
    let icon: HabitIcon
    let color: HabitColor
    var size: CGFloat = 44
    var filled = false

    var body: some View {
        Image(systemName: icon.symbolName)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(filled ? Color.white : color.color)
            .frame(width: size, height: size)
            .background(Circle().fill(filled ? color.color.gradient : color.color.opacity(0.18).gradient))
            .contentTransition(.symbolEffect(.replace))
            .accessibilityHidden(true)
    }
}

// MARK: - Progress ring

struct ProgressRing: View {
    var progress: Double
    var lineWidth: CGFloat = 14
    var colors: [Color] = [Palette.coral, Palette.amber, Palette.rose, Palette.coral]

    @State private var displayed: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.08), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, displayed))
                .stroke(
                    AngularGradient(colors: colors, center: .center),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .onAppear {
            withAnimation(.spring(duration: 1.1, bounce: 0.25)) { displayed = clamped(progress) }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.spring(duration: 0.8, bounce: 0.3)) { displayed = clamped(newValue) }
        }
    }

    private func clamped(_ value: Double) -> Double { min(max(value, 0), 1) }
}

// MARK: - Week dots (weekCount / targetPerWeek, no text)

struct WeekDots: View {
    let count: Int
    let target: Int
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<max(target, 1), id: \.self) { index in
                Capsule()
                    .fill(index < count ? AnyShapeStyle(color.gradient) : AnyShapeStyle(Color.primary.opacity(0.12)))
                    .frame(width: 14, height: 6)
            }
        }
        .animation(.bouncy, value: count)
    }
}

// MARK: - Banner (errors / toasts)

struct BannerModifier: ViewModifier {
    @Binding var message: String?
    var symbol: String
    var tint: Color

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let message {
                HStack(spacing: 10) {
                    Image(systemName: symbol)
                        .foregroundStyle(tint)
                        .symbolEffect(.bounce, value: message)
                    Text(verbatim: message)
                        .font(.subheadline.weight(.medium))
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .glassEffect(.regular.tint(tint.opacity(0.15)).interactive(), in: .capsule)
                .padding(.horizontal, Metrics.padding)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .onTapGesture { withAnimation(.smooth) { self.message = nil } }
                .task(id: message) { @MainActor in
                    // Auto-dismiss; a cancelled sleep (new message / view gone) must not clear the binding.
                    do {
                        try await Task.sleep(for: .seconds(4))
                    } catch {
                        return
                    }
                    withAnimation(.smooth) { self.message = nil }
                }
                .accessibilityAddTraits(.isStaticText)
            }
        }
        .animation(.bouncy, value: message)
    }
}

extension View {
    func errorBanner(_ message: Binding<String?>) -> some View {
        modifier(BannerModifier(message: message, symbol: "exclamationmark.triangle.fill", tint: Palette.coral))
    }

    func successBanner(_ message: Binding<String?>) -> some View {
        modifier(BannerModifier(message: message, symbol: "checkmark.seal.fill", tint: Palette.mint))
    }
}

// MARK: - Logo

struct LogoMark: View {
    var size: CGFloat = 96
    var animating = false

    var body: some View {
        Image(systemName: "checkmark.seal.fill")
            .font(.system(size: size * 0.5, weight: .bold))
            .foregroundStyle(Palette.brandGradient)
            .symbolEffect(.pulse, isActive: animating)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
