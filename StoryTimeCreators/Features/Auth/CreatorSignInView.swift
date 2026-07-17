import SwiftUI

struct CreatorSignInView: View {
    @EnvironmentObject private var auth: AuthService
    @State private var email = ""
    @State private var password = ""
    @FocusState private var focused: Field?

    private enum Field { case email, password }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                formCard
                    .padding(.horizontal, 20)
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
            Text("Sign in with your content creator email and password to open your dashboard.")
                .font(STFont.body(14))
                .foregroundStyle(STColor.textSecondary)

            field(title: "Email", text: $email, field: .email, secure: false)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .textContentType(.username)
                .autocorrectionDisabled()

            field(title: "Password", text: $password, field: .password, secure: true)
                .textContentType(.password)

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
        }
        .padding(22)
        .glassPanel()
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
