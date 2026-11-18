import SwiftUI

/// Pure layout helper (unit-testable): `count` weeks ending with the week that contains `today`,
/// each week starting on `calendar.firstWeekday`.
enum HeatmapLayout {
    static func weeks(count: Int, endingAt today: Date, calendar: Calendar) -> [[Date]] {
        guard count > 0 else { return [] }
        let startOfToday = calendar.startOfDay(for: today)
        let weekday = calendar.component(.weekday, from: startOfToday)
        let offset = (weekday - calendar.firstWeekday + 7) % 7
        guard
            let startOfWeek = calendar.date(byAdding: .day, value: -offset, to: startOfToday),
            let first = calendar.date(byAdding: .day, value: -7 * (count - 1), to: startOfWeek)
        else { return [] }
        return (0..<count).map { week in
            (0..<7).compactMap { day in calendar.date(byAdding: .day, value: week * 7 + day, to: first) }
        }
    }

    /// Localized very-short weekday symbols rotated to start at `firstWeekday`.
    static func weekdaySymbols(calendar: Calendar) -> [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let shift = calendar.firstWeekday - 1
        return Array(symbols[shift...] + symbols[..<shift])
    }
}

/// 5-week check-in heatmap (rows = weeks, columns = weekdays).
struct HeatmapView: View {
    let checkedDays: Set<String>
    let color: Color
    var weeks = 5

    @Environment(L10n.self) private var l10n

    private var localizedCalendar: Calendar {
        var calendar = Calendar.current
        calendar.locale = l10n.swiftLocale
        return calendar
    }

    var body: some View {
        let calendar = localizedCalendar
        let grid = HeatmapLayout.weeks(count: weeks, endingAt: .now, calendar: calendar)
        let today = calendar.startOfDay(for: .now)

        VStack(spacing: 6) {
            HStack(spacing: 6) {
                ForEach(Array(HeatmapLayout.weekdaySymbols(calendar: calendar).enumerated()), id: \.offset) { _, symbol in
                    Text(verbatim: symbol)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .accessibilityHidden(true)

            ForEach(grid, id: \.self) { week in
                HStack(spacing: 6) {
                    ForEach(week, id: \.self) { day in
                        cell(day: day, today: today, calendar: calendar)
                    }
                }
            }
        }
    }

    private func cell(day: Date, today: Date, calendar: Calendar) -> some View {
        let key = DayKey.string(from: day, calendar: calendar)
        let checked = checkedDays.contains(key)
        let isFuture = day > today
        let isToday = calendar.isDate(day, inSameDayAs: today)

        return RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(fill(checked: checked, future: isFuture))
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if isToday {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(color, lineWidth: 2)
                }
            }
            .frame(maxWidth: .infinity)
            .animation(.bouncy, value: checked)
            .accessibilityElement()
            .accessibilityLabel(Text(verbatim: day.formatted(.dateTime.day().month(.wide).weekday(.wide).locale(l10n.swiftLocale))))
            .accessibilityValue(Text(verbatim: checked ? l10n.t(.habitsCheckedIn) : ""))
            .accessibilityHidden(isFuture)
    }

    private func fill(checked: Bool, future: Bool) -> AnyShapeStyle {
        if checked { return AnyShapeStyle(color.gradient) }
        if future { return AnyShapeStyle(Color.primary.opacity(0.03)) }
        return AnyShapeStyle(color.opacity(0.14))
    }
}
