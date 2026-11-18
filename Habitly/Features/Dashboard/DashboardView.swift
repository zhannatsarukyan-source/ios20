import SwiftUI

struct DashboardView: View {
    @Environment(L10n.self) private var l10n
    @Environment(AuthStore.self) private var auth
    @Environment(HabitsStore.self) private var habits
    @Environment(StatsStore.self) private var stats

    @State private var showEditor = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Metrics.spacing) {
                    header

                    if habits.hasLoaded && habits.habits.isEmpty {
                        emptyState
                    } else {
                        progressCard
                        habitList
                    }
                }
                .padding(.horizontal, Metrics.padding)
                .padding(.bottom, 32)
            }
            .background { HabitlyBackground() }
            .refreshable { await reload() }
            .navigationTitle(Text(verbatim: l10n.t(.dashboardToday)))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showEditor = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(Text(verbatim: l10n.t(.habitsNew)))
                }
            }
            .sheet(isPresented: $showEditor) {
                HabitEditorSheet(mode: .create)
            }
            .errorBanner($errorMessage)
            .successBanner($successMessage)
            .onChange(of: habits.createdRevision) {
                successMessage = l10n.t(.habitsCreatedToast)
            }
            .overlay {
                if !habits.hasLoaded && habits.isLoading {
                    ProgressView().controlSize(.large)
                }
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(l10n.swiftLocale)))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(verbatim: l10n.t(.dashboardGreeting, ["name": auth.user?.displayName ?? ""]))
                .font(.system(.title, design: .rounded, weight: .bold))
                .redacted(reason: auth.user == nil ? .placeholder : [])
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
        .accessibilityElement(children: .combine)
    }

    private var progressCard: some View {
        let done = habits.doneToday
        let total = habits.habits.count
        let allDone = total > 0 && done == total

        return HStack(spacing: 20) {
            ZStack {
                ProgressRing(progress: habits.progressToday)
                Text(verbatim: l10n.percent(habits.progressToday))
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .contentTransition(.numericText(value: habits.progressToday))
                    .animation(.snappy, value: habits.progressToday)
            }
            .frame(width: 104, height: 104)

            VStack(alignment: .leading, spacing: 8) {
                Text(verbatim: l10n.t(.dashboardProgress, ["done": l10n.number(done), "total": l10n.number(total)]))
                    .font(.headline)
                    .contentTransition(.numericText())
                if allDone {
                    Label {
                        Text(verbatim: l10n.t(.dashboardAllDone))
                    } icon: {
                        Image(systemName: "sparkles")
                            .symbolEffect(.bounce, value: allDone)
                            .foregroundStyle(Palette.amber)
                    }
                    .font(.subheadline.weight(.semibold))
                    .transition(.scale.combined(with: .opacity))
                }
            }
            Spacer(minLength: 0)
        }
        .glassCard(tint: allDone ? Palette.mint : nil)
        .animation(.bouncy, value: allDone)
        .accessibilityElement(children: .combine)
    }

    private var habitList: some View {
        LazyVStack(spacing: 12) {
            ForEach(habits.habits) { habit in
                TodayHabitRow(habit: habit, isPending: habits.pendingCheckIns.contains(habit.id)) {
                    Task { await toggle(habit) }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 52, weight: .semibold))
                .foregroundStyle(Palette.mint.gradient)
                .symbolEffect(.pulse)
                .frame(width: 96, height: 96)
                .glassEffect(.regular.tint(Palette.mint.opacity(0.2)), in: .circle)
                .accessibilityHidden(true)
            Text(verbatim: l10n.t(.dashboardEmptyTitle))
                .font(.title3.weight(.bold))
            Text(verbatim: l10n.t(.dashboardEmptySubtitle))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                showEditor = true
            } label: {
                Label {
                    Text(verbatim: l10n.t(.dashboardAddFirst))
                } icon: {
                    Image(systemName: "plus")
                }
                .font(.headline)
                .padding(.horizontal, 8)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .tint(Palette.coral)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .glassCard()
        .padding(.top, 24)
    }

    // MARK: - Actions

    private func reload() async {
        do {
            try await habits.load()
            try? await stats.load()
        } catch {
            errorMessage = l10n.message(for: error)
        }
    }

    private func toggle(_ habit: HabitWithProgress) async {
        do {
            try await habits.toggleCheckIn(id: habit.id)
            try? await stats.load()
        } catch {
            errorMessage = l10n.message(for: error)
        }
    }
}

// MARK: - Row

struct TodayHabitRow: View {
    let habit: HabitWithProgress
    var isPending = false
    let onToggle: () -> Void

    @Environment(L10n.self) private var l10n
    @Namespace private var glassNamespace

    var body: some View {
        HStack(spacing: 14) {
            HabitIconBadge(icon: habit.icon, color: habit.color, size: 48, filled: habit.checkedInToday)

            VStack(alignment: .leading, spacing: 6) {
                Text(verbatim: habit.name)
                    .font(.headline)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(habit.currentStreak > 0 ? Palette.amber : Color.secondary)
                        .symbolEffect(.bounce, value: habit.currentStreak)
                    Text(verbatim: l10n.plural(.habitsStreak, count: habit.currentStreak))
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText(value: Double(habit.currentStreak)))
                }
                .font(.subheadline)
                WeekDots(count: habit.weekCount, target: habit.targetPerWeek, color: habit.color.color)
                    .accessibilityElement()
                    .accessibilityLabel(Text(verbatim: l10n.t(.habitsThisWeek, [
                        "done": l10n.number(habit.weekCount),
                        "target": l10n.number(habit.targetPerWeek),
                    ])))
            }

            Spacer(minLength: 8)

            // The streak pill morphs out of the check button when checked in.
            GlassEffectContainer(spacing: 10) {
                HStack(spacing: 8) {
                    if habit.checkedInToday && habit.currentStreak > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "flame.fill")
                            Text(verbatim: l10n.number(habit.currentStreak))
                                .contentTransition(.numericText(value: Double(habit.currentStreak)))
                        }
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Palette.amber)
                        .padding(.horizontal, 10)
                        .frame(height: 32)
                        .glassEffect(.regular, in: .capsule)
                        .glassEffectID("streak", in: glassNamespace)
                        .accessibilityHidden(true)
                    }
                    CheckInButton(isOn: habit.checkedInToday, color: habit.color.color, isPending: isPending, action: onToggle)
                        .glassEffectID("check", in: glassNamespace)
                }
            }
        }
        .glassCard(tint: habit.checkedInToday ? habit.color.color : nil)
        .animation(.bouncy, value: habit.checkedInToday)
    }
}

/// Round glass check-in toggle with symbol replace transition + haptics.
struct CheckInButton: View {
    let isOn: Bool
    let color: Color
    var isPending = false
    var size: CGFloat = 54
    let action: () -> Void

    @Environment(L10n.self) private var l10n

    var body: some View {
        Button(action: action) {
            Image(systemName: isOn ? "checkmark" : "circle.dashed")
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundStyle(isOn ? Color.white : color)
                .contentTransition(.symbolEffect(.replace.downUp))
                .frame(width: size, height: size)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .glassEffect(isOn ? Glass.regular.tint(color).interactive() : Glass.regular.interactive(), in: .circle)
        .disabled(isPending)
        .sensoryFeedback(trigger: isOn) { _, newValue in
            newValue ? .success : .impact(weight: .light)
        }
        .accessibilityLabel(Text(verbatim: l10n.t(isOn ? .habitsUndoCheckIn : .habitsCheckIn)))
        .accessibilityValue(Text(verbatim: isOn ? l10n.t(.habitsCheckedIn) : ""))
    }
}
