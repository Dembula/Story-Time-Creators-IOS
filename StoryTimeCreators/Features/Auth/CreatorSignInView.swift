import SwiftUI
import AuthenticationServices

struct CreatorSignInView: View {
    @EnvironmentObject private var auth: AuthService
    @State private var email = ""
    @State private var password = ""
    @State private var selectedRole = AppConfig.creatorRole
    @FocusState private var focused: Field?

    private enum Field { case email, password }

    private let roles: [(String, String)] = [
        ("CONTENT_CREATOR", "Content Creator"),
        ("MUSIC_CREATOR", "Music Creator"),
        ("EQUIPMENT_COMPANY", "Equipment Company"),
        ("LOCATION_OWNER", "Location Owner"),
        ("CREW_TEAM", "Crew Team"),
        ("CASTING_AGENCY", "Casting Agency"),
        ("CATERING_COMPANY", "Catering Company"),
        ("FUNDER", "Funder / Investor"),
    ]

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

            Text("Creator Portal")
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
            Text("Creator Sign In")
                .font(STFont.display(24, weight: .semibold))
                .foregroundStyle(STColor.textPrimary)
            Text("Access your dashboard, tools, network, and virtual assistant.")
                .font(STFont.body(14))
                .foregroundStyle(STColor.textSecondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Account type")
                    .font(STFont.body(13, weight: .medium))
                    .foregroundStyle(STColor.textSecondary)
                Picker("Account type", selection: $selectedRole) {
                    ForEach(roles, id: \.0) { role in
                        Text(role.1).tag(role.0)
                    }
                }
                .pickerStyle(.menu)
                .tint(STColor.primary)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 14).fill(STColor.surfaceElevated))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(STColor.border))
            }

            field(title: "Email", text: $email, field: .email, secure: false)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .textContentType(.username)

            field(title: "Password", text: $password, field: .password, secure: true)
                .textContentType(.password)

            if let error = auth.lastError {
                Text(error)
                    .font(STFont.body(13))
                    .foregroundStyle(STColor.danger)
            }

            Button {
                Task {
                    await auth.signIn(email: email, password: password, selectedRole: selectedRole)
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

            divider

            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                switch result {
                case .success(let authResult):
                    guard let credential = authResult.credential as? ASAuthorizationAppleIDCredential else {
                        auth.signInWithApple()
                        return
                    }
                    let token = credential.identityToken.flatMap { String(data: $0, encoding: .utf8) }
                    Task {
                        await auth.completeNativeApple(
                            identityToken: token,
                            email: credential.email,
                            fullName: credential.fullName
                        )
                    }
                case .failure:
                    auth.signInWithApple()
                }
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            HStack(spacing: 10) {
                oauthButton(title: "Google", action: auth.signInWithGoogle)
                oauthButton(title: "GitHub", action: auth.signInWithGitHub)
            }
        }
        .padding(22)
        .glassPanel()
    }

    private var divider: some View {
        HStack {
            Rectangle().fill(STColor.border).frame(height: 1)
            Text("Or continue with")
                .font(STFont.body(12))
                .foregroundStyle(STColor.textMuted)
            Rectangle().fill(STColor.border).frame(height: 1)
        }
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
        }
    }

    private func oauthButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(STFont.body(14, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundStyle(STColor.textPrimary)
                .background(RoundedRectangle(cornerRadius: 14).fill(STColor.surfaceElevated))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(STColor.border))
        }
    }
}
