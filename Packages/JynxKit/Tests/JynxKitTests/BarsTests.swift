import Foundation
import Testing
@testable import JynxKit

private let T = 1_790_000_100 - 1_790_000_100 % 900   // a 15m boundary

@Test func opensTheFirstBarOnTheGrid() {
    #expect(fold(nil, .m15, t: Double(T + 125), price: 2350.5) == (Bar(t: Double(T), o: 2350.5, h: 2350.5, l: 2350.5, c: 2350.5), true))
}

@Test func widensHighLowKeepingTheOpen() {
    var b = fold(nil, .m15, t: Double(T + 1), price: 2350).bar
    b = fold(b, .m15, t: Double(T + 60), price: 2356).bar
    b = fold(b, .m15, t: Double(T + 120), price: 2344).bar
    #expect(fold(b, .m15, t: Double(T + 899), price: 2351) == (Bar(t: Double(T), o: 2350, h: 2356, l: 2344, c: 2351), false))
}

@Test func nextBarAtTheBoundarySkippingEmptyBars() {
    let b = Bar(t: Double(T), o: 1, h: 1, l: 1, c: 1)
    #expect(fold(b, .m15, t: Double(T + 900), price: 2).bar.t == Double(T + 900))
    #expect(fold(b, .m15, t: Double(T + 3 * 900 + 10), price: 2).bar.t == Double(T + 2700))
}

@Test func keepsTheBrokersDayBoundary() {
    let friday2100 = JSON.parseDate("2026-09-18T21:00:00Z")!.timeIntervalSince1970
    let b = Bar(t: friday2100, o: 1, h: 1, l: 1, c: 1)
    let monday = fold(b, .d1, t: JSON.parseDate("2026-09-21T22:30:00Z")!.timeIntervalSince1970, price: 2).bar
    #expect(monday.t == JSON.parseDate("2026-09-21T21:00:00Z")!.timeIntervalSince1970)
}

@Test func ignoresALatePrice() {
    let b = Bar(t: Double(T), o: 1, h: 1, l: 1, c: 1)
    #expect(fold(b, .m1, t: Double(T - 5), price: 9) == (b, false))
}

@Test func heikinAshiMatchesTheSite() {
    let ha = heikinAshi([Bar(t: 0, o: 10, h: 12, l: 9, c: 11), Bar(t: 60, o: 11, h: 15, l: 10, c: 14), Bar(t: 120, o: 14, h: 14.5, l: 8, c: 9)])
    #expect(ha == [Bar(t: 0, o: 10.5, h: 12, l: 9, c: 10.5), Bar(t: 60, o: 10.5, h: 15, l: 10, c: 12.5), Bar(t: 120, o: 11.5, h: 14.5, l: 8, c: 11.375)])
}

@Test func timeframes() {
    #expect(Timeframe(interval: "60") == .h1)
    #expect(Timeframe(interval: "D") == .d1)
    #expect(Timeframe(interval: "nope") == nil)
    #expect(Timeframe.allCases.map(\.label) == ["1m", "5m", "15m", "30m", "1h", "4h", "1D", "1W"])
    #expect(Timeframe.h4.seconds == 14_400 && Timeframe.w1.rawValue == "1w")
}

@Test func pipsLikeTheSite() {
    #expect(Pips.value(symbol: "XAUUSD", side: .buy, entry: 2350, exit: 2365) == 150)
    #expect(Pips.value(symbol: "EURUSD", side: .sell, entry: 1.085, exit: 1.083) == 20)
    #expect(Pips.value(symbol: "XAUUSD", side: .sell, entry: 2350, exit: 2350) == 0)
    #expect(Pips.value(symbol: "NOPE", side: .buy, entry: 1, exit: 2) == nil)
}
