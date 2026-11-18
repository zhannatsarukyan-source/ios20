import SwiftUI

/// First launch: logo + spinner only (no text — the bundle isn't loaded yet).
/// On failure an icon-only retry button morphs out of the spinner.
struct BootstrapView: View {
    @Environment(L10n.self) private var l10n
    @Namespace private var glassNamespace

    private var failed: Bool { l10n.phase == .failed }

    var body: some View {
        ZStack {
            HabitlyBackground()

            GlassEffectContainer(spacing: 32) {
                VStack(spacing: 32) {
                    LogoMark(size: 120, animating: !failed)
                        .glassEffect(.regular.tint(Palette.coral.opacity(0.18)), in: .circle)
                        .glassEffectID("logo", in: glassNamespace)

                    if failed {
                        Button {
                            Task { await l10n.bootstrap() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.title2.weight(.semibold))
                                .frame(width: 64, height: 64)
                                .contentShape(.circle)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.tint(Palette.coral.opacity(0.35)).interactive(), in: .circle)
                        .glassEffectID("action", in: glassNamespace)
                        .sensoryFeedback(.error, trigger: failed)
                        .modifier(RetryAccessibility(l10n: l10n))
                    } else {
                        ProgressView()
                            .controlSize(.large)
                            .frame(width: 64, height: 64)
                            .glassEffect(.regular, in: .circle)
                            .glassEffectID("action", in: glassNamespace)
                    }
                }
            }
        }
        .animation(.bouncy(duration: 0.5), value: failed)
    }
}

/// Uses `common.retry` once a (cached) bundle exists; otherwise VoiceOver falls back to the SF Symbol's
/// built-in description — we never hardcode text.
private struct RetryAccessibility: ViewModifier {
    let l10n: L10n

    func body(content: Content) -> some View {
        if l10n.hasBundle {
            content.accessibilityLabel(Text(verbatim: l10n.t(.commonRetry)))
        } else {
            content
        }
    }
}
