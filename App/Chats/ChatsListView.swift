import SwiftUI
import JynxKit

struct ChatsListView: View {
    @Environment(Session.self) private var session
    @Environment(Live.self) private var live
    @State private var rooms: [Room]?
    @State private var error: String?
    @State private var query = ""
    @State private var path: [String] = []

    private var shown: [Room] {
        let q = query.trimmingCharacters(in: .whitespaces)
        return (rooms ?? []).filter { q.isEmpty || $0.name.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                VStack(spacing: 14) { PageTitle(text: "Chats"); SearchPill(text: $query) }
                    .listRowSeparator(.hidden).listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))
                if rooms != nil {
                    ForEach(shown) { room in
                        Button { if !room.locked { path.append(room.id) } } label: { RoomRow(room: room) }
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                            .alignmentGuide(.listRowSeparatorLeading) { _ in 62 }
                    }
                    if shown.isEmpty {
                        Text(query.isEmpty ? "No chats yet." : "No chats match.").font(.open(15)).foregroundStyle(Theme.muted)
                            .frame(maxWidth: .infinity).padding(.top, 30).listRowSeparator(.hidden)
                    }
                } else if let error {
                    VStack(spacing: 12) {
                        Text(error).font(.open(15)).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
                        Button("Try again") { Task { await load() } }.font(.open(15, .semibold))
                    }.frame(maxWidth: .infinity).padding(.top, 30).listRowSeparator(.hidden)
                } else {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 30).listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain).scrollContentBackground(.hidden).background(Theme.bg)
            .safeAreaInset(edge: .top, spacing: 0) { ReconnectingLine() }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: String.self) { id in
                if let room = rooms?.first(where: { $0.id == id }) { ChannelView(room: room) }
            }
            .refreshable { await load() }
            .task(id: live.any) { await load() }
        }
    }

    private func load() async {
        do { rooms = try await session.api.rooms(); error = nil }
        catch is CancellationError {
        } catch { session.handle(error); if rooms == nil { self.error = Copy.error(error) } }
    }
}

struct SearchPill: View {
    @Binding var text: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.muted)
            TextField("Search", text: $text).font(.open(16)).textInputAutocapitalization(.never).autocorrectionDisabled()
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.muted).frame(width: 44, height: 44)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14).frame(height: 42)
        .background(Theme.card, in: Capsule())
    }
}

struct RoomRow: View {
    let room: Room
    var body: some View {
        HStack(spacing: 12) {
            RoomAvatar(name: room.name)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(room.name).font(.open(16, .bold)).foregroundStyle(Theme.fg).lineLimit(1)
                    if room.kind == .channel { VipBadge() }
                    if room.locked { Image(systemName: "lock.fill").font(.system(size: 11)).foregroundStyle(Theme.muted) }
                    Spacer(minLength: 8)
                    if let last = room.last {
                        Text(Format.chatTime(last.createdAt)).font(.open(12)).foregroundStyle(Theme.muted)
                    }
                }
                HStack(spacing: 8) {
                    Text(room.locked ? "Subscribe on the website to read" : room.last?.body ?? "No messages yet")
                        .font(.open(14)).foregroundStyle(Theme.muted).lineLimit(1)
                    Spacer(minLength: 8)
                    if room.unread > 0 {
                        Text(room.unread >= 100 ? "99+" : "\(room.unread)").font(.open(11, .bold)).foregroundStyle(.white)
                            .padding(.horizontal, 6).frame(minWidth: 20, minHeight: 20).background(Theme.primary, in: Capsule())
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .opacity(room.locked ? 0.7 : 1)
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
