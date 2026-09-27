import SwiftUI
import JynxKit

struct InviteView: View {
    let wallet: WalletOverview
    let changed: () async -> Void
    @Environment(Session.self) private var session
    @State private var code = ""
    @State private var saving = false
    @State private var error: String?

    private var link: String { "https://signals.justsal.xyz/invite/\(wallet.inviteCode)" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Share your link. When someone you invite pays for a plan, you earn a share, and a smaller share from the people they invite.")
                    .font(.open(15)).foregroundStyle(Theme.muted)
                CardGroup {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(link).font(.open(15, .semibold)).foregroundStyle(Theme.fg).textSelection(.enabled).lineLimit(2)
                        HStack(spacing: 10) {
                            Button { UIPasteboard.general.string = link } label: { Label("Copy", systemImage: "doc.on.doc").frame(maxWidth: .infinity) }
                                .font(.open(15, .bold)).foregroundStyle(Theme.primary).frame(height: 44).background(Theme.primarySoft, in: Capsule())
                            ShareLink(item: URL(string: link)!) { Label("Share", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }
                                .font(.open(15, .bold)).foregroundStyle(.white).frame(height: 44).background(Theme.primary, in: Capsule())
                        }
                    }.padding(16)
                }
                VStack(alignment: .leading, spacing: 8) {
                    StepLabel("Your code")
                    HStack(spacing: 10) {
                        TextField("code", text: $code).font(.open(16)).textInputAutocapitalization(.never).autocorrectionDisabled()
                            .padding(.horizontal, 14).frame(minHeight: 48)
                            .background(Theme.raised, in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border))
                        Button(saving ? "Saving" : "Save") { Task { await save() } }
                            .font(.open(15, .bold)).foregroundStyle(.white).padding(.horizontal, 18).frame(minHeight: 48)
                            .background(Theme.primary, in: Capsule()).disabled(saving || code == wallet.inviteCode || code.isEmpty)
                    }
                    Text(error ?? "3 to 20 letters, numbers, - or _").font(.open(13)).foregroundStyle(error == nil ? Theme.muted : Theme.down)
                }
                CardGroup {
                    ForEach(0..<3, id: \.self) { i in
                        if i > 0 { Divider().padding(.leading, 16) }
                        HStack {
                            Text("Level \(i + 1)").font(.open(15, .bold)).foregroundStyle(Theme.fg)
                            Text(i < wallet.rates.count ? "\(wallet.rates[i].formatted())%" : "").font(.open(14)).foregroundStyle(Theme.muted)
                            Spacer()
                            let n = i < wallet.counts.count ? wallet.counts[i] : 0
                            Text("\(n) \(n == 1 ? "person" : "people")").font(.open(15, .semibold)).foregroundStyle(Theme.fg)
                        }.padding(.horizontal, 16).padding(.vertical, 14)
                    }
                }
                HStack {
                    Text("Earned so far").font(.open(15, .semibold)).foregroundStyle(Theme.muted)
                    Spacer()
                    Text(Money.dollars(wallet.earnedCents)).font(.open(18, .heavy)).foregroundStyle(Theme.up).monospacedDigit()
                }.padding(.horizontal, 4)
            }
            .padding(16)
        }
        .background(Theme.bg)
        .navigationTitle("Invite").navigationBarTitleDisplayMode(.large)
        .onAppear { code = wallet.inviteCode }
    }

    private func save() async {
        saving = true; error = nil
        do { try await session.api.setInviteCode(code.trimmingCharacters(in: .whitespaces)); await changed() }
        catch { session.handle(error); self.error = Copy.error(error) }
        saving = false
    }
}
