import SwiftUI

struct CreatorSignInView: View {
    @EnvironmentObject private var auth: AuthService
    @State private var email = ""
    @State private var password = ""
    @State private var showSignUp = false
    @State private var showForgotPassword = false
    @FocusState private var focused: Field?

    private enum Field { case email, password }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                formCard
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
        .sheet(isPresented: $showSignUp) {
            AuthenticatedWebBrowser(
                url: AppConfig.creatorSignUpURLForApp,
                title: "Create account",
                mode: .signUp,
                onSessionEstablished: {
                    // Browser already exported cookies + established the native session.
                    // Re-sync once, dismiss sheet — RootView switches to MainShell when authenticated.
                    showSignUp = false
                    Task {
                        if !auth.isAuthenticated {
                            _ = await auth.establishSessionFromCookies()
                        } else {
                            await auth.refreshPackageGate()
                        }
                    }
                }
            )
        }
        .sheet(isPresented: $showForgotPassword) {
            SafariView(url: AppConfig.forgotPasswordURL)
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
        }
        .padding(.top, 56)
        .padding(.bottom, 28)
    }

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Sign In")
                .font(STFont.display(24, weight: .semibold))
                .foregroundStyle(STColor.textPrimary)
            Text("Use your content creator email and password. New accounts create securely in an in-app browser (terms & registration). Creator plans and upload fees use In-App Purchase — then the app signs you into your dashboard.")
                .font(STFont.body(14))
                .foregroundStyle(STColor.textSecondary)

            field(title: "Email", text: $email, field: .email, secure: false)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .textContentType(.username)
                .autocorrectionDisabled()

            field(title: "Password", text: $password, field: .password, secure: true)
                .textContentType(.password)

            Button {
                showForgotPassword = true
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

            Button {
                Task {
                    await auth.signIn(email: email, password: password)
                }
            } label: {
                HStack {
                    if auth.isBusy { ProgressView().tint(.black) }
                    Text(auth.isBusy ? "Signing in…" : "Sign In")
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
            .disabled(auth.isBusy || email.isEmpty || password.isEmpty)
            .opacity(email.isEmpty || password.isEmpty ? 0.5 : 1)

            HStack {
                Rectangle().fill(STColor.border).frame(height: 1)
                Text("or")
                    .font(STFont.body(12))
                    .foregroundStyle(STColor.textMuted)
                Rectangle().fill(STColor.border).frame(height: 1)
            }

            Button {
                showSignUp = true
            } label: {
                Text("Create creator account")
                    .font(STFont.body(15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(STColor.primary)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(STColor.primary.opacity(0.5), lineWidth: 1.5)
                    )
            }
            .buttonStyle(.plain)

            Text("Sign up covers Films/Shows and other studio types on the web. This app opens the command center for Content Creator catalogue & production tools after your plan is active.")
                .font(STFont.body(11))
                .foregroundStyle(STColor.textMuted)
        }
        .padding(22)
        .glassPanel()
    }

    private var legalNote: some View {
        Text("Creator plan subscriptions and per-film upload fees use In-App Purchase. Marketplace and other multi-platform studio tools remain on story-time.online.")
            .font(STFont.body(11))
            .foregroundStyle(STColor.textMuted)
            .multilineTextAlignment(.center)
    }

    private func field(title: String, text: Binding<String>, field: Field, secure: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(STFont.body(13, weight: .medium))
                .foregroundStyle(STColor.textSecondary)
            Group {
                if secure {
                    SecureField(title, text: text)
                } else {
                    TextField(title, text: text)
                }
            }
            .focused($focused, equals: field)
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14).fill(STColor.surfaceElevated))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(STColor.border))
            .foregroundStyle(STColor.textPrimary)
            .submitLabel(field == .email ? .next : .go)
            .onSubmit {
                if field == .email {
                    focused = .password
                } else if !email.isEmpty && !password.isEmpty {
                    Task { await auth.signIn(email: email, password: password) }
                }
            }
        }
    }
}
