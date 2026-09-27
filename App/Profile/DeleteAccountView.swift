import SwiftUI
import JynxKit

struct DeleteAccountView: View {
    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var password = ""
    @State private var busy = false
    @State private var error: String?
    @State private var confirming = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Delete your account").font(.open(24, .heavy)).foregroundStyle(Theme.fg)
                    VStack(alignment: .leading, spacing: 10) {
                        point("Your email, username, name and password are erased, and you are signed out everywhere.")
                        point("Plans you paid for end with the account. Money left in your wallet cannot be withdrawn afterwards.")
                        point("Payment and wallet records stay for accounting. Your old group messages show as Deleted member.")
                        point("This cannot be undone. You can sign up again later with the same email.")
                    }
                    Field(label: "Password", text: $password, placeholder: "Enter your password", kind: .password,
                          submitLabel: .done) { if !password.isEmpty { confirming = true } }
                    if let error { Text(error).font(.open(14)).foregroundStyle(Theme.down) }
                    Button { confirming = true } label: {
                        ZStack { if busy { ProgressView().tint(.white) } else { Text("Delete my account").font(.open(16, .bold)) } }
                            .foregroundStyle(.white).frame(maxWidth: .infinity).frame(minHeight: 50)
                            .background(Theme.down, in: Capsule())
                    }
                    .disabled(password.isEmpty || busy).opacity(password.isEmpty ? 0.5 : 1)
                }
                .padding(20)
            }
            .background(Theme.bg)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .confirmationDialog("Delete your account for good?", isPresented: $confirming, titleVisibility: .visible) {
                Button("Delete my account", role: .destructive) { Task { await delete() } }
            }
        }
    }

    private func point(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle().fill(Theme.muted).frame(width: 5, height: 5).padding(.top, 8)
            Text(text).font(.open(15)).foregroundStyle(Theme.muted)
        }
    }

    private func delete() async {
        busy = true; error = nil
        do {
            try await session.api.deleteAccount(password: password)
            password = ""
            await session.signOut()
        } catch { session.handle(error); self.error = Copy.error(error) }
        busy = false
    }
}
