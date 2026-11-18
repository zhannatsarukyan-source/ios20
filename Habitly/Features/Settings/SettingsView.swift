import SwiftUI

struct SettingsView: View {
    @Environment(L10n.self) private var l10n
    @Environment(AuthStore.self) private var auth

    @AppStorage(AppTheme.storageKey) private var theme: AppTheme = .system

    @State private var nameDraft = ""
    @State private var isSavingName = false
    @State private var confirmLogout = false
    @State private var errorMessage: String?
    @State private var savedCount = 0
    @Namespace private var glassNamespace

    private var trimmedDraft: String { nameDraft.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var nameChanged: Bool {
        !trimmedDraft.isEmpty && trimmedDraft != (auth.user?.displayName ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                profileSection
                appearanceSection
                languageSection
                aboutSection
                accountSection
            }
            .scrollContentBackground(.hidden)
            .background { HabitlyBackground() }
            .navigationTitle(Text(verbatim: l10n.t(.settingsTitle)))
            .errorBanner($errorMessage)
            .sensoryFeedback(.success, trigger: savedCount)
            .alert(Text(verbatim: l10n.t(.authLogoutConfirm)), isPresented: $confirmLogout) {
                Button(role: .destructive) {
                    Task { await auth.logout() }
                } label: {
                    Text(verbatim: l10n.t(.authLogout))
                }
                Button(role: .cancel) {} label: {
                    Text(verbatim: l10n.t(.commonCancel))
                }
            }
            .onAppear { syncDraft() }
            .onChange(of: auth.user?.displayName) { syncDraft() }
        }
    }

    // MARK: - Sections

    private var profileSection: some View {
        Section {
            HStack(spacing: 14) {
                Text(verbatim: initials)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(Palette.brandGradient))
                    .glassEffect(.regular.interactive(), in: .circle)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: auth.user?.displayName ?? "")
                        .font(.headline)
                    Text(verbatim: auth.user?.email ?? "")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .redacted(reason: auth.user == nil ? .placeholder : [])
            }
            .padding(.vertical, 4)

            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    TextField(text: $nameDraft, prompt: Text(verbatim: l10n.t(.authDisplayName))) {
                        Text(verbatim: l10n.t(.authDisplayName))
                    }
                    .textContentType(.name)
                    .submitLabel(.done)
                    .onSubmit { Task { await saveName() } }

                    if nameChanged {
                        Button {
                            Task { await saveName() }
                        } label: {
                            Group {
                                if isSavingName {
                                    ProgressView()
                                } else {
                                    Image(systemName: "checkmark")
                                        .font(.headline.weight(.bold))
                                }
                            }
                            .frame(width: 40, height: 40)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.tint(Palette.coral.opacity(0.4)).interactive(), in: .circle)
                        .glassEffectID("save-name", in: glassNamespace)
                        .disabled(isSavingName)
                        .accessibilityLabel(Text(verbatim: l10n.t(.commonSave)))
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .animation(.bouncy, value: nameChanged)
        } header: {
            Text(verbatim: l10n.t(.settingsProfile))
        }
    }

    private var appearanceSection: some View {
        Section {
            Picker(selection: $theme) {
                ForEach(AppTheme.allCases) { option in
                    Label {
                        Text(verbatim: l10n.t(option.l10nKey))
                    } icon: {
                        Image(systemName: option.symbolName)
                    }
                    .tag(option)
                }
            } label: {
                Text(verbatim: l10n.t(.settingsTheme))
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .sensoryFeedback(.selection, trigger: theme)
        } header: {
            Text(verbatim: l10n.t(.settingsTheme))
        }
    }

    private var languageSection: some View {
        Section {
            Picker(selection: Binding(
                get: { l10n.locale },
                set: { code in Task { await changeLanguage(code) } }
            )) {
                ForEach(l10n.locales) { locale in
                    Text(verbatim: locale.name).tag(locale.code)
                }
            } label: {
                Label {
                    Text(verbatim: l10n.t(.settingsLanguage))
                } icon: {
                    Image(systemName: "globe")
                        .symbolEffect(.rotate, value: l10n.locale)
                }
            }
            .pickerStyle(.navigationLink)
            .disabled(l10n.isSwitching)
        } header: {
            Text(verbatim: l10n.t(.settingsLanguage))
        }
    }

    private var aboutSection: some View {
        Section {
            LabeledContent {
                Text(verbatim: AppConfig.versionDisplay)
                    .monospacedDigit()
            } label: {
                Label {
                    Text(verbatim: l10n.t(.settingsVersion))
                } icon: {
                    Image(systemName: "info.circle")
                }
            }
            LabeledContent {
                Text(verbatim: l10n.t(.appTagline))
                    .multilineTextAlignment(.trailing)
            } label: {
                Label {
                    Text(verbatim: l10n.t(.appName))
                } icon: {
                    Image(systemName: "checkmark.seal")
                }
            }
        } header: {
            Text(verbatim: l10n.t(.settingsAbout))
        }
    }

    private var accountSection: some View {
        Section {
            Button(role: .destructive) {
                confirmLogout = true
            } label: {
                Label {
                    Text(verbatim: l10n.t(.authLogout))
                } icon: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                }
            }
        } header: {
            Text(verbatim: l10n.t(.settingsAccount))
        }
    }

    // MARK: - Helpers

    private var initials: String {
        let name = auth.user?.displayName ?? ""
        let letters = name.split(separator: " ").prefix(2).compactMap(\.first)
        return letters.isEmpty ? String(name.prefix(1)).uppercased() : String(letters).uppercased()
    }

    private func syncDraft() {
        nameDraft = auth.user?.displayName ?? ""
    }

    private func saveName() async {
        guard nameChanged, !isSavingName else { return }
        guard trimmedDraft.count <= 50 else {
            errorMessage = l10n.t(.validationTooLong, ["max": l10n.number(50)])
            return
        }
        isSavingName = true
        defer { isSavingName = false }
        do {
            try await auth.updateProfile(displayName: trimmedDraft)
            savedCount += 1
        } catch {
            errorMessage = l10n.message(for: error)
        }
    }

    private func changeLanguage(_ code: String) async {
        do {
            try await l10n.switchLocale(code)
            savedCount += 1
        } catch {
            errorMessage = l10n.message(for: error)
            return
        }
        // Persist on the account so other devices / backend messages follow.
        do {
            try await auth.updateProfile(locale: code)
        } catch {
            errorMessage = l10n.message(for: error)
        }
    }
}
