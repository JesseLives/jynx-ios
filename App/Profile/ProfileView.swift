import SwiftUI
import JynxKit

struct ProfileView: View {
    @Environment(Session.self) private var session
    @AppStorage("appearance") private var appearance: Appearance = .light
    private let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"

    var body: some View {
        NavigationStack {
            List {
                if let me = session.me {
                    Section {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(me.user.displayName).font(.open(18, .bold)).foregroundStyle(Theme.fg)
                            Text(me.user.email).font(.open(14)).foregroundStyle(Theme.muted)
                        }
                    }
                    Section("Plan") {
                        if me.subscriptions.isEmpty { Text("No active plan").font(.open(15)).foregroundStyle(Theme.muted) }
                        ForEach(me.subscriptions, id: \.productId) { s in
                            HStack {
                                Text(s.productName).font(.open(15, .semibold))
                                Spacer()
                                Text("Until \(s.endsAt.formatted(.dateTime.day().month(.abbreviated).year()))")
                                    .font(.open(14)).foregroundStyle(Theme.muted)
                            }
                        }
                    }
                }
                Section("Theme") {
                    Picker("Theme", selection: $appearance) { ForEach(Appearance.allCases) { Text($0.label).tag($0) } }
                        .pickerStyle(.segmented)
                }
                Section {
                    Button("Sign out", role: .destructive) { Task { await session.signOut() } }.font(.open(16, .semibold))
                } footer: { Text("Build \(build)").font(.open(12)) }
            }
            .navigationTitle("Profile").navigationBarTitleDisplayMode(.inline)
            .refreshable { await session.refreshMe() }
        }
    }
}
