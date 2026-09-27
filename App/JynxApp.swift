import SwiftUI

@main
struct JynxApp: App {
    @State private var session = Session()
    @AppStorage("appearance") private var appearance: Appearance = .light

    var body: some Scene {
        WindowGroup {
            Group {
                switch session.state {
                case .loading: ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity).background(Theme.bg)
                case .signedOut: SignInView()
                case .signedIn: TabsView()
                }
            }
            .environment(session)
            .preferredColorScheme(appearance.scheme)
            .tint(Theme.primary)
            .task { await session.start() }
        }
    }
}

struct TabsView: View { var body: some View { Text("Signed in") } }
