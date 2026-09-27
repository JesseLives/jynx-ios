import Foundation

public struct Viewport: Equatable, Sendable {
    public static let margin = 3.0
    public static let fewestBars = 20.0, mostBars = 400.0
    public var barWidth: Double
    public var offset: Double
    public init(barWidth: Double, offset: Double = 0) { self.barWidth = barWidth; self.offset = offset }

    public var isPinned: Bool { offset < 0.5 }

    private func slot(_ index: Double, count: Int) -> Double { Double(count - 1) - index + Self.margin - offset }

    public func x(of index: Int, count: Int, width: Double) -> Double {
        width - (slot(Double(index), count: count) + 0.5) * barWidth
    }

    public func index(at x: Double, count: Int, width: Double) -> Int {
        Int((Double(count - 1) + Self.margin - offset - ((width - x) / barWidth - 0.5)).rounded())
    }

    public func visible(count: Int, width: Double) -> Range<Int> {
        let right = Double(count - 1) + Self.margin - offset
        let lo = max(0, Int((right - width / barWidth + 0.5).rounded(.down)))
        let hi = min(count, Int((right + 0.5).rounded(.down)) + 1)
        return lo < hi ? lo..<hi : lo..<lo
    }

    private func clamped(count: Int, width: Double) -> Viewport {
        var v = self
        v.barWidth = min(max(barWidth, width / Self.mostBars), width / Self.fewestBars)
        let most = max(0, Double(count - 1) + Self.margin - width / v.barWidth)
        v.offset = min(max(offset, 0), most)
        return v
    }

    public func panned(by dx: Double, count: Int, width: Double) -> Viewport {
        Viewport(barWidth: barWidth, offset: offset + dx / barWidth).clamped(count: count, width: width)
    }

    public func zoomed(by scale: Double, anchorX: Double, count: Int, width: Double) -> Viewport {
        let under = Double(count - 1) + Self.margin - offset - ((width - anchorX) / barWidth - 0.5)
        var v = Viewport(barWidth: barWidth * scale, offset: 0).clamped(count: count, width: width)
        v.offset = Double(count - 1) + Self.margin - under - ((width - anchorX) / v.barWidth - 0.5)
        return v.clamped(count: count, width: width)
    }

    public func afterNewBar() -> Viewport { isPinned ? self : Viewport(barWidth: barWidth, offset: offset + 1) }
}

public struct PriceScale: Equatable, Sendable {
    public let lo: Double, hi: Double, top: Double, bottom: Double

    public init<C: Collection>(bars: C, extra: [Double], top: Double, bottom: Double) where C.Element == Bar {
        var lo = min(bars.map(\.l).min() ?? .infinity, extra.min() ?? .infinity)
        var hi = max(bars.map(\.h).max() ?? -.infinity, extra.max() ?? -.infinity)
        if !lo.isFinite || !hi.isFinite { lo = 0; hi = 1 }
        let span = max(hi - lo, max(abs(hi), 1) * 0.0005)
        self.lo = lo - span * 0.08; self.hi = hi + span * 0.08; self.top = top; self.bottom = bottom
    }

    public func y(_ price: Double) -> Double { top + (hi - price) / (hi - lo) * (bottom - top) }
    public func price(y: Double) -> Double { hi - (y - top) / (bottom - top) * (hi - lo) }

    public static func step(lo: Double, hi: Double, height: Double) -> Double {
        let raw = (hi - lo) / max(2, height / 60)
        guard raw > 0, raw.isFinite else { return 1 }
        let mag = pow(10, (log10(raw)).rounded(.down))
        return [1, 2, 2.5, 5, 10].map { $0 * mag }.first { $0 >= raw } ?? 10 * mag
    }

    public static func ticks(lo: Double, hi: Double, height: Double) -> [Double] {
        let step = step(lo: lo, hi: hi, height: height)
        var k = (lo / step).rounded(.up), out: [Double] = []
        while k * step <= hi + step * 1e-9, out.count < 200 {
            out.append(((k * step) * 1e10).rounded() / 1e10)
            k += 1
        }
        return out
    }
}

public func declutter(_ ys: [Double], gap: Double) -> [Bool] {
    var placed: [Double] = []
    return ys.map { y in
        let clear = !placed.contains { abs($0 - y) < gap }
        if clear { placed.append(y) }
        return clear
    }
}
