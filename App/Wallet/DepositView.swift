import SwiftUI
import JynxKit

struct DepositView: View {
    let minCents: Int
    let payment: PaymentSettings?
    @State private var amount = CentsInput()
    @State private var paying: PayOrder?
    @State private var error: String?

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 10)
            HStack(alignment: .top, spacing: 2) {
                Text("$").font(.open(34, .heavy)).foregroundStyle(Theme.muted).padding(.top, 12)
                Text(amount.display).font(.open(64, .heavy)).tracking(-2.5)
                    .foregroundStyle(amount.cents == 0 ? Theme.muted : Theme.fg)
                    .monospacedDigit().lineLimit(1).minimumScaleFactor(0.4).contentTransition(.numericText())
            }
            .animation(.snappy(duration: 0.15), value: amount.cents)
            .accessibilityElement(children: .ignore).accessibilityLabel("Amount \(Money.dollars(amount.cents))")
            Text(error ?? "From \(Money.dollars(minCents)) to $10,000").font(.open(13.5)).foregroundStyle(error == nil ? Theme.muted : Theme.down)
            Spacer(minLength: 10)
            HStack(spacing: 10) {
                ForEach([1000, 5000, 10000], id: \.self) { c in
                    Button("+\(Money.dollars(c).replacingOccurrences(of: ".00", with: ""))") { amount.add(cents: c); error = nil }
                        .font(.open(15, .heavy)).foregroundStyle(Theme.fg).padding(.horizontal, 16).frame(height: 44)
                        .background(Theme.card, in: Capsule()).overlay(Capsule().stroke(Theme.borderSoft))
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 6) {
                ForEach(["1", "2", "3", "4", "5", "6", "7", "8", "9", "00", "0", "⌫"], id: \.self) { k in
                    Button { amount.press(k); error = nil } label: {
                        Group {
                            if k == "⌫" { Image(systemName: "delete.left").font(.system(size: 22, weight: .medium)).accessibilityLabel("Delete") }
                            else { Text(k).font(.open(30, .semibold)) }
                        }
                        .foregroundStyle(Theme.fg).frame(maxWidth: .infinity).frame(height: 58).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }
            }
            PrimaryButton(title: "Continue") {
                let c = amount.cents
                guard c >= minCents, c <= AmountInput.maxCents else {
                    error = Copy.error(APIError.server(status: 400, code: "bad_amount", field: nil, message: nil)); return
                }
                paying = .deposit(cents: c)
            }
        }
        .padding(.horizontal, 20).padding(.bottom, 16)
        .background(Theme.bg)
        .navigationTitle("Deposit").navigationBarTitleDisplayMode(.large)
        .navigationDestination(item: $paying) { PayView(order: $0, payment: payment) }
    }
}
