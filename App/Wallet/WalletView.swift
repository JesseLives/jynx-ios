import SwiftUI
import JynxKit

struct WalletView: View {
    @Environment(Session.self) private var session
    @State private var wallet: WalletOverview?
    @State private var plans: PlansBody?
    @State private var error: String?
    @State private var withdrawing = false
    @State private var path: [Route] = []

    enum Route: Hashable { case deposit, invite }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                if let wallet { content(wallet) }
                else if let error {
                    VStack(spacing: 12) {
                        Text(error).font(.open(15)).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
                        Button("Try again") { Task { await load() } }.font(.open(15, .semibold))
                    }.padding(.top, 80).frame(maxWidth: .infinity)
                } else { ProgressView().padding(.top, 80).frame(maxWidth: .infinity) }
            }
            .background(Theme.bg)
            .navigationTitle("Wallet").navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: Route.self) { r in
                switch r {
                case .deposit: DepositView(minCents: wallet?.minDepositCents ?? 500, payment: plans?.payment)
                case .invite: if let wallet { InviteView(wallet: wallet) { await load() } }
                }
            }
            .sheet(isPresented: $withdrawing) {
                if let wallet { WithdrawSheet(wallet: wallet) { withdrawing = false; Task { await load() } }.presentationDetents([.medium, .large]) }
            }
            .task { await load() }
            .refreshable { await load() }
            .onChange(of: path) { if path.isEmpty { Task { await load() } } }
        }
    }

    private func load() async {
        do {
            async let w = session.api.wallet()
            async let p = session.api.plans()
            wallet = try await w; plans = try? await p; error = nil
        } catch is CancellationError {
        } catch { session.handle(error); if wallet == nil { self.error = Copy.error(error) } }
    }

    private func content(_ w: WalletOverview) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            WalletCard(wallet: w)
            HStack {
                if Features.sells { action("Deposit", "arrow.down.to.line", filled: true) { path.append(.deposit) } }
                action("Withdraw", "arrow.up.to.line") { withdrawing = true }
                if w.referrals { action("Invite", "square.and.arrow.up") { path.append(.invite) } }
            }
            let days = grouped(w.activity)
            if days.isEmpty {
                Text("Nothing here yet. Deposits, referral earnings and payments from your wallet show up here.")
                    .font(.open(15)).foregroundStyle(Theme.muted).padding(.top, 8)
            }
            ForEach(days, id: \.0) { day, items in
                VStack(alignment: .leading, spacing: 10) {
                    StepLabel(day)
                    ForEach(items) { a in ActivityRow(item: a, rejectReason: reason(a, w)) }
                }
            }
        }
        .padding(.horizontal, 16).padding(.bottom, 24)
    }

    private func action(_ title: String, _ symbol: String, filled: Bool = false, _ tap: @escaping () -> Void) -> some View {
        Button(action: tap) {
            VStack(spacing: 8) {
                Circle().fill(filled ? Theme.primary : Theme.card).frame(width: 64, height: 64)
                    .overlay(Circle().stroke(filled ? Color.clear : Theme.borderSoft))
                    .overlay(Image(systemName: symbol).font(.system(size: 20, weight: .semibold)).foregroundStyle(filled ? .white : Theme.primary))
                Text(title).font(.open(15, .bold)).foregroundStyle(Theme.fg)
            }.frame(maxWidth: .infinity)
        }.buttonStyle(.plain)
    }

    private func grouped(_ items: [WalletActivity]) -> [(String, [WalletActivity])] {
        var out: [(String, [WalletActivity])] = []
        for a in items {
            let d = Format.day(a.at)
            if out.last?.0 == d { out[out.count - 1].1.append(a) } else { out.append((d, [a])) }
        }
        return out
    }

    private func reason(_ a: WalletActivity, _ w: WalletOverview) -> String? {
        guard a.kind == .withdrawal, a.withdrawalStatus == "rejected" else { return nil }
        return w.withdrawals.first { $0.id == a.id }?.rejectReason
    }
}

private struct WalletCard: View {
    let wallet: WalletOverview
    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(hex: 0x10141a)
            Circle().fill(Theme.primary).frame(width: 300, height: 300).offset(x: 190, y: 70)
            Circle().fill(Color(hex: 0x0d63b0)).frame(width: 190, height: 190).offset(x: 110, y: 150)
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    RoundedRectangle(cornerRadius: 9).fill(Theme.primary).frame(width: 32, height: 32)
                        .overlay(Text("J").font(.open(15, .heavy)).foregroundStyle(.white))
                    Spacer()
                    Text("Jynx wallet").font(.open(14, .semibold)).foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                Text("Balance").font(.open(14, .semibold)).foregroundStyle(.white.opacity(0.7))
                Text(Money.dollars(wallet.balance)).font(.open(40, .heavy)).tracking(-1.2).foregroundStyle(.white).monospacedDigit()
                    .contentTransition(.numericText())
                HStack {
                    Text("Withdrawable \(Money.dollars(wallet.withdrawable))")
                    Spacer()
                    Text(wallet.username).lineLimit(1)
                }.font(.open(13.5, .semibold)).foregroundStyle(.white.opacity(0.85)).padding(.top, 6)
            }.padding(22)
        }
        .frame(height: 210).clipShape(RoundedRectangle(cornerRadius: 26))
        .shadow(color: .black.opacity(0.18), radius: 16, y: 8)
    }
}

private struct ActivityRow: View {
    let item: WalletActivity
    let rejectReason: String?
    var body: some View {
        let d = item.describe
        HStack(spacing: 14) {
            IconTile(symbol: d.symbol)
            VStack(alignment: .leading, spacing: 2) {
                Text(d.title).font(.open(16, .bold)).foregroundStyle(Theme.fg).lineLimit(1)
                Text([d.subtitle, Format.clock(item.at)].filter { !$0.isEmpty }.joined(separator: ", ")).font(.open(13.5)).foregroundStyle(Theme.muted)
                if let rejectReason { Text(rejectReason).font(.open(13)).foregroundStyle(Theme.down) }
            }
            Spacer(minLength: 8)
            Text(Money.signed(item.cents)).font(.open(16, .heavy)).foregroundStyle(item.cents > 0 ? Theme.up : Theme.fg).monospacedDigit()
        }
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.borderSoft))
    }
}
