import SwiftUI

struct TabsView: View {
    @Environment(Session.self) private var session
    @State private var live = Live()
    @State private var prices = PriceFeed()

    var body: some View {
        TabView {
            ChatsListView().tabItem { Label("Chats", systemImage: "bubble.left.and.bubble.right") }
            ChartsView().tabItem { Label("Charts", systemImage: "chart.xyaxis.line") }
            SoonView(title: "Plans").tabItem { Label("Plans", systemImage: "square.stack") }
            SoonView(title: "Wallet").tabItem { Label("Wallet", systemImage: "wallet.pass") }
            ProfileView().tabItem { Label("Profile", systemImage: "person") }
        }
        .environment(live)
        .environment(prices)
        .onAppear { live.start(session: session); prices.start(session: session) }
        .onDisappear { live.stop(); prices.stop() }
    }
}
