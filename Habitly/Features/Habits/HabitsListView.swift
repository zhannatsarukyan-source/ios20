import SwiftUI

struct HabitsListView: View {
    @Environment(L10n.self) private var l10n
    @Environment(HabitsStore.self) private var habits
    @Environment(StatsStore.self) private var stats

    @State private var editorMode: HabitEditorSheet.Mode?
    @State private var pendingDelete: HabitWithProgress?
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var path: [String] = []

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if habits.hasLoaded && habits.habits.isEmpty {
                    emptyRow
                }
                ForEach(habits.habits) { habit in
                    NavigationLink(value: habit.id) {
                        HabitListRow(habit: habit)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: Metrics.padding, bottom: 6, trailing: Metrics.padding))
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            pendingDelete = habit
                        } label: {
                            Label { Text(verbatim: l10n.t(.commonDelete)) } icon: { Image(systemName: "trash") }
                        }
                        Button {
                            editorMode = .edit(habit)
                        } label: {
                            Label { Text(verbatim: l10n.t(.commonEdit)) } icon: { Image(systemName: "pencil") }
                        }
                        .tint(habit.color.color)
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            Task { await toggle(habit) }
                        } label: {
                            Label {
                                Text(verbatim: l10n.t(habit.checkedInToday ? .habitsUndoCheckIn : .habitsCheckIn))
                            } icon: {
                                Image(systemName: habit.checkedInToday ? "arrow.uturn.backward" : "checkmark")
                            }
                        }
                        .tint(habit.checkedInToday ? .gray : Palette.mint)
                    }
                    .contextMenu {
                        Button {
                            editorMode = .edit(habit)
                        } label: {
                            Label { Text(verbatim: l10n.t(.commonEdit)) } icon: { Image(systemName: "pencil") }
                        }
                        Button(role: .destructive) {
                            pendingDelete = habit
                        } label: {
                            Label { Text(verbatim: l10n.t(.commonDelete)) } icon: { Image(systemName: "trash") }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background { HabitlyBackground() }
            .refreshable { await reload() }
            .navigationTitle(Text(verbatim: l10n.t(.habitsTitle)))
            .navigationDestination(for: String.self) { id in
                HabitDetailView(habitId: id)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editorMode = .create
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(Text(verbatim: l10n.t(.habitsNew)))
                }
            }
            .sheet(item: $editorMode) { mode in
                HabitEditorSheet(mode: mode)
            }
            .confirmationDialog(
                Text(verbatim: l10n.t(.habitsDeleteConfirmTitle)),
                isPresented: Binding(
                    get: { pendingDelete != nil },
                    set: { if !$0 { pendingDelete = nil } }
                ),
                titleVisibility: .visible,
                presenting: pendingDelete
            ) { habit in
                Button(role: .destructive) {
                    Task { await delete(habit) }
                } label: {
                    Text(verbatim: l10n.t(.commonDelete))
                }
                Button(role: .cancel) {
                    pendingDelete = nil
                } label: {
                    Text(verbatim: l10n.t(.commonCancel))
                }
            } message: { habit in
                Text(verbatim: l10n.t(.habitsDeleteConfirmMessage, ["name": habit.name]))
            }
            .errorBanner($errorMessage)
            .successBanner($successMessage)
            .onChange(of: habits.createdRevision) {
                successMessage = l10n.t(.habitsCreatedToast)
            }
        }
    }

    private var emptyRow: some View {
        VStack(spacing: 14) {
            Image(systemName: "square.stack.3d.up.slash")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(verbatim: l10n.t(.habitsEmpty))
                .font(.headline)
                .multilineTextAlignment(.center)
            Button {
                editorMode = .create
            } label: {
                Label { Text(verbatim: l10n.t(.habitsNew)) } icon: { Image(systemName: "plus") }
            }
            .buttonStyle(.glassProminent)
            .tint(Palette.coral)
        }
        .frame(maxWidth: .infinity)
        .glassCard()
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .padding(.top, 32)
    }

    private func reload() async {
        do {
            try await habits.load()
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

    private func delete(_ habit: HabitWithProgress) async {
        pendingDelete = nil
        do {
            try await habits.delete(id: habit.id)
            path.removeAll { $0 == habit.id }
            try? await stats.load()
        } catch {
            errorMessage = l10n.message(for: error)
        }
    }
}

struct HabitListRow: View {
    let habit: HabitWithProgress
    @Environment(L10n.self) private var l10n

    var body: some View {
        HStack(spacing: 14) {
            HabitIconBadge(icon: habit.icon, color: habit.color, size: 46, filled: habit.checkedInToday)
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: habit.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                if let description = habit.description, !description.isEmpty {
                    Text(verbatim: description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                HStack(spacing: 10) {
                    Label {
                        Text(verbatim: l10n.plural(.habitsStreak, count: habit.currentStreak))
                    } icon: {
                        Image(systemName: "flame.fill").foregroundStyle(Palette.amber)
                    }
                    .labelStyle(.titleAndIcon)
                    Text(verbatim: l10n.plural(.habitsTargetPerWeekValue, count: habit.targetPerWeek))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if habit.checkedInToday {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(habit.color.color)
                    .symbolEffect(.bounce, value: habit.checkedInToday)
                    .accessibilityLabel(Text(verbatim: l10n.t(.habitsCheckedIn)))
            }
        }
        .glassCard(tint: habit.color.color, interactive: true, padding: 14)
        .accessibilityElement(children: .combine)
    }
}
