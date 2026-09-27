import SwiftUI
import JynxKit

struct WithdrawSheet: View {
    let wallet: WalletOverview
    let done: () -> Void
    @Environment(Session.self) private var session
    @State private var dollars = ""
    @State private var method = "usdt"
    @State private var destination = ""
    @State private var busy = false
    @State private var error: String?
    @State private var sent = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Withdraw").font(.open(22, .heavy)).foregroundStyle(Theme.fg).padding(.top, 24)
            if sent {
                Text("Withdrawal requested. It shows in your activity until it is paid.").font(.open(15)).foregroundStyle(Theme.muted)
                PrimaryButton(title: "Done", action: done)
            } else if wallet.withdrawable < wallet.minWithdrawCents {
                Text("You can withdraw from \(Money.dollars(wallet.minWithdrawCents)) of referral earnings. You have \(Money.dollars(wallet.withdrawable)).")
                    .font(.open(15)).foregroundStyle(Theme.muted)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Amount").font(.open(14, .semibold)).foregroundStyle(Theme.fg)
                    TextField("0.00", text: $dollars).keyboardType(.decimalPad).font(.open(16))
                        .padding(.horizontal, 14).frame(minHeight: 48)
                        .background(Theme.raised, in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border))
                }
                Text("Up to \(Money.dollars(wallet.withdrawable)). Only referral earnings can be withdrawn.").font(.open(13.5)).foregroundStyle(Theme.muted)
                Segmented(options: [("usdt", "USDT (TRC20)"), ("aba", "ABA")], selection: $method)
                Field(label: method == "usdt" ? "USDT address (TRON)" : "ABA account number and name", text: $destination,
                      placeholder: method == "usdt" ? "T…" : "000 000 000, Your Name", kind: .login, submitLabel: .send) {
                    if destination.trimmingCharacters(in: .whitespaces).count >= 3 { Task { await submit() } }
                }
                if let error { Text(error).font(.open(14)).foregroundStyle(Theme.down) }
                PrimaryButton(title: typedCents.map { "Withdraw \(Money.dollars($0))" } ?? "Request withdrawal", busy: busy) { Task { await submit() } }
                    .disabled(destination.trimmingCharacters(in: .whitespaces).count < 3)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .onAppear {
            let sep = Locale.current.decimalSeparator ?? "."
            dollars = "\(wallet.withdrawable / 100)\(sep)" + String(format: "%02d", wallet.withdrawable % 100)
        }
    }

    private var typedCents: Int? { AmountInput.parse(dollars, decimalSeparator: Locale.current.decimalSeparator ?? ".") }

    private func submit() async {
        guard let cents = typedCents else { error = "Enter an amount like 10.50."; return }
        guard cents >= wallet.minWithdrawCents else {
            error = "The smallest withdrawal is \(Money.dollars(wallet.minWithdrawCents))."; return
        }
        busy = true; error = nil
        do { try await session.api.withdraw(amountCents: cents, method: method, destination: destination.trimmingCharacters(in: .whitespaces)); sent = true }
        catch { session.handle(error); self.error = Copy.error(error) }
        busy = false
    }
}
