import SwiftUI
import JynxKit

struct CommunityView: View {
    @Environment(Session.self) private var session
    @State private var community: Community?
    @State private var error: String?
    @State private var open: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    PageTitle(text: "Community")
                    if let community { sections(community) }
                    else if let error {
                        VStack(spacing: 12) {
                            Text(error).font(.open(15)).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
                            Button("Try again") { Task { await load() } }.font(.open(15, .semibold)).frame(minHeight: 44)
                        }.frame(maxWidth: .infinity).padding(.top, 40)
                    } else { ProgressView().frame(maxWidth: .infinity).padding(.top, 40) }
                }
                .padding(.horizontal, 16).padding(.bottom, 24)
            }
            .background(Theme.bg)
            .refreshable { await load() }
            .toolbar(.hidden, for: .navigationBar)
            .task { if community == nil { await load() } }
        }
    }

    private func load() async {
        do { community = try await session.api.community(); error = nil }
        catch { session.handle(error); if community == nil { self.error = Copy.error(error) } }
    }

    @ViewBuilder private func sections(_ c: Community) -> some View {
        if let channel = c.channelURL {
            header("Our Channel")
            CardGroup { LinkRow(url: channel, tile: IconTile(brand: "telegram"), title: "Jynx Results", subtitle: "Every result we post, on Telegram") }
        }

        header("Contact us")
        CardGroup {
            if let mail = c.emailURL { LinkRow(url: mail, tile: IconTile(symbol: "envelope"), title: "Email", subtitle: c.email); Divider().padding(.leading, 68) }
            if let tg = c.telegramURL { LinkRow(url: tg, tile: IconTile(brand: "telegram"), title: "Telegram", subtitle: tg.host() == "t.me" ? "@" + tg.lastPathComponent : nil); Divider().padding(.leading, 68) }
            LinkRow(url: Community.website, tile: IconTile(symbol: "globe"), title: "Website", subtitle: "signals.justsal.xyz/contact")
        }

        if !c.socials.isEmpty {
            header("Connect with us")
            CardGroup {
                ForEach(Array(c.socials.enumerated()), id: \.offset) { i, s in
                    if i > 0 { Divider().padding(.leading, 68) }
                    LinkRow(url: s.1, tile: IconTile(brand: s.0.rawValue), title: name(s.0), subtitle: nil)
                }
            }
        }

        header("FAQ")
        CardGroup {
            ForEach(Array(c.faq.enumerated()), id: \.element.id) { i, f in
                if i > 0 { Divider().padding(.leading, 14) }
                question(f)
            }
        }
    }

    private func header(_ text: String) -> some View {
        Text(text).font(.open(15, .bold)).foregroundStyle(Theme.muted).padding(.top, 12).padding(.leading, 4)
            .accessibilityAddTraits(.isHeader)
    }

    private func question(_ f: Community.Question) -> some View {
        let shown = open == f.id
        return Button { withAnimation(.snappy(duration: 0.2)) { open = shown ? nil : f.id } } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(f.q).font(.open(16, .bold)).foregroundStyle(Theme.fg).multilineTextAlignment(.leading)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.down").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.muted)
                        .rotationEffect(.degrees(shown ? 180 : 0))
                }
                if shown { Text(f.a).font(.open(15)).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true) }
            }
            .padding(.horizontal, 14).padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(shown ? "Hides the answer" : "Shows the answer")
    }

    private func name(_ s: Community.Social) -> String {
        switch s { case .youtube: "YouTube"; case .instagram: "Instagram"; case .facebook: "Facebook"; case .x: "X" }
    }
}

private struct LinkRow: View {
    let url: URL
    let tile: IconTile
    let title: String
    let subtitle: String?
    var body: some View {
        Link(destination: url) {
            HStack(spacing: 14) {
                tile
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.open(16, .bold)).foregroundStyle(Theme.fg)
                    if let subtitle { Text(subtitle).font(.open(13.5)).foregroundStyle(Theme.muted).lineLimit(1) }
                }
                Spacer(minLength: 8)
                Image(systemName: "arrow.up.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.muted)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
