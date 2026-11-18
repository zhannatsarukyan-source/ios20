import Charts
import SwiftUI

struct StatsView: View {
    @Environment(L10n.self) private var l10n
    @Environment(StatsStore.self) private var stats

    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Metrics.spacing) {
                    if let summary = stats.summary {
                        cards(summary)
                        if summary.totalHabits == 0 {
                            emptyCard
                        } else {
                            chartCard(summary)
                        }
                    } else if stats.failed {
                        failedCard
                    } else {
                        ProgressView()
                            .controlSize(.large)
                            .padding(.top, 80)
                    }
                }
                .padding(.horizontal, Metrics.padding)
                .padding(.bottom, 32)
            }
            .background { HabitlyBackground() }
            .refreshable { await reload() }
            .navigationTitle(Text(verbatim: l10n.t(.statsTitle)))
            .errorBanner($errorMessage)
            // Initial load happens once in MainTabView; here only pull-to-refresh / retry.
        }
    }

    // MARK: - Sections

    private func cards(_ summary: StatsSummary) -> some View {
        // Separate cards: no GlassEffectContainer here, so neighbours don't blend into one blob.
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            StatCard(
                symbol: "square.stack.3d.up.fill",
                title: l10n.t(.statsTotalHabits),
                value: l10n.number(summary.totalHabits),
                numeric: Double(summary.totalHabits),
                color: Palette.sky
            )
            StatCard(
                symbol: "checkmark.circle.fill",
                title: l10n.t(.statsCompletedToday),
                value: l10n.number(summary.completedToday),
                numeric: Double(summary.completedToday),
                color: Palette.mint
            )
            StatCard(
                symbol: "flame.fill",
                title: l10n.t(.statsBestStreak),
                value: l10n.number(summary.bestStreak),
                numeric: Double(summary.bestStreak),
                color: Palette.amber
            )
            StatCard(
                symbol: "percent",
                title: l10n.t(.statsWeeklyRate),
                value: l10n.percent(summary.weeklyCompletionRate),
                numeric: summary.weeklyCompletionRate,
                color: Palette.violet
            )
        }
    }

    private func chartCard(_ summary: StatsSummary) -> some View {
        let maxTotal = max(summary.last7Days.map(\.total).max() ?? 1, 1)
        let dayLabel = l10n.t(.statsLast7Days)
        let valueLabel = l10n.t(.statsCompletedToday)

        return VStack(alignment: .leading, spacing: 14) {
            Label {
                Text(verbatim: l10n.t(.statsLast7Days))
            } icon: {
                Image(systemName: "chart.bar.xaxis")
            }
            .font(.headline)

            Chart(summary.last7Days) { day in
                BarMark(
                    x: .value(dayLabel, DayKey.date(from: day.date) ?? .now, unit: .day),
                    y: .value(valueLabel, day.completed)
                )
                .foregroundStyle(
                    LinearGradient(colors: [Palette.coral, Palette.amber], startPoint: .bottom, endPoint: .top)
                )
                .cornerRadius(8)
                .annotation(position: .top, spacing: 4) {
                    if day.completed > 0 {
                        Text(verbatim: l10n.number(day.completed))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .chartYScale(domain: 0...maxTotal)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated), centered: true)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: min(maxTotal, 4))) { _ in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .frame(height: 220)
            .animation(.smooth, value: summary.last7Days)
        }
        .glassCard()
    }

    private var emptyCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(verbatim: l10n.t(.statsEmpty))
                .font(.headline)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .glassCard()
    }

    private var failedCard: some View {
        VStack(spacing: 14) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(verbatim: l10n.t(.commonLoadingFailed))
                .font(.headline)
            Button {
                Task { await reload() }
            } label: {
                Label { Text(verbatim: l10n.t(.commonRetry)) } icon: { Image(systemName: "arrow.clockwise") }
            }
            .buttonStyle(.glass)
        }
        .frame(maxWidth: .infinity)
        .glassCard()
        .padding(.top, 40)
    }

    private func reload() async {
        do {
            try await stats.load()
        } catch {
            errorMessage = l10n.message(for: error)
        }
    }
}

struct StatCard: View {
    let symbol: String
    let title: String
    let value: String
    let numeric: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(color.gradient)
                .symbolEffect(.bounce, value: numeric)
                .accessibilityHidden(true)
            Text(verbatim: value)
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .contentTransition(.numericText(value: numeric))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(verbatim: title)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .glassCard(tint: color)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: title))
        .accessibilityValue(Text(verbatim: value))
    }
}
