import SwiftUI

/// Create / edit sheet: name, description, color + icon pickers (glass morphing selection), weekly target stepper.
struct HabitEditorSheet: View {
    enum Mode: Identifiable {
        case create
        case edit(HabitWithProgress)

        var id: String {
            switch self {
            case .create: "create"
            case .edit(let habit): habit.id
            }
        }

        var habit: HabitWithProgress? {
            if case .edit(let habit) = self { return habit }
            return nil
        }
    }

    private enum Field: Hashable { case name, description }

    let mode: Mode

    @Environment(L10n.self) private var l10n
    @Environment(HabitsStore.self) private var habits
    @Environment(StatsStore.self) private var stats
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var details = ""
    @State private var color: HabitColor = .coral
    @State private var icon: HabitIcon = .run
    @State private var target = 3
    @State private var nameError: String?
    @State private var detailsError: String?
    @State private var errorMessage: String?
    @State private var isSaving = false
    @State private var didLoad = false
    @State private var savedCount = 0

    @FocusState private var focus: Field?
    @Namespace private var pickerNamespace

    private static let nameMax = 60
    private static let descriptionMax = 280
    private static let targetRange = 1...7

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    preview
                    textFields
                    colorPicker
                    iconPicker
                    targetStepper
                }
                .padding(Metrics.padding)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(Text(verbatim: l10n.t(mode.habit == nil ? .habitsNew : .habitsEdit)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel(Text(verbatim: l10n.t(.commonCancel)))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Image(systemName: "checkmark")
                        }
                    }
                    .buttonStyle(.glassProminent)
                    .tint(color.color)
                    .disabled(isSaving)
                    .accessibilityLabel(Text(verbatim: l10n.t(.commonSave)))
                }
            }
            .errorBanner($errorMessage)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .sensoryFeedback(.success, trigger: savedCount)
        .onAppear(perform: loadInitialValues)
    }

    // MARK: - Sections

    private var preview: some View {
        HStack(spacing: 14) {
            HabitIconBadge(icon: icon, color: color, size: 56, filled: true)
                .symbolEffect(.bounce, value: icon)
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: name.isEmpty ? l10n.t(.habitsNamePlaceholder) : name)
                    .font(.headline)
                    .foregroundStyle(name.isEmpty ? Color.secondary : Color.primary)
                    .lineLimit(1)
                Text(verbatim: l10n.plural(.habitsTargetPerWeekValue, count: target))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText(value: Double(target)))
            }
            Spacer(minLength: 0)
        }
        .glassCard(tint: color.color)
        .animation(.bouncy, value: color)
        .accessibilityHidden(true)
    }

    private var textFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(.habitsName)
            TextField(text: $name, prompt: Text(verbatim: l10n.t(.habitsNamePlaceholder))) {
                Text(verbatim: l10n.t(.habitsName))
            }
            .focused($focus, equals: .name)
            .submitLabel(.next)
            .onSubmit { focus = .description }
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: Metrics.smallCornerRadius))
            fieldError(nameError)

            sectionTitle(.habitsDescription)
            TextField(
                text: $details,
                prompt: Text(verbatim: l10n.t(.habitsDescriptionPlaceholder)),
                axis: .vertical
            ) {
                Text(verbatim: l10n.t(.habitsDescription))
            }
            .lineLimit(2...5)
            .focused($focus, equals: .description)
            .padding(16)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: Metrics.smallCornerRadius))
            fieldError(detailsError)
        }
    }

    private var colorPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(.habitsColor)
            GlassEffectContainer(spacing: 10) {
                HStack(spacing: 10) {
                    ForEach(HabitColor.allCases) { option in
                        let selected = option == color
                        Button {
                            withAnimation(.bouncy) { color = option }
                        } label: {
                            Circle()
                                .fill(option.color.gradient)
                                .frame(width: 34, height: 34)
                                .overlay {
                                    if selected {
                                        Image(systemName: "checkmark")
                                            .font(.caption.weight(.heavy))
                                            .foregroundStyle(.white)
                                            .transition(.scale.combined(with: .opacity))
                                    }
                                }
                                .padding(6)
                                .contentShape(.circle)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(
                            selected ? Glass.regular.tint(option.color.opacity(0.4)).interactive() : Glass.regular.interactive(),
                            in: .circle
                        )
                        .glassEffectID(option, in: pickerNamespace)
                        .scaleEffect(selected ? 1.08 : 1)
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel(Text(verbatim: l10n.t(option.l10nKey)))
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
            }
            .sensoryFeedback(.selection, trigger: color)
        }
    }

    private var iconPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(.habitsIcon)
            GlassEffectContainer(spacing: 10) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                    ForEach(HabitIcon.allCases) { option in
                        let selected = option == icon
                        Button {
                            withAnimation(.bouncy) { icon = option }
                        } label: {
                            Image(systemName: option.symbolName)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(selected ? Color.white : color.color)
                                .symbolEffect(.bounce, value: selected)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .contentShape(.rect(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                        .glassEffect(
                            selected ? Glass.regular.tint(color.color).interactive() : Glass.regular.interactive(),
                            in: .rect(cornerRadius: 16)
                        )
                        .accessibilityLabel(Text(verbatim: l10n.t(option.l10nKey)))
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
            }
            .sensoryFeedback(.selection, trigger: icon)
        }
    }

    /// Custom glass stepper: big touch targets, morphing glass buttons, localized a11y labels.
    private var targetStepper: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: l10n.t(.habitsTargetPerWeek))
                    .font(.headline)
                Text(verbatim: l10n.plural(.habitsTargetPerWeekValue, count: target))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText(value: Double(target)))
            }
            .accessibilityElement(children: .combine)

            Spacer(minLength: 0)

            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    stepButton(symbol: "minus", label: .commonDecrease, enabled: target > Self.targetRange.lowerBound) {
                        target -= 1
                    }
                    Text(verbatim: l10n.number(target))
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .contentTransition(.numericText(value: Double(target)))
                        .frame(minWidth: 28)
                        .accessibilityHidden(true)
                    stepButton(symbol: "plus", label: .commonIncrease, enabled: target < Self.targetRange.upperBound) {
                        target += 1
                    }
                }
            }
        }
        .glassCard()
        .sensoryFeedback(.selection, trigger: target)
        .animation(.snappy, value: target)
    }

    private func stepButton(symbol: String, label: L10nKey, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.headline.weight(.bold))
                .frame(width: 44, height: 44)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.tint(color.color.opacity(0.25)).interactive(), in: .circle)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
        .accessibilityLabel(Text(verbatim: l10n.t(label)))
    }

    private func sectionTitle(_ key: L10nKey) -> some View {
        Text(verbatim: l10n.t(key))
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.leading, 4)
    }

    @ViewBuilder
    private func fieldError(_ message: String?) -> some View {
        if let message {
            Text(verbatim: message)
                .font(.footnote.weight(.medium))
                .foregroundStyle(Palette.coral)
                .padding(.leading, 4)
        }
    }

    // MARK: - Actions

    private func loadInitialValues() {
        guard !didLoad else { return }
        didLoad = true
        if let habit = mode.habit {
            name = habit.name
            details = habit.description ?? ""
            color = habit.color
            icon = habit.icon
            target = habit.targetPerWeek
        } else {
            focus = .name
        }
    }

    private func validate() -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        nameError = nil
        detailsError = nil
        if trimmedName.isEmpty {
            nameError = l10n.t(.validationRequired)
        } else if trimmedName.count > Self.nameMax {
            nameError = l10n.t(.validationTooLong, ["max": l10n.number(Self.nameMax)])
        }
        if details.count > Self.descriptionMax {
            detailsError = l10n.t(.validationTooLong, ["max": l10n.number(Self.descriptionMax)])
        }
        if !Self.targetRange.contains(target) {
            errorMessage = l10n.t(.validationTargetRange, [
                "min": l10n.number(Self.targetRange.lowerBound),
                "max": l10n.number(Self.targetRange.upperBound),
            ])
            return false
        }
        return nameError == nil && detailsError == nil
    }

    private func save() async {
        guard !isSaving, validate() else { return }
        isSaving = true
        defer { isSaving = false }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            if let habit = mode.habit {
                try await habits.update(id: habit.id, UpdateHabitInput(
                    name: trimmedName,
                    description: trimmedDetails,
                    color: color,
                    icon: icon,
                    targetPerWeek: target
                ))
            } else {
                _ = try await habits.create(CreateHabitInput(
                    name: trimmedName,
                    description: trimmedDetails.isEmpty ? nil : trimmedDetails,
                    color: color,
                    icon: icon,
                    targetPerWeek: target
                ))
            }
            savedCount += 1
            try? await stats.load()
            dismiss()
        } catch let error as APIError {
            applyServerError(error)
        } catch {
            errorMessage = l10n.message(for: error)
        }
    }

    private func applyServerError(_ error: APIError) {
        var handled = false
        for detail in error.fieldDetails {
            let text = detail.message ?? detail.messageKey.flatMap { l10n.catalog.string(forRawKey: $0) }
            switch detail.field ?? "" {
            case "name": nameError = text; handled = true
            case "description": detailsError = text; handled = true
            default: break
            }
        }
        if !handled { errorMessage = l10n.message(for: error) }
    }
}
