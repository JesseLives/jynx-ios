import SwiftUI
import JynxKit

struct ChatsListView: View {
    @Environment(Session.self) private var session
    @Environment(Live.self) private var live
    @State private var rooms: [Room]?
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Group {
                if let rooms {
                    List(rooms) { room in
                        if room.locked { RoomRow(room: room) }
                        else { NavigationLink(value: room.id) { RoomRow(room: room) } }
                    }
                    .listStyle(.plain)
                    .overlay { if rooms.isEmpty { Text("No chats yet.").font(.open(15)).foregroundStyle(Theme.muted) } }
                } else if let error {
                    VStack(spacing: 12) {
                        Text(error).font(.open(15)).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
                        Button("Try again") { Task { await load() } }.font(.open(15, .semibold))
                    }.padding()
                } else { ProgressView() }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity).background(Theme.bg)
            .safeAreaInset(edge: .top, spacing: 0) { ReconnectingLine() }
            .navigationTitle("Chats").navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: String.self) { id in
                if let room = rooms?.first(where: { $0.id == id }) { ChannelView(room: room) }
            }
            .refreshable { await load() }
            .task(id: live.any) { await load() }
        }
    }

    private func load() async {
        do { rooms = try await session.api.rooms(); error = nil }
        catch { session.handle(error); if rooms == nil { self.error = Copy.error(error) } }
    }
}

struct RoomRow: View {
    let room: Room
    var body: some View {
        HStack(spacing: 12) {
            Circle().fill(Theme.primary.opacity(0.12)).frame(width: 44, height: 44)
                .overlay(Text(String(room.name.prefix(1)).uppercased()).font(.open(18, .bold)).foregroundStyle(Theme.primary))
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(room.name).font(.open(16, .semibold)).foregroundStyle(Theme.fg).lineLimit(1)
                    if room.locked { Image(systemName: "lock.fill").font(.system(size: 12)).foregroundStyle(Theme.muted) }
                    Spacer()
                    if let last = room.last { Text(Format.chatTime(last.createdAt)).font(.open(12)).foregroundStyle(Theme.muted) }
                }
                HStack {
                    Text(room.locked ? "Subscribe on the website to read" : room.last?.body ?? "No messages yet")
                        .font(.open(14)).foregroundStyle(Theme.muted).lineLimit(1)
                    Spacer()
                    if room.unread > 0 {
                        Text(room.unread >= 100 ? "99+" : "\(room.unread)").font(.open(12, .bold)).foregroundStyle(.white)
                            .padding(.horizontal, 7).frame(minWidth: 20, minHeight: 20).background(Theme.primary, in: Capsule())
                    }
                }
            }
        }.padding(.vertical, 4)
    }
}

struct ReconnectingLine: View {
    @Environment(Live.self) private var live
    var body: some View {
        if !live.connected {
            Text("Reconnecting").font(.open(12, .semibold)).foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity).padding(.vertical, 4).background(Theme.card)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

struct ChannelView: View { let room: Room; var body: some View { Text(room.name) } }
