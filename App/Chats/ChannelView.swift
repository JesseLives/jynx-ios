import SwiftUI
import JynxKit

struct ChannelView: View {
    let room: Room
    @Environment(Session.self) private var session
    @Environment(Live.self) private var live
    @State private var timeline = Timeline()
    @State private var verdict: PostVerdict = .ok
    @State private var loaded = false
    @State private var loadingOlder = false
    @State private var pinned = true
    @State private var error: String?
    @State private var viewing: URL?
    private let bottom = "bottom"

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if loaded && !timeline.reachedStart {
                        ProgressView().frame(maxWidth: .infinity).padding(8)
                            .onAppear { Task { await older(proxy) } }
                    }
                    if loaded && timeline.messages.isEmpty {
                        Text("No messages yet.").font(.open(15)).foregroundStyle(Theme.muted)
                            .frame(maxWidth: .infinity).padding(.top, 40)
                    }
                    ForEach(timeline.messages) { m in
                        MessageRow(message: m, roomVersion: live.version(of: room.id),
                                   mediaURL: session.api.mediaURL(messageId: m.id)) { viewing = $0 }
                            .id(m.id)
                    }
                    Color.clear.frame(height: 1).id(bottom)
                        .onAppear { pinned = true; Task { await markRead() } }
                        .onDisappear { pinned = false }
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
            }
            .background(Theme.bg)
            .safeAreaInset(edge: .top, spacing: 0) { ReconnectingLine() }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if let reason = Copy.verdict(verdict) {
                    Text(reason).font(.open(14)).foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity).padding(12).background(Theme.card)
                } else if loaded {
                    Composer { text in try await send(text, proxy) }
                }
            }
            .overlay {
                if !loaded {
                    if let error { Text(error).font(.open(15)).foregroundStyle(Theme.muted).padding() } else { ProgressView() }
                }
            }
            .task(id: live.version(of: room.id)) { await latest(proxy) }
        }
        .navigationTitle(room.name).navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $viewing) { ImageViewer(url: $0) }
    }

    private func latest(_ proxy: ScrollViewProxy) async {
        do {
            let page = try await session.api.messages(room: room.id)
            let first = !loaded
            let grew = page.messages.first?.id != timeline.newestId
            timeline.applyLatest(page.messages); verdict = page.canPost; loaded = true; error = nil
            if first { try? await Task.sleep(for: .milliseconds(30)); proxy.scrollTo(bottom, anchor: .bottom) }
            else if grew && pinned { withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(bottom, anchor: .bottom) } }
            if pinned { await markRead() }
        } catch { session.handle(error); if !loaded { self.error = Copy.error(error) } }
    }

    private func older(_ proxy: ScrollViewProxy) async {
        guard !loadingOlder, let anchor = timeline.oldestId else { return }
        loadingOlder = true
        defer { loadingOlder = false }
        do {
            let page = try await session.api.messages(room: room.id, before: anchor)
            timeline.applyOlder(page.messages)
            proxy.scrollTo(anchor, anchor: .top)
        } catch { session.handle(error) }
    }

    private func send(_ text: String, _ proxy: ScrollViewProxy) async throws {
        do { try await session.api.send(room: room.id, body: text); pinned = true; await latest(proxy) }
        catch let APIError.server(_, code, _, _) where ["read_only", "muted", "banned"].contains(code) {
            await latest(proxy); throw APIError.server(status: 403, code: code, field: nil, message: nil)
        }
    }

    private func markRead() async {
        guard let id = timeline.newestId else { return }
        try? await session.api.markRead(room: room.id, messageId: id)
    }
}

extension URL: @retroactive Identifiable { public var id: String { absoluteString } }
