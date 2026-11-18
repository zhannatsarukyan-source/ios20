import SwiftUI

struct HabitDetailView: View {
    let habitId: String

    @Environment(L10n.self) private var l10n
    @Environment(HabitsStore.self) private var habits
    @Environment(StatsStore.self) private var stats
    @Environment(\.dismiss) private var dismiss

    @State private var checkedDays: Set<String> = []
    @State private var showEditor = false
    @State private var confirmDelete = false
    @State private var errorMessage: String?
    /// Set once the habit is deleted: the view stops rendering/refetching it while the pop animation runs.
    @State private var isDeleted = false

    private let heatmapWeeks = 5

    var body: some View {
        Group {
            if !isDeleted, let habit = habits.habit(id: habitId) {
                content(habit)
            } else if !isDeleted {
                ProgressView()
            }
        }
        .background { HabitlyBackground(accent: habits.habit(id: habitId)?.color.color) }
        .navigationBarTitleDisplayMode(.inline)
        .errorBanner($errorMessage)
    }

    private func content(_ habit: HabitWithProgress) -> some View {
        ScrollView {
            VStack(spacing: Metrics.spacing) {
                hero(habit)
                HStack(alignment: .top, spacing: 12) {
                    streakCard(habit)
                    targetCard(habit)
                }
                .fixedSize(horizontal: false, vertical: true)
                checkInButton(habit)
                historyCard(habit)
                Text(verbatim: l10n.t(.habitsCreated, [
                    "date": habit.createdAt.formatted(.dateTime.day().month(.wide).year().locale(l10n.swiftLocale)),
                ]))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            }
            .padding(.horizontal, Metrics.padding)
            .padding(.bottom, 32)
        }
        .refreshable { await reload(habit) }
        .task(id: habit.checkedInToday) { await loadHistory(habit) }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showEditor = true
                } label: {
                    Image(systemName: "pencil")
                }
                .accessibilityLabel(Text(verbatim: l10n.t(.commonEdit)))
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    confirmDelete = true
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel(Text(verbatim: l10n.t(.commonDelete)))
            }
        }
        .sheet(isPresented: $showEditor) {
            HabitEditorSheet(mode: .edit(habit))
        }
        .alert(Text(verbatim: l10n.t(.habitsDeleteConfirmTitle)), isPresented: $confirmDelete) {
            Button(role: .destructive) {
                Task { await delete(habit) }
            } label: {
                Text(verbatim: l10n.t(.commonDelete))
            }
            Button(role: .cancel) {} label: {
                Text(verbatim: l10n.t(.commonCancel))
            }
        } message: {
            Text(verbatim: l10n.t(.habitsDeleteConfirmMessage, ["name": habit.name]))
        }
    }

    // MARK: - Sections

    private func hero(_ habit: HabitWithProgress) -> some View {
        VStack(spacing: 12) {
            Image(systemName: habit.icon.symbolName)
                .font(.system(size: 46, weight: .semibold))
                .foregroundStyle(habit.color.color.gradient)
                .symbolEffect(.bounce, value: habit.checkedInToday)
                .frame(width: 104, height: 104)
                .glassEffect(.regular.tint(habit.color.color.opacity(0.25)), in: .circle)
                .accessibilityLabel(Text(verbatim: l10n.t(habit.icon.l10nKey)))
            Text(verbatim: habit.name)
                .font(.system(.title, design: .rounded, weight: .bold))
                .multilineTextAlignment(.center)
            if let description = habit.description, !description.isEmpty {
                Text(verbatim: description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 8)
        .frame(maxWidth: .infinity)
    }

    private func streakCard(_ habit: HabitWithProgress) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "flame.fill")
                .font(.title2)
                .foregroundStyle(Palette.amber.gradient)
                .symbolEffect(.bounce, value: habit.currentStreak)
            Text(verbatim: l10n.number(habit.currentStreak))
                .font(.system(size: 40, weight: .heavy, design: .rounded))
                .contentTransition(.numericText(value: Double(habit.currentStreak)))
            Text(verbatim: l10n.plural(.habitsStreak, count: habit.currentStreak))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .glassCard(tint: Palette.amber)
        .accessibilityElement(children: .combine)
    }

    private func targetCard(_ habit: HabitWithProgress) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "target")
                .font(.title2)
                .foregroundStyle(habit.color.color.gradient)
            Text(verbatim: l10n.t(.habitsThisWeek, [
                "done": l10n.number(habit.weekCount),
                "target": l10n.number(habit.targetPerWeek),
            ]))
            .font(.subheadline.weight(.semibold))
            .contentTransition(.numericText(value: Double(habit.weekCount)))
            WeekDots(count: habit.weekCount, target: habit.targetPerWeek, color: habit.color.color)
            Text(verbatim: l10n.plural(.habitsTargetPerWeekValue, count: habit.targetPerWeek))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .glassCard(tint: habit.color.color)
        .accessibilityElement(children: .combine)
    }

    private func checkInButton(_ habit: HabitWithProgress) -> some View {
        Button {
            Task { await toggle(habit) }
        } label: {
            Label {
                Text(verbatim: l10n.t(habit.checkedInToday ? .habitsUndoCheckIn : .habitsCheckIn))
            } icon: {
                Image(systemName: habit.checkedInToday ? "arrow.uturn.backward" : "checkmark")
                    .contentTransition(.symbolEffect(.replace))
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .frame(height: 32)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
        .tint(habit.checkedInToday ? Color.gray : habit.color.color)
        .disabled(habits.pendingCheckIns.contains(habit.id))
        .sensoryFeedback(trigger: habit.checkedInToday) { _, newValue in
            newValue ? .success : .impact(weight: .light)
        }
    }

    private func historyCard(_ habit: HabitWithProgress) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text(verbatim: l10n.t(.habitsHistory))
            } icon: {
                Image(systemName: "calendar")
            }
            .font(.headline)
            HeatmapView(checkedDays: checkedDays, color: habit.color.color, weeks: heatmapWeeks)
        }
        .glassCard()
    }

    // MARK: - Actions

    private func loadHistory(_ habit: HabitWithProgress) async {
        // Fetch one extra week so the range covers the grid whatever the locale's first weekday is.
        let calendar = Calendar.current
        guard let first = calendar.date(byAdding: .day, value: -7 * (heatmapWeeks + 1), to: .now) else { return }
        do {
            let items = try await habits.checkIns(
                habitId: habit.id,
                from: DayKey.string(from: first, calendar: calendar),
                to: DayKey.today
            )
            withAnimation(.smooth) { checkedDays = Set(items.map(\.date)) }
        } catch is CancellationError {
            // View went away.
        } catch {
            errorMessage = l10n.message(for: error)
        }
    }

    private func reload(_ habit: HabitWithProgress) async {
        do {
            try await habits.load()
        } catch {
            errorMessage = l10n.message(for: error)
        }
        await loadHistory(habit)
    }

    private func toggle(_ habit: HabitWithProgress) async {
        do {
            try await habits.toggleCheckIn(id: habit.id)
            try? await stats.load()
        } catch {
            errorMessage = l10n.message(for: error)
        }
    }

    private func delete(_ habit: HabitWithProgress) async {
        guard !isDeleted else { return }
        do {
            try await habits.delete(id: habit.id)
            isDeleted = true
            dismiss()
            try? await stats.load()
        } catch {
            errorMessage = l10n.message(for: error)
        }
    }
}
