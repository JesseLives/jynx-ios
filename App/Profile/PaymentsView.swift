import SwiftUI
import JynxKit

struct PaymentsView: View {
    @Environment(Session.self) private var session
    @State private var payments: [PaymentRecord]?
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if let payments {
                    if payments.isEmpty { Text("No payments yet.").font(.open(15)).foregroundStyle(Theme.muted).padding(.top, 40) }
                    ForEach(payments) { row($0) }
                } else if let error {
                    Text(error).font(.open(15)).foregroundStyle(Theme.muted).padding(.top, 40)
                } else { ProgressView().padding(.top, 40) }
            }.padding(16)
        }
        .background(Theme.bg)
        .navigationTitle("Payments").navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        do { payments = try await session.api.payments(); error = nil }
        catch is CancellationError {
        } catch { session.handle(error); if payments == nil { self.error = Copy.error(error) } }
    }

    private func row(_ p: PaymentRecord) -> some View {
        let title = p.kind == "deposit" ? "Deposit" : "\(p.productName ?? "Plan")"
        let sub = [p.months.map { "\($0) \($0 == 1 ? "month" : "months")" }, method(p.method),
                   p.createdAt.formatted(.dateTime.day().month(.abbreviated).hour().minute())].compactMap { $0 }.joined(separator: ", ")
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                IconTile(symbol: p.kind == "deposit" ? "arrow.down.to.line" : "square.stack.3d.up")
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.open(16, .bold)).foregroundStyle(Theme.fg).lineLimit(1)
                    Text(sub).font(.open(13.5)).foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 6) {
                    Text(Money.dollars(p.amountCents)).font(.open(16, .heavy)).foregroundStyle(Theme.fg).monospacedDigit()
                    pill(p.status)
                }
            }
            if p.status == .rejected, let reason = p.rejectReason { Text(reason).font(.open(13.5)).foregroundStyle(Theme.down) }
        }
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.borderSoft))
    }

    private func method(_ m: String) -> String {
        ["aba": "ABA", "usdt": "USDT", "wallet": "Wallet", "khqr": "KHQR"][m] ?? m.uppercased()
    }

    private func pill(_ s: PaymentStatus) -> some View {
        let (text, color): (String, Color) = switch s {
        case .approved: ("Approved", Theme.up)
        case .rejected: ("Rejected", Theme.down)
        case .pending: ("Pending", Theme.wait)
        case .other: ("Unknown", Theme.muted)
        }
        return Text(text).font(.open(12, .bold)).foregroundStyle(color)
            .padding(.horizontal, 9).padding(.vertical, 3).background(color.opacity(0.14), in: Capsule())
    }
}
