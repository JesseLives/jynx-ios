import Foundation
import Testing
@testable import JynxKit

@Test func readsPriceEvents() {
    #expect(PriceTick(event: SSEEvent(event: "price", data: #"{"t":1790000000.5,"p":3712.34}"#)) == PriceTick(t: 1_790_000_000.5, p: 3712.34))
    #expect(PriceTick(event: SSEEvent(event: "room", data: "abc")) == nil)
    #expect(PriceTick(event: SSEEvent(event: "price", data: "not json")) == nil)
}

@Test func olderTicksAreDropped() {
    let now = PriceTick(t: 100, p: 1)
    #expect(PriceTick(t: 99, p: 2).isNewer(than: now) == false)
    #expect(PriceTick(t: 100, p: 2).isNewer(than: now))
    #expect(PriceTick(t: 1, p: 2).isNewer(than: nil))
}

@Test func theStreamPassesOtherEventsThrough() async {
    let s = Script([["event: price", #"data: {"t":1,"p":2}"#, ""]])
    var got: [LiveEvent] = []
    for await e in stream(s).events() { got.append(e); if got.count == 2 { break } }
    #expect(got == [.connected, .message(SSEEvent(event: "price", data: #"{"t":1,"p":2}"#))])
}

@Test func targetBarsFillTowardsEachTarget() {
    let buy = TargetProgress.fills(side: .buy, entry: 2350, tps: [2365, 2380], hits: [], price: 2357.5)
    #expect(buy == [0.5, 0])
    #expect(TargetProgress.fills(side: .buy, entry: 2350, tps: [2365, 2380], hits: [1], price: 2372.5) == [1, 0.5])
    #expect(TargetProgress.fills(side: .sell, entry: 3700, tps: [3690], hits: [], price: 3695) == [0.5])
    #expect(TargetProgress.fills(side: .sell, entry: 3700, tps: [3690], hits: [], price: 3710) == [0])   // against: empty
    #expect(TargetProgress.fills(side: .buy, entry: 2350, tps: [2365], hits: [], price: nil) == [0])
}
