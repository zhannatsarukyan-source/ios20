import SwiftUI

struct AuthView: View {
    enum Mode: Equatable {
        case login
        case register
    }

    enum Field: Hashable {
        case displayName, email, password
    }

    @Environment(L10n.self) private var l10n
    @Environment(AuthStore.self) private var auth

    @State private var mode: Mode = .login
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var showPassword = false
    @State private var fieldErrors: [Field: String] = [:]
    @State private var errorMessage: String?
    @State private var isSubmitting = false
    @State private var failureCount = 0

    @FocusState private var focus: Field?
    @Namespace private var glassNamespace

    var body: some View {
        ZStack {
            HabitlyBackground()

            ScrollView {
                VStack(spacing: 28) {
                    header
                    fields
                    submitButton
                    modeSwitch
                }
                .padding(24)
                .frame(maxWidth: 480)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollBounceBehavior(.basedOnSize)
        }
        .errorBanner($errorMessage)
        .sensoryFeedback(.error, trigger: failureCount)
        .animation(.bouncy(duration: 0.45), value: mode)
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: 14) {
            LogoMark(size: 84)
                .glassEffect(.regular.tint(Palette.coral.opacity(0.18)), in: .circle)
                .padding(.top, 32)
            Text(verbatim: l10n.t(.appName))
                .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                .foregroundStyle(Palette.brandGradient)
            Text(verbatim: l10n.t(mode == .login ? .authLoginTitle : .authRegisterTitle))
                .font(.title2.weight(.bold))
                .contentTransition(.opacity)
            Text(verbatim: l10n.t(mode == .login ? .authLoginSubtitle : .authRegisterSubtitle))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .contentTransition(.opacity)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var fields: some View {
        GlassEffectContainer(spacing: 14) {
            VStack(spacing: 14) {
                if mode == .register {
                    inputRow(.displayName, symbol: "person.fill", title: l10n.t(.authDisplayName)) {
                        TextField(text: $displayName, prompt: Text(verbatim: l10n.t(.authDisplayName))) {
                            Text(verbatim: l10n.t(.authDisplayName))
                        }
                        .textContentType(.name)
                        .submitLabel(.next)
                    }
                    .transition(.blurReplace)
                }

                inputRow(.email, symbol: "envelope.fill", title: l10n.t(.authEmail)) {
                    TextField(text: $email, prompt: Text(verbatim: l10n.t(.authEmail))) {
                        Text(verbatim: l10n.t(.authEmail))
                    }
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                }

                inputRow(.password, symbol: "lock.fill", title: l10n.t(.authPassword)) {
                    HStack {
                        Group {
                            if showPassword {
                                TextField(text: $password, prompt: Text(verbatim: l10n.t(.authPassword))) {
                                    Text(verbatim: l10n.t(.authPassword))
                                }
                            } else {
                                SecureField(text: $password, prompt: Text(verbatim: l10n.t(.authPassword))) {
                                    Text(verbatim: l10n.t(.authPassword))
                                }
                            }
                        }
                        .textContentType(mode == .login ? .password : .newPassword)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.go)

                        Button {
                            showPassword.toggle()
                        } label: {
                            Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                .foregroundStyle(.secondary)
                                .contentTransition(.symbolEffect(.replace))
                                .frame(width: 32, height: 32)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(verbatim: l10n.t(showPassword ? .authHidePassword : .authShowPassword)))
                    }
                }
            }
        }
        .onSubmit(advanceFocus)
    }

    private func inputRow<Content: View>(
        _ field: Field,
        symbol: String,
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .foregroundStyle(fieldErrors[field] == nil ? Color.secondary : Palette.coral)
                    .frame(width: 24)
                    .accessibilityHidden(true)
                content()
                    .focused($focus, equals: field)
                    .accessibilityLabel(Text(verbatim: title))
            }
            .padding(.horizontal, 18)
            .frame(minHeight: 58)
            .glassEffect(fieldGlass(hasError: fieldErrors[field] != nil), in: .rect(cornerRadius: Metrics.smallCornerRadius))
            // ID sits on the glass-carrying view itself so the container can morph it (register field appears).
            .glassEffectID(field, in: glassNamespace)

            if let error = fieldErrors[field] {
                Text(verbatim: error)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Palette.coral)
                    .padding(.leading, 18)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.smooth, value: fieldErrors[field])
    }

    private func fieldGlass(hasError: Bool) -> Glass {
        hasError ? Glass.regular.tint(Palette.coral.opacity(0.18)).interactive() : Glass.regular.interactive()
    }

    private var submitButton: some View {
        Button {
            Task { await submit() }
        } label: {
            ZStack {
                if isSubmitting {
                    ProgressView().tint(.white)
                } else {
                    Text(verbatim: l10n.t(mode == .login ? .authLoginButton : .authRegisterButton))
                        .font(.headline)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 32)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
        .tint(Palette.coral)
        .disabled(isSubmitting)
    }

    private var modeSwitch: some View {
        HStack(spacing: 8) {
            Text(verbatim: l10n.t(mode == .login ? .authNoAccount : .authHaveAccount))
                .foregroundStyle(.secondary)
            Button {
                fieldErrors = [:]
                mode = mode == .login ? .register : .login
            } label: {
                Text(verbatim: l10n.t(mode == .login ? .authRegisterButton : .authLoginButton))
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.glass)
        }
        .font(.subheadline)
    }

    // MARK: - Actions

    private func advanceFocus() {
        switch focus {
        case .displayName: focus = .email
        case .email: focus = .password
        case .password, .none:
            focus = nil
            Task { await submit() }
        }
    }

    private func validate() -> Bool {
        var errors: [Field: String] = [:]
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)

        if mode == .register {
            if trimmedName.isEmpty {
                errors[.displayName] = l10n.t(.validationRequired)
            } else if trimmedName.count > 50 {
                errors[.displayName] = l10n.t(.validationTooLong, ["max": l10n.number(50)])
            }
        }
        if trimmedEmail.isEmpty {
            errors[.email] = l10n.t(.validationRequired)
        } else if trimmedEmail.wholeMatch(of: /[^@\s]+@[^@\s]+\.[^@\s]+/) == nil {
            errors[.email] = l10n.t(.validationEmailInvalid)
        }
        if password.isEmpty {
            errors[.password] = l10n.t(.validationRequired)
        } else if mode == .register && password.count < 8 {
            errors[.password] = l10n.t(.validationPasswordMin, ["min": l10n.number(8)])
        }
        fieldErrors = errors
        return errors.isEmpty
    }

    private func submit() async {
        guard !isSubmitting else { return }
        guard validate() else {
            failureCount += 1
            return
        }
        isSubmitting = true
        defer { isSubmitting = false }

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            switch mode {
            case .login:
                try await auth.login(email: trimmedEmail, password: password)
                // Adopt the language saved on the account, if we have it.
                if let saved = auth.user?.locale, saved != l10n.locale,
                   l10n.locales.contains(where: { $0.code == saved }) {
                    try? await l10n.switchLocale(saved)
                }
            case .register:
                try await auth.register(
                    email: trimmedEmail,
                    password: password,
                    displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
                    locale: l10n.locale
                )
            }
        } catch {
            failureCount += 1
            applyServerErrors(error)
        }
    }

    private func applyServerErrors(_ error: any Error) {
        var errors: [Field: String] = [:]
        if let apiError = error as? APIError {
            for detail in apiError.fieldDetails {
                guard let field = detail.field.flatMap(Self.field(named:)) else { continue }
                errors[field] = detail.message ?? detail.messageKey.flatMap { l10n.catalog.string(forRawKey: $0) }
            }
        }
        fieldErrors = errors
        if errors.isEmpty { errorMessage = l10n.message(for: error) }
    }

    private static func field(named name: String) -> Field? {
        switch name {
        case "email": .email
        case "password": .password
        case "displayName": .displayName
        default: nil
        }
    }
}
