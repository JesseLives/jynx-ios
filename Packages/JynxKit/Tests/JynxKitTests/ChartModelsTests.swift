import Foundation
import Testing
@testable import JynxKit

@Test func decodesChartConfig() throws {
    let c = try JSON.decoder().decode(ChartConfigBody.self, from: fixture("chart-config")).chart
    #expect(c.style == .candles && c.upColor == "#00b87a" && c.background == nil && c.toolbar)
    #expect(c.timeframe == .m15)
}

@Test func unknownStyleAndIntervalFallBack() throws {
    let json = ##"{"chart":{"interval":"7","style":"renko","upColor":"#00b87a","downColor":"#f4212e","background":null,"grid":null,"toolbar":true}}"##
    let c = try JSON.decoder().decode(ChartConfigBody.self, from: Data(json.utf8)).chart
    #expect(c.style == .candles && c.timeframe == .h1)
}

@Test func decodesCandlesOldestFirst() throws {
    let bars = try JSON.decoder().decode(CandlesBody.self, from: fixture("candles-1h")).candles
    #expect(bars.count == 5 && bars[0].t < bars[4].t)
}

@Test func decodesEveryIndicatorAnswer() throws {
    #expect(try JSON.decoder().decode(Sniper.self, from: fixture("indicator-locked")) == .locked)
    #expect(try JSON.decoder().decode(Sniper.self, from: fixture("indicator-off")) == .off)
    guard case let .working(w) = try JSON.decoder().decode(Sniper.self, from: fixture("indicator-working")) else {
        Issue.record("not working"); return
    }
    #expect(w.profile == "1h" && w.record && !w.buys.isEmpty && w.panel.state == "Trend up" && w.panel.entry != nil)
    #expect(w.live?.calls == 0)
}

@Test func decodesChartSignals() throws {
    let s = try JSON.decoder().decode(ChartSignalsBody.self, from: fixture("chart-signals")).signals
    #expect(s.count == 1 && s[0].side == .sell && s[0].entry == 3700 && s[0].tps == [3690, 3680] && s[0].tpHits.isEmpty)
}

@Test func sniperSaysWhatTheSiteSays() {
    #expect(SniperPanel.say("In long since 3700") == "Long since 3700")
    #expect(SniperPanel.say("Buy") == "Long")
    #expect(SniperPanel.say("Arming short") == "Setting up a short")
    #expect(SniperPanel.say("Trend up") == "Waiting")
    #expect(SniperPanel.say("Trend upward") == "Trend upward")
}

@Test func marketClosedWhenTheLastPriceIsOld() throws {
    let last = try JSON.decoder().decode(LastPrice.self, from: fixture("chart-price"))
    #expect(last.price == 4284.883 && last.at != nil)
    let now = Date(timeIntervalSince1970: 2_000_000)
    #expect(MarketClock.closed(lastTickAt: 2_000_000 - 601, now: now))
    #expect(!MarketClock.closed(lastTickAt: 2_000_000 - 30, now: now))
    #expect(!MarketClock.closed(lastTickAt: nil, now: now))   // nothing known: say nothing
}
