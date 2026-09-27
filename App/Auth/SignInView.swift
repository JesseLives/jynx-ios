import SwiftUI
import JynxKit

struct SignInView: View {
    @Environment(Session.self) private var session
    @State private var login = ""
    @State private var password = ""
    @State private var error: String?
    @State private var busy = false
    @State private var signingUp = false
    @FocusState private var focus: Int?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Wordmark().frame(maxWidth: .infinity).padding(.top, 36).padding(.bottom, 12)
                    AuthHeading(title: "Welcome back", subtitle: "Sign in to see your signals.")
                    Field(label: "Username or email", text: $login, placeholder: "Enter your username or email", kind: .login,
                          focus: $focus, tag: 0) { focus = 1 }
                    Field(label: "Password", text: $password, placeholder: "Enter your password", kind: .password,
                          focus: $focus, tag: 1, submitLabel: .go) { if !login.isEmpty && !password.isEmpty { Task { await submit() } } }
                    if let error { Text(error).font(.open(14)).foregroundStyle(Theme.down) }
                    PrimaryButton(title: "Sign in", busy: busy) { Task { await submit() } }
                        .disabled(login.isEmpty || password.isEmpty).opacity(login.isEmpty || password.isEmpty ? 0.5 : 1)
                        .padding(.top, 4)
                    AuthSwitch(question: "New to Jynx?", action: "Create an account") { signingUp = true }
                }
                .padding(.horizontal, 24).padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.bg)
            .navigationDestination(isPresented: $signingUp) { SignUpView() }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func submit() async {
        busy = true; error = nil
        do { try await session.signIn(login: login, password: password) } catch { self.error = Copy.error(error) }
        busy = false
    }
}

struct AuthHeading: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.open(32, .heavy)).tracking(-1).foregroundStyle(Theme.fg)
            Text(subtitle).font(.open(16)).foregroundStyle(Theme.muted)
        }
        .padding(.bottom, 6)
    }
}

struct AuthSwitch: View {
    let question: String
    let action: String
    let tap: () -> Void
    var body: some View {
        Button(action: tap) {
            (Text(question + " ").foregroundColor(Theme.muted) + Text(action).foregroundColor(Theme.primary).fontWeight(.bold))
                .font(.open(15)).frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct Field: View {
    enum Kind { case login, email, password, newPassword, username }
    let label: String
    @Binding var text: String
    let placeholder: String
    let kind: Kind
    var error: String? = nil
    var focus: FocusState<Int?>.Binding? = nil
    var tag = 0
    var submitLabel: SubmitLabel = .next
    var onSubmit: () -> Void = {}
    @State private var shown = false

    private var secret: Bool { kind == .password || kind == .newPassword }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label).font(.open(14.5, .semibold)).foregroundStyle(Theme.fg)
            HStack(spacing: 8) {
                Group {
                    if secret && !shown { SecureField(placeholder, text: $text) } else { TextField(placeholder, text: $text) }
                }
                .font(.open(16))
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .textContentType(contentType)
                .keyboardType(kind == .email ? .emailAddress : .default)
                .submitLabel(submitLabel)
                .onSubmit(onSubmit)
                .modifier(FocusTag(focus: focus, tag: tag))
                if secret {
                    Button { shown.toggle() } label: {
                        Image(systemName: shown ? "eye.slash" : "eye").font(.system(size: 17)).foregroundStyle(Theme.muted)
                            .frame(width: 44, height: 44).contentShape(Rectangle())
                    }
                    .accessibilityLabel(shown ? "Hide password" : "Show password")
                }
            }
            .padding(.leading, 16).padding(.trailing, secret ? 4 : 16).frame(minHeight: 52)
            .background(Theme.raised, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(error == nil ? Theme.border : Theme.down))
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

private struct FocusTag: ViewModifier {
    let focus: FocusState<Int?>.Binding?
    let tag: Int
    func body(content: Content) -> some View {
        if let focus { content.focused(focus, equals: tag) } else { content }
    }
}

struct PrimaryButton: View {
    let title: String
    var busy = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            ZStack { if busy { ProgressView().tint(.white) } else { Text(title).font(.open(17, .bold)) } }
                .frame(maxWidth: .infinity).frame(minHeight: 54).contentShape(Capsule())
        }
        .foregroundStyle(.white).background(Theme.primary, in: Capsule()).disabled(busy)
    }
}
