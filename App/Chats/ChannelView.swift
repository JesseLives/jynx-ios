import SwiftUI
import JynxKit

struct ChannelView: View {
    let room: Room
    @Environment(Session.self) private var session
    @Environment(Live.self) private var live
    @State private var timeline = Timeline()
    @State private var signals: [String: Signal] = [:]
    @State private var verdict: PostVerdict = .ok
    @State private var loaded = false
    @State private var loadingOlder = false
    @State private var pinned = true
    @State private var ready = false
    @State private var error: String?
    @State private var viewing: URL?
    private let bottom = "bottom"

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    if ready && !timeline.reachedStart {
                        ProgressView().frame(maxWidth: .infinity).padding(8)
                            .onAppear { Task { await older() } }
                    }
                    if loaded && timeline.messages.isEmpty {
                        Text("No messages yet.").font(.open(15)).foregroundStyle(Theme.muted)
                            .frame(maxWidth: .infinity).padding(.top, 40)
                    }
                    let messages = timeline.messages
                    ForEach(Array(messages.enumerated()), id: \.element.id) { i, m in
                        let day = Format.day(m.createdAt)
                        if i == 0 || Format.day(messages[i - 1].createdAt) != day { DayChip(text: day) }
                        MessageRow(message: m, mine: m.author != nil && m.author?.id == session.me?.user.id,
                                   showAuthor: room.kind == .group && m.author?.id != session.me?.user.id,
                                   signal: m.signalId.flatMap { signals[$0] }, api: session.api) { viewing = $0 }
                            .id(m.id)
                    }
                    Color.clear.frame(height: 1).id(bottom)
                        .onAppear { pinned = true; Task { await markRead() } }
                        .onDisappear { pinned = false }
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
            }
            .defaultScrollAnchor(.bottom)
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.bg)
            .safeAreaInset(edge: .top, spacing: 0) { ReconnectingLine() }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if let reason = Copy.verdict(verdict) {
                    Text(reason).font(.open(13)).foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity).padding(.horizontal, 16).padding(.vertical, 14)
                        .background(Theme.card).overlay(alignment: .top) { Divider() }
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
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 10) {
                    RoomAvatar(name: room.name, small: true)
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 6) {
                            Text(room.name).font(.open(15, .bold)).foregroundStyle(Theme.fg).lineLimit(1)
                            if room.kind == .channel { VipBadge() }
                        }
                        Text(room.kind == .group ? "Group" : "Channel").font(.open(11.5)).foregroundStyle(Theme.muted)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .toolbarBackground(Theme.bg, for: .navigationBar)
        .fullScreenCover(item: $viewing) { ImageViewer(url: $0) }
    }

    private func loadSignals(_ page: [Message], refresh: Bool) async {
        let inPage = Set(page.compactMap(\.signalId))
        let running = refresh ? Set(signals.values.filter { $0.status == .running }.map(\.id)) : []
        let wanted = inPage.filter { signals[$0] == nil }.union(running)
        guard !wanted.isEmpty else { return }
        let api = session.api
        await withTaskGroup(of: Signal?.self) { group in
            for id in wanted { group.addTask { try? await api.signal(id: id) } }
            for await s in group { if let s { signals[s.id] = s } }
        }
    }

    private func latest(_ proxy: ScrollViewProxy) async {
        do {
            let page = try await session.api.messages(room: room.id)
            await loadSignals(page.messages, refresh: loaded)
            let first = !loaded
            let grew = page.messages.first?.id != timeline.newestId
            if !first && Alarm.shouldRing(shownNewest: timeline.newestId, page: page.messages) { AlarmPlayer.play() }
            timeline.applyLatest(page.messages); verdict = page.canPost; loaded = true; error = nil
            if first { proxy.scrollTo(bottom, anchor: .bottom); await Task.yield(); ready = true }
            else if grew && pinned { withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(bottom, anchor: .bottom) } }
            if pinned { await markRead() }
        } catch is CancellationError {
        } catch { session.handle(error); if !loaded { self.error = Copy.error(error) } }
    }

    private func older() async {
        guard !loadingOlder, let anchor = timeline.oldestId else { return }
        loadingOlder = true
        defer { loadingOlder = false }
        do {
            let page = try await session.api.messages(room: room.id, before: anchor)
            await loadSignals(page.messages, refresh: false)
            timeline.applyOlder(page.messages)
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
