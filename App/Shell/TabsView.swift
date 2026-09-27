import SwiftUI

struct TabsView: View {
    @Environment(Session.self) private var session
    @State private var live = Live()

    var body: some View {
        TabView {
            ChatsListView().tabItem { Label("Chats", systemImage: "bubble.left.and.bubble.right") }
            SoonView(title: "Charts").tabItem { Label("Charts", systemImage: "chart.xyaxis.line") }
            SoonView(title: "Plans").tabItem { Label("Plans", systemImage: "square.stack") }
            SoonView(title: "Wallet").tabItem { Label("Wallet", systemImage: "wallet.pass") }
            SoonView(title: "Copier").tabItem { Label("Copier", systemImage: "power") }
            ProfileView().tabItem { Label("Profile", systemImage: "person") }
        }
        .environment(live)
        .onAppear { live.start(session: session) }
        .onDisappear { live.stop() }
    }
}
