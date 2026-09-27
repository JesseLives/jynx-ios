import SwiftUI

@main
struct JynxApp: App {
    @State private var session = Session()
    @AppStorage("appearance") private var appearance: Appearance = .light
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            Group {
                switch session.state {
                case .loading: ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity).background(Theme.bg)
                case .offline: OfflineView()
                case .signedOut: SignInView()
                case .signedIn: TabsView()
                }
            }
            .environment(session)
            .preferredColorScheme(appearance.scheme)
            .tint(Theme.primary)
            .task { await session.start() }
            .onChange(of: phase) { if phase == .active && session.state == .offline { Task { await session.refreshMe() } } }
        }
    }
}

struct OfflineView: View {
    @Environment(Session.self) private var session
    @State private var busy = false
    var body: some View {
        VStack(spacing: 14) {
            Text("Can't reach Jynx").font(.open(20, .bold)).foregroundStyle(Theme.fg)
            Text("Check your connection.").font(.open(15)).foregroundStyle(Theme.muted)
            PrimaryButton(title: "Try again", busy: busy) {
                Task { busy = true; await session.refreshMe(); busy = false }
            }.frame(maxWidth: 220)
        }
        .padding(24).frame(maxWidth: .infinity, maxHeight: .infinity).background(Theme.bg)
    }
}
