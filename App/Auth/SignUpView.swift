import SwiftUI
import JynxKit

struct SignUpView: View {
    @Environment(Session.self) private var session
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirm = ""
    @State private var fieldErrors: [String: String] = [:]
    @State private var error: String?
    @State private var busy = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Create your account").font(.open(22, .semibold)).foregroundStyle(Theme.fg).padding(.top, 24)
                Field(label: "Username", text: $username, placeholder: "Pick a username", kind: .username, error: fieldErrors["username"])
                Field(label: "Email", text: $email, placeholder: "you@example.com", kind: .email, error: fieldErrors["email"])
                Field(label: "Password", text: $password, placeholder: "At least 8 characters", kind: .newPassword, error: fieldErrors["password"])
                Field(label: "Confirm password", text: $confirm, placeholder: "Repeat your password", kind: .newPassword, error: fieldErrors["confirm"])
                if let error { Text(error).font(.open(14)).foregroundStyle(Theme.down) }
                PrimaryButton(title: "Create account", busy: busy) { Task { await submit() } }
                    .disabled(username.isEmpty || email.isEmpty || password.isEmpty || confirm.isEmpty)
            }.padding(.horizontal, 20)
        }.background(Theme.bg).navigationBarTitleDisplayMode(.inline)
    }

    private func submit() async {
        busy = true; error = nil; fieldErrors = [:]
        do { try await session.signUp(username: username, email: email, password: password, confirm: confirm) }
        catch let APIError.server(_, code, field?, message) {
            fieldErrors[field] = message ?? Copy.error(APIError.server(status: 0, code: code, field: nil, message: nil))
        } catch { self.error = Copy.error(error) }
        busy = false
    }
}
