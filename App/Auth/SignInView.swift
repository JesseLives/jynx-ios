import SwiftUI
import JynxKit

struct SignInView: View {
    @Environment(Session.self) private var session
    @State private var login = ""
    @State private var password = ""
    @State private var error: String?
    @State private var busy = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Jynx").font(.open(34, .bold)).foregroundStyle(Theme.fg).padding(.top, 48)
                    Text("Sign in").font(.open(22, .semibold)).foregroundStyle(Theme.fg)
                    Field(label: "Username or email", text: $login, placeholder: "Enter your username or email", kind: .login)
                    Field(label: "Password", text: $password, placeholder: "Enter your password", kind: .password)
                    if let error { Text(error).font(.open(14)).foregroundStyle(Theme.down) }
                    PrimaryButton(title: "Sign in", busy: busy) { Task { await submit() } }
                        .disabled(login.isEmpty || password.isEmpty)
                    NavigationLink("Create an account") { SignUpView() }
                        .font(.open(15, .semibold)).foregroundStyle(Theme.primary).frame(maxWidth: .infinity)
                }.padding(.horizontal, 20)
            }.background(Theme.bg)
        }
    }

    private func submit() async {
        busy = true; error = nil
        do { try await session.signIn(login: login, password: password) } catch { self.error = Copy.error(error) }
        busy = false
    }
}

struct Field: View {
    enum Kind { case login, email, password, newPassword, username }
    let label: String
    @Binding var text: String
    let placeholder: String
    let kind: Kind
    var error: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.open(14, .semibold)).foregroundStyle(Theme.fg)
            Group {
                if kind == .password || kind == .newPassword { SecureField(placeholder, text: $text) }
                else { TextField(placeholder, text: $text) }
            }
            .font(.open(16)).padding(.horizontal, 14).frame(height: 48)
            .background(Theme.raised, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(error == nil ? Theme.border : Theme.down))
            .textInputAutocapitalization(.never).autocorrectionDisabled()
            .textContentType(contentType)
            .keyboardType(kind == .email ? .emailAddress : .default)
            if let error { Text(error).font(.open(13)).foregroundStyle(Theme.down) }
        }
    }

    private var contentType: UITextContentType {
        switch kind {
        case .password: .password
        case .newPassword: .newPassword
        case .email: .emailAddress
        case .login, .username: .username
        }
    }
}

struct PrimaryButton: View {
    let title: String
    var busy = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            ZStack { if busy { ProgressView().tint(.white) } else { Text(title).font(.open(16, .bold)) } }
                .frame(maxWidth: .infinity).frame(height: 50)
        }
        .foregroundStyle(.white).background(Theme.primary, in: Capsule()).disabled(busy)
    }
}
