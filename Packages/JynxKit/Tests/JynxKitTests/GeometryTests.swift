import Foundation
import Testing
@testable import JynxKit

private let W = 400.0   // plot width in points

@Test func pinnedShowsTheNewestBarsAtTheRightEdge() {
    let v = Viewport(barWidth: 10)
    let r = v.visible(count: 1000, width: W)
    #expect(r.upperBound == 1000)
    #expect(r.count >= 37 && r.count <= 42)
    #expect(v.x(of: 999, count: 1000, width: W) < W)
    #expect(v.index(at: v.x(of: 950, count: 1000, width: W), count: 1000, width: W) == 950)
}

@Test func panningIsClamped() {
    var v = Viewport(barWidth: 10)
    v = v.panned(by: -500, count: 1000, width: W)
    #expect(v.offset == 0 && v.isPinned)
    v = v.panned(by: 1_000_000, count: 1000, width: W)     // flung far into the past
    #expect(v.offset <= 1000 && v.visible(count: 1000, width: W).lowerBound == 0)
    #expect(!v.isPinned)
}

@Test func zoomIsClampedBetween20And400Bars() {
    var v = Viewport(barWidth: 10)
    v = v.zoomed(by: 100, anchorX: 200, count: 1000, width: W)
    #expect(abs(W / v.barWidth - 20) < 0.001)
    v = v.zoomed(by: 0.0001, anchorX: 200, count: 1000, width: W)
    #expect(abs(W / v.barWidth - 400) < 0.001)
}

@Test func zoomKeepsTheBarUnderTheFingers() {
    var v = Viewport(barWidth: 10).panned(by: 300, count: 1000, width: W)
    let under = v.index(at: 150, count: 1000, width: W)
    v = v.zoomed(by: 1.5, anchorX: 150, count: 1000, width: W)
    #expect(v.index(at: 150, count: 1000, width: W) == under)
}

@Test func aNewBarFollowsOnlyWhenPinned() {
    let pinned = Viewport(barWidth: 10)
    #expect(pinned.afterNewBar().isPinned)
    let back = Viewport(barWidth: 10).panned(by: 200, count: 1000, width: W)
    let before = back.index(at: 100, count: 1000, width: W)
    #expect(back.afterNewBar().index(at: 100, count: 1001, width: W) == before)
}

@Test func priceScaleRoundTripsAndPads() {
    let s = PriceScale(bars: [Bar(t: 0, o: 3700, h: 3744, l: 3700, c: 3740)], extra: [3690], top: 0, bottom: 500)
    #expect(s.lo < 3690 && s.hi > 3744)
    #expect(abs(s.price(y: s.y(3720)) - 3720) < 1e-9)
    #expect(s.y(s.hi) == 0 && s.y(s.lo) == 500)
}

@Test func niceTicks() {
    #expect(PriceScale.ticks(lo: 3700, hi: 3744, height: 540) == stride(from: 3700.0, through: 3740, by: 5).map { $0 })
    #expect(PriceScale.ticks(lo: 1.0801, hi: 1.0899, height: 300).first == 1.082)
    #expect(PriceScale.step(lo: 0, hi: 1, height: 0) > 0)
}

@Test func labelsDeclutterByPriority() {
    #expect(declutter([100, 108, 200, 210, 300], gap: 16) == [true, false, true, false, true])
}

@Test func tickDecimalsShowEveryTickExactly() {
    #expect(PriceScale.decimals([4300, 4310, 4320]) == 0)
    #expect(PriceScale.decimals([4300, 4302.5, 4305]) == 1)
    #expect(PriceScale.decimals([4300, 4325, 4350]) == 0)
    #expect(PriceScale.decimals([1.0825, 1.085, 1.0875]) == 4)
    #expect(PriceScale.decimals([0.25, 0.5, 0.75]) == 2)
}
