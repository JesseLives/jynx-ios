import Foundation
import Testing
@testable import JynxKit

@Test func dollarsLikeTheSite() {
    #expect(Money.dollars(123456) == "$1,234.56")
    #expect(Money.dollars(0) == "$0.00")
    #expect(Money.signed(1149) == "+$11.49")
    #expect(Money.signed(-1000) == "−$10.00")
}

@Test func planMathMatchesTheSite() {
    let prices = [1: 11499, 3: 29999, 6: 54999, 12: 82999]
    #expect([1, 3, 6, 12].map { PlanMath.perMonth(prices, $0) } == [11499, 10000, 9167, 6917])
    #expect([1, 3, 6, 12].map { PlanMath.percentOff(prices, $0) } == [nil, 13, 20, 40])
    #expect(PlanMath.bestValue(prices) == 12)
    #expect(PlanMath.cheapestMonthly(prices) == 6917)
    #expect(PlanMath.percentOff([3: 100], 3) == nil)
    #expect(PlanMath.bestValue([1: 1000]) == nil)
}

@Test func keypadBuildsCents() {
    var a = AmountInput()
    for k in ["1", "0", ".", "1"] { a.press(k) }
    #expect(a.text == "10.1" && a.cents == 1010)
    a.press("5"); a.press("9")                     // a third decimal is refused
    #expect(a.text == "10.15" && a.cents == 1015)
    a.press(".")                                    // a second point is refused
    #expect(a.text == "10.15")
    a.press("⌫"); a.press("⌫"); a.press("⌫")
    #expect(a.text == "10" && a.cents == 1000)
    a.add(cents: 5000)
    #expect(a.text == "60" && a.cents == 6000)
    var b = AmountInput(); for k in ["0", "0", "7"] { b.press(k) }
    #expect(b.text == "7")                          // no leading zeros
    var c = AmountInput(); for _ in 0..<9 { c.press("9") }
    #expect(c.cents == 1_000_000)                   // capped at $10,000
    var d = AmountInput(); d.press(".")
    #expect(d.text == "0." && d.cents == 0)
    #expect(AmountInput().cents == nil)
}

@Test func decodesPlans() throws {
    let p = try JSON.decoder().decode(PlansBody.self, from: fixture("plans"))
    #expect(p.payment.autoQr == .khqr && p.payment.usdtTrc20.hasPrefix("T") && p.payment.abaName == "JYNX CO")
    let channel = try #require(p.products.first { $0.kind == .channel })
    #expect(channel.prices == [1: 11499, 3: 29999, 6: 54999, 12: 82999])
    #expect(channel.lengths == [1, 3, 6, 12])
    #expect(p.products.contains { $0.kind == .copier })
}

@Test func decodesWallet() throws {
    let w = try JSON.decoder().decode(WalletBody.self, from: fixture("wallet")).wallet
    #expect(w.balance == 5149 && w.withdrawable == 149 && w.counts == [1, 0, 0] && w.rates == [10, 5, 2])
    #expect(Set(w.activity.map(\.kind)) == [.deposit, .commission, .withdrawal])
    #expect(w.withdrawals.first?.status == "pending" && w.withdrawals.first?.method == "usdt")
    let c = try #require(w.activity.first { $0.kind == .commission })
    #expect(c.describe.title.hasPrefix("From ") && c.describe.subtitle == "Referral, level 1")
    #expect(w.activity.first { $0.kind == .withdrawal }?.describe.subtitle == "Waiting to be paid")
}

@Test func decodesPaymentsAndQR() throws {
    let list = try JSON.decoder().decode(PaymentsBody.self, from: fixture("payments")).payments
    #expect(Set(list.map(\.status)) == [.pending, .approved, .rejected])
    #expect(list.first { $0.status == .rejected }?.rejectReason == "No USDT arrived for that transaction ID.")
    let qr = try JSON.decoder().decode(QRPaymentBody.self, from: fixture("qr-start")).payment
    #expect(qr.method == .khqr && qr.amountCents == 11499 && qr.deeplink != nil && qr.pngData != nil)
    let s = try JSON.decoder().decode(PaymentStatusBody.self, from: fixture("payment-status")).payment
    #expect(s.status == .pending && s.kind == "plan")
}

@Test func commerceErrorsReadLikeTheSite() throws {
    #expect(Copy.error(APIError.server(status: 400, code: "insufficient", field: nil, message: nil)) == "Not enough in your wallet. Deposit first, or pay by ABA or USDT.")
    #expect(Copy.error(APIError.server(status: 400, code: "no_proof", field: nil, message: nil)) == "Add a receipt screenshot or a transaction reference.")
}

@Test func moneyRequestsSendNumbers() async throws {
    let t = StubTransport(); t.body = try fixture("qr-start")
    _ = try await api(t).startQR(productId: "p1", months: 3)
    _ = try await api(t).startQR(depositCents: 2500)
    t.body = Data(#"{"ok":true,"endsAt":"2026-10-27T00:00:00.000Z"}"#.utf8)
    _ = try await api(t).buyWithWallet(productId: "p1", months: 1)
    t.body = Data(#"{"ok":true,"id":"w1"}"#.utf8)
    try await api(t).withdraw(amountCents: 1500, method: "usdt", destination: "TX")
    let bodies = try t.seen.map { try #require(JSONSerialization.jsonObject(with: $0.httpBody!) as? [String: Any]) }
    #expect(t.seen.map(\.url!.path) == ["/api/payments/qr", "/api/payments/qr", "/api/wallet", "/api/wallet"])
    #expect(bodies[0]["kind"] as? String == "plan" && bodies[0]["months"] as? Int == 3 && bodies[0]["productId"] as? String == "p1")
    #expect(bodies[1]["kind"] as? String == "deposit" && bodies[1]["amountCents"] as? Int == 2500)
    #expect(bodies[2]["action"] as? String == "buy" && bodies[2]["months"] as? Int == 1)
    #expect(bodies[3]["action"] as? String == "withdraw" && bodies[3]["amountCents"] as? Int == 1500)
    #expect(!(bodies[0]["months"] is String))
}

@Test func typedDollarsReadTheDecimalSeparator() {
    #expect(AmountInput.parse("10,50", decimalSeparator: ",") == 1050)
    #expect(AmountInput.parse("10,5", decimalSeparator: ",") == 1050)
    #expect(AmountInput.parse("1.234,50", decimalSeparator: ",") == 123450)
    #expect(AmountInput.parse("10.50", decimalSeparator: ".") == 1050)
    #expect(AmountInput.parse("1,234.50", decimalSeparator: ".") == 123450)
    #expect(AmountInput.parse("20000", decimalSeparator: ".") == 2_000_000)   // no deposit cap on a withdrawal
    #expect(AmountInput.parse("10.555", decimalSeparator: ".") == nil)
    #expect(AmountInput.parse("", decimalSeparator: ".") == nil)
    #expect(AmountInput.parse("1.2.3", decimalSeparator: ".") == nil)
}

@Test func typedAmountsReadEitherMark() {
    #expect(AmountInput.parse("0,05", decimalSeparator: ".") == 5)
    #expect(AmountInput.parse("0.05", decimalSeparator: ",") == 5)
    #expect(AmountInput.parse("1.5", decimalSeparator: ",") == 150)
    #expect(AmountInput.parse("10,50", decimalSeparator: ".") == 1050)
    #expect(AmountInput.parse("1,234", decimalSeparator: ".") == 123_400)
    #expect(AmountInput.parse("1.234", decimalSeparator: ",") == 123_400)
    #expect(AmountInput.parse("12,345,678.9", decimalSeparator: ".") == 1_234_567_890)
    #expect(AmountInput.parse("10.555", decimalSeparator: ".") == nil)
    #expect(AmountInput.parse("10,555", decimalSeparator: ",") == nil)
    #expect(CopierInput.lot("0,05", separator: ".") == 0.05)
}

@Test func hugeTypedAmountsAreRefusedNotACrash() {
    #expect(AmountInput.parse("99999999999999999", decimalSeparator: ".") == nil)
    #expect(AmountInput.parse("999999999999", decimalSeparator: ".") == 99_999_999_999_900)
}

@Test func plansCarryTheirAppStoreIDs() throws {
    let p = try JSON.decoder().decode(PlansBody.self, from: fixture("plans"))
    let channel = try #require(p.products.first { $0.kind == .channel })
    #expect(channel.appleIds.keys.sorted() == [1, 3, 6, 12])
    #expect(channel.appleIds[3]?.hasPrefix("xyz.justsal.jynx.") == true && channel.appleIds[3]?.hasSuffix(".3m") == true)
}

@Test func reportingAnApplePurchase() async throws {
    let t = StubTransport(); t.body = try fixture("iap-granted")
    let end = try await api(t).reportApplePurchase(signedTransaction: "a.b.c")
    #expect(end != nil && t.seen[0].url?.path == "/api/iap")
    #expect(try JSONSerialization.jsonObject(with: t.seen[0].httpBody!) as? [String: String] == ["signedTransaction": "a.b.c"])
    #expect(Copy.error(APIError.server(status: 400, code: "not_yours", field: nil, message: nil)) == "That purchase belongs to another Jynx account.")
    #expect(Copy.error(APIError.server(status: 400, code: "bad_signature", field: nil, message: nil)) == "Apple could not confirm that purchase. Try again.")
}
