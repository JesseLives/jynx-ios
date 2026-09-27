import SwiftUI

struct TabsView: View {
    @Environment(Session.self) private var session
    @State private var live = Live()
    @State private var prices = PriceFeed()
    @State private var storeListener: Task<Void, Never>?

    var body: some View {
        TabView {
            ChatsListView().tabItem { Label("Chats", systemImage: "bubble.left.and.bubble.right") }
            ChartsView().tabItem { Label("Charts", systemImage: "chart.xyaxis.line") }
            PlansView().tabItem { Label("Plans", systemImage: "square.stack") }
            CommunityView().tabItem { Label("Community", systemImage: "person.2") }
            ProfileView().tabItem { Label("Profile", systemImage: "person") }
        }
        .environment(live)
        .environment(prices)
        .onAppear {
            live.start(session: session); prices.start(session: session)
            if Features.store && storeListener == nil { storeListener = AppleStore.listen(api: session.api) { await session.refreshMe() } }
        }
        .onDisappear { live.stop(); prices.stop(); storeListener?.cancel(); storeListener = nil }
    }
}
