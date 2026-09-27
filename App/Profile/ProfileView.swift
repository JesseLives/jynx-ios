import SwiftUI
import JynxKit

struct ProfileView: View {
    @Environment(Session.self) private var session
    @AppStorage("appearance") private var appearance: Appearance = .light
    @State private var confirmLogout = false
    @State private var deleting = false
    @State private var copier: CopierState?
    @State private var extending: String?
    @State private var renewing: Set<String> = []
    @State private var renewError: String?
    @AppStorage("alarm") private var alarm: Alarm.Sound = .alarm
    private let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let me = session.me {
                        header(me); plans(me)
                        if let renewError { Text(renewError).font(.open(14)).foregroundStyle(Theme.down) }
                        if Features.copier && me.copierEnabled != false {
                            CardGroup {
                                NavigationLink { CopierView(pushed: true) } label: { copierRow(chevron: true) }.buttonStyle(.plain)
                            }
                        } else if copier?.account != nil { CardGroup { copierRow(chevron: false) } }
                        CardGroup {
                            NavigationLink { WalletView() } label: {
                                Row(symbol: "wallet.pass", title: "Wallet") {
                                    HStack(spacing: 8) {
                                        Text(Money.dollars(me.wallet.balance)).font(.open(15)).foregroundStyle(Theme.muted).monospacedDigit()
                                        Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.muted)
                                    }
                                }
                            }.buttonStyle(.plain)
                            Divider().padding(.leading, 68)
                            NavigationLink { PaymentsView() } label: {
                                Row(symbol: "creditcard", title: "Payments") {
                                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.muted)
                                }
                            }.buttonStyle(.plain)
                        }
                    }
                    CardGroup {
                        Menu {
                            Picker("Alarm Sound", selection: $alarm) { ForEach(Alarm.Sound.allCases) { Text($0.label).tag($0) } }
                        } label: {
                            Row(symbol: "speaker.wave.2", title: "Alarm Sound") { MenuValue(text: alarm.label) }
                        }
                        .buttonStyle(.plain)
                        Divider().padding(.leading, 68)
                        Menu {
                            Picker("Appearance", selection: $appearance) { ForEach(Appearance.allCases) { Text($0.label).tag($0) } }
                        } label: {
                            Row(symbol: "circle.lefthalf.filled", title: "Appearance") { MenuValue(text: appearance.label) }
                        }
                        .buttonStyle(.plain)
                    }
                    Button { confirmLogout = true } label: {
                        Text("Log out").font(.open(17, .bold)).foregroundStyle(Theme.down)
                            .frame(maxWidth: .infinity).frame(height: 56)
                    }
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 22))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.borderSoft))
                    Button("Delete account") { deleting = true }
                        .font(.open(14, .semibold)).foregroundStyle(Theme.muted).frame(minHeight: 44)
                    Text("Build \(build)").font(.open(12)).foregroundStyle(Theme.muted)
                }
                .padding(.horizontal, 16).padding(.top, 20).padding(.bottom, 24)
            }
            .background(Theme.bg)
            .refreshable { await session.refreshMe() }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: Binding(get: { extending.map(Extend.init) }, set: { extending = $0?.id })) { e in PlansView(preselect: e.id, closable: true) }
            .sheet(isPresented: $deleting) { DeleteAccountView() }
            .task { copier = try? await session.api.copier() }
            .onChange(of: alarm) { AlarmPlayer.play(alarm) }   // hear the choice
            .confirmationDialog("Log out of Jynx?", isPresented: $confirmLogout, titleVisibility: .visible) {
                Button("Log out", role: .destructive) { Task { await session.signOut() } }
            }
        }
    }

    private func header(_ me: Me) -> some View {
        VStack(spacing: 6) {
            Circle().fill(Theme.primary).frame(width: 84, height: 84)
                .overlay(Text(String(me.user.displayName.prefix(1)).uppercased()).font(.open(36, .heavy)).foregroundStyle(.white))
                .padding(.bottom, 6)
            Text(me.user.displayName).font(.open(24, .heavy)).foregroundStyle(Theme.fg)
            Text(me.user.email).font(.open(15)).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity).padding(.bottom, 8)
    }

    private func plans(_ me: Me) -> some View {
        CardGroup {
            if me.subscriptions.isEmpty {
                Row(symbol: "square.stack.3d.up", title: "No active plan") { EmptyView() }
            }
            ForEach(Array(me.subscriptions.enumerated()), id: \.element.productId) { i, s in
                if i > 0 { Divider().padding(.leading, 68) }
                Row(symbol: "square.stack.3d.up", title: s.productName, subtitle: until(s.endsAt)) {
                    if Features.sells {
                        Button("Extend") { extending = s.productId }
                            .font(.open(15, .bold)).foregroundStyle(.white).padding(.horizontal, 16).frame(height: 44)
                            .background(Theme.primary, in: Capsule())
                    }
                }
                if Features.sells && !Features.store {
                    Divider().padding(.leading, 68)
                    Toggle(isOn: Binding(get: { renewing.contains(s.productId) != s.autoRenew },
                                         set: { on in Task { await setRenew(s, on: on) } })) {
                        Text("Auto-renew from wallet").font(.open(15, .semibold)).foregroundStyle(Theme.fg)
                    }
                    .tint(Theme.primary).padding(.horizontal, 14).padding(.vertical, 10)
                    .disabled(renewing.contains(s.productId))   // one change at a time
                    if let why = s.renewError, s.autoRenew {
                        Text(why).font(.open(13.5)).foregroundStyle(Theme.down)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 14).padding(.bottom, 10)
                    }
                }
            }
        }
    }

    private func setRenew(_ s: Subscription, on: Bool) async {
        renewing.insert(s.productId); renewError = nil
        do { try await session.api.setAutoRenew(productId: s.productId, on: on); await session.refreshMe() }
        catch { session.handle(error); renewError = Copy.error(error) }
        renewing.remove(s.productId)
    }

    private func copierRow(chevron: Bool) -> some View {
        let power = CopierPower.of(hasPass: copier?.hasPass ?? false, account: copier?.account)
        return Row(symbol: "power", title: "Copier", subtitle: copier == nil ? nil : power.sub) {
            HStack(spacing: 8) {
                if copier != nil {
                    Text(power.label).font(.open(15, .semibold))
                        .foregroundStyle(power.ring == .on ? Theme.up : power.ring == .error ? Theme.down : Theme.muted)
                }
                if chevron { Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.muted) }
            }
        }
    }

    private func until(_ end: Date) -> String {
        let days = max(0, Int((end.timeIntervalSinceNow / 86_400).rounded(.up)))
        let date = end.formatted(Date.FormatStyle(locale: Locale(identifier: "en_GB")).day().month(.abbreviated).year())
        return "Active until \(date), \(days) day\(days == 1 ? "" : "s") left"
    }
}

private struct Row<Trailing: View>: View {
    let symbol: String
    let title: String
    var subtitle: String? = nil
    @ViewBuilder let trailing: Trailing
    var body: some View {
        HStack(spacing: 14) {
            IconTile(symbol: symbol)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.open(16, .bold)).foregroundStyle(Theme.fg)
                if let subtitle { Text(subtitle).font(.open(13.5)).foregroundStyle(Theme.muted) }
            }
            Spacer(minLength: 8)
            trailing
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

private struct Extend: Identifiable { let id: String }

private struct MenuValue: View {
    let text: String
    var body: some View {
        HStack(spacing: 6) {
            Text(text).font(.open(15)).foregroundStyle(Theme.muted)
            Image(systemName: "chevron.up.chevron.down").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.muted)
        }
    }
}
