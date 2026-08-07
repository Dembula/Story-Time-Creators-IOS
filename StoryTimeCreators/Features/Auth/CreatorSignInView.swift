import SwiftUI
import UIKit

/// Native Sign In / Sign Up — same flow as Story Time Universe (no web account window).
/// After signup: credentials session → MainShell → StoreKit plan picker when package is incomplete.
struct CreatorSignInView: View {
    @EnvironmentObject private var auth: AuthService
    @State private var mode: Mode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var showPassword = false
    @State private var acceptedTerms = false
    @State private var browser: BrowserSheet?
    @FocusState private var focused: Field?

    private enum Field { case name, email, password }
    private enum Mode: String { case signIn, signUp }

    private struct BrowserSheet: Identifiable {
        let id = UUID()
        let url: URL
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                modeTabs
                    .padding(.horizontal, 28)
                    .padding(.bottom, 18)

                Group {
                    if mode == .signIn {
                        signInForm
                    } else {
                        signUpForm
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)

                legalNote
                    .padding(.horizontal, 28)
                    .padding(.bottom, 40)
            }
        }
        .background(
            ZStack {
                STColor.background
                RadialGradient(
                    colors: [STColor.primary.opacity(0.22), .clear],
                    center: .top,
                    startRadius: 20,
                    endRadius: 420
                )
            }
            .ignoresSafeArea()
        )
        .scrollDismissesKeyboard(.interactively)
        .sheet(item: $browser) { item in
            SafariView(url: item.url)
                .ignoresSafeArea()
        }
    }

    private var header: some View {
        VStack(spacing: 14) {
            Image("SplashLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: STColor.primary.opacity(0.45), radius: 18, y: 8)

            HStack(spacing: 8) {
                Text("STORY")
                    .foregroundStyle(STColor.textPrimary)
                Text("TIME")
                    .foregroundStyle(STColor.brandGradient)
            }
            .font(STFont.display(26, weight: .bold))
            .tracking(3)

            Text("Content Creators")
                .font(STFont.body(13, weight: .semibold))
                .foregroundStyle(STColor.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(STColor.primary.opacity(0.15)))

            Text(mode == .signIn ? "Sign in to your studio" : "Create your account")
                .font(STFont.body(14))
                .foregroundStyle(STColor.textSecondary)
        }
        .padding(.top, 56)
        .padding(.bottom, 22)
    }

    private var modeTabs: some View {
        HStack(spacing: 0) {
            modeTab(.signIn, title: "Sign In")
            modeTab(.signUp, title: "Sign Up")
        }
        .background(Color.white.opacity(0.08))
        .clipShape(Capsule())
    }

    private func modeTab(_ value: Mode, title: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                mode = value
                auth.lastError = nil
            }
        } label: {
            Text(title)
                .font(STFont.body(14, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(mode == value ? STColor.primary : Color.clear)
                .foregroundStyle(mode == value ? .black : STColor.textMuted)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sign In

    private var signInForm: some View {
        VStack(alignment: .leading, spacing: 18) {
            labeledField("Email") {
                TextField("Email", text: $email)
                    .textContentType(.username)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focused, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { focused = .password }
            }

            labeledField("Password") {
                passwordRow(placeholder: "Password", contentType: .password)
            }

            Button {
                browser = BrowserSheet(url: AppConfig.forgotPasswordURL)
            } label: {
                Text("Forgot password?")
                    .font(STFont.body(13, weight: .semibold))
                    .foregroundStyle(STColor.primary)
            }
            .buttonStyle(.plain)

            if let error = auth.lastError {
                Text(error)
                    .font(STFont.body(13))
                    .foregroundStyle(STColor.danger)
            }

            primaryButton(title: auth.isBusy ? "Signing in…" : "Sign In", enabled: !email.isEmpty && !password.isEmpty) {
                focused = nil
                Task { await auth.signIn(email: email, password: password) }
            }
        }
        .padding(22)
        .glassPanel()
    }

    // MARK: - Sign Up

    private var signUpForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Create your account here, then choose a plan with Apple In‑App Purchase. Payment never leaves the App Store.")
                .font(STFont.body(13))
                .foregroundStyle(STColor.textSecondary)
                .multilineTextAlignment(.leading)

            labeledField("Name (optional)") {
                TextField("Name (optional)", text: $name)
                    .textContentType(.name)
                    .focused($focused, equals: .name)
            }

            labeledField("Email") {
                TextField("Email", text: $email)
                    .textContentType(.username)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focused, equals: .email)
            }

            labeledField("Password") {
                passwordRow(placeholder: "Password (min 8 characters)", contentType: .newPassword)
            }

            Toggle(isOn: $acceptedTerms) {
                HStack(spacing: 4) {
                    Text("I agree to the")
                        .foregroundStyle(STColor.textMuted)
                    Button("Terms of Use") {
                        browser = BrowserSheet(url: AppConfig.termsOfUseURL)
                    }
                    .foregroundStyle(STColor.primary)
                    Text("and")
                        .foregroundStyle(STColor.textMuted)
                    Button("Privacy") {
                        browser = BrowserSheet(url: AppConfig.privacyPolicyURL)
                    }
                    .foregroundStyle(STColor.primary)
                }
                .font(STFont.body(12))
            }
            .toggleStyle(SwitchToggleStyle(tint: STColor.primary))

            if let error = auth.lastError {
                Text(error)
                    .font(STFont.body(13))
                    .foregroundStyle(STColor.danger)
            }

            primaryButton(
                title: auth.isBusy ? "Creating…" : "Create Account",
                enabled: canSubmitSignUp
            ) {
                focused = nil
                Task {
                    await auth.signUp(
                        email: email,
                        password: password,
                        name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : name
                    )
                }
            }

            Text("After your account is created you’ll pick a plan via Apple. Subscriptions are managed in Settings → Apple ID → Subscriptions.")
                .font(STFont.body(11))
                .foregroundStyle(STColor.textMuted)
        }
        .padding(22)
        .glassPanel()
    }

    private var canSubmitSignUp: Bool {
        acceptedTerms
            && !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && password.count >= 8
    }

    private var legalNote: some View {
        Text("Creator plan subscriptions and per-film upload fees use In-App Purchase. Multi-type studio registration (music, crew, locations) remains on story-time.online.")
            .font(STFont.body(11))
            .foregroundStyle(STColor.textMuted)
            .multilineTextAlignment(.center)
    }

    // MARK: - Shared

    private func primaryButton(title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                if auth.isBusy { ProgressView().tint(.black) }
                Text(title)
                    .font(STFont.body(16, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(.black)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(STColor.brandGradient)
            )
        }
        .disabled(!enabled || auth.isBusy)
        .opacity(enabled && !auth.isBusy ? 1 : 0.5)
    }

    private func labeledField<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(STFont.body(13, weight: .medium))
                .foregroundStyle(STColor.textSecondary)
            content()
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 14).fill(STColor.surfaceElevated))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(STColor.border))
                .foregroundStyle(STColor.textPrimary)
        }
    }

    private func passwordRow(placeholder: String, contentType: UITextContentType) -> some View {
        HStack {
            Group {
                if showPassword {
                    TextField(placeholder, text: $password)
                } else {
                    SecureField(placeholder, text: $password)
                }
            }
            .textContentType(contentType)
            .focused($focused, equals: .password)

            Button { showPassword.toggle() } label: {
                Image(systemName: showPassword ? "eye.slash" : "eye")
                    .foregroundStyle(STColor.textMuted)
            }
        }
    }
}
