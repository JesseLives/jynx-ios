import SwiftUI
import JynxKit

struct PriceLine: Equatable {
    enum Dash { case solid, dashed, dotted }
    let price: Double, color: Color, title: String, dash: Dash, width: CGFloat
}

struct Marker: Equatable {
    enum Shape { case up, down, dot, square }
    let t: Double, shape: Shape, color: Color, text: String?
}

struct CandleCanvas: View {
    let bars: [Bar]
    let timeframe: Timeframe
    let style: ChartStyle
    let up: Color, down: Color, grid: Color, background: Color
    let lines: [PriceLine]
    let markers: [Marker]
    let lastPrice: Double?
    @Binding var viewport: Viewport?
    @Binding var crosshair: Int?

    @State private var panFrom: Viewport?
    @State private var zoomFrom: Viewport?
    static let axisWidth: CGFloat = 60, timeHeight: CGFloat = 24

    var body: some View {
        GeometryReader { geo in
            let plotW = max(1, geo.size.width - Self.axisWidth), plotH = max(1, geo.size.height - Self.timeHeight)
            let vp = viewport ?? Viewport(barWidth: plotW / 70)
            Canvas { ctx, size in draw(&ctx, size: size, vp: vp, plotW: plotW, plotH: plotH) }
                .contentShape(Rectangle())
                .gesture(crosshairGesture(vp: vp, plotW: plotW).exclusively(before: panGesture(vp: vp, plotW: plotW)))
                .simultaneousGesture(zoomGesture(vp: vp, plotW: plotW))
                .onTapGesture(count: 2) { withAnimation(.easeOut(duration: 0.25)) { viewport = Viewport(barWidth: vp.barWidth) } }
        }
        .background(background)
        .accessibilityElement()
        .accessibilityLabel(summary)
        .accessibilityHint("Drag to scroll back, pinch to zoom.")
    }

    private var summary: String {
        guard let last = bars.last else { return "Chart, loading" }
        let p = (lastPrice ?? last.c).formatted(.number.precision(.fractionLength(2)))
        return "XAUUSD chart, \(timeframe.label) candles, last price \(p)" + (lines.isEmpty ? "" : ", with the team signal's levels")
    }

    // MARK: Gestures

    private func panGesture(vp: Viewport, plotW: Double) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { g in
                guard zoomFrom == nil else { return }
                let from = panFrom ?? vp
                if panFrom == nil { panFrom = vp }
                viewport = from.panned(by: g.translation.width, count: bars.count, width: plotW)
            }
            .onEnded { _ in panFrom = nil }
    }

    private func zoomGesture(vp: Viewport, plotW: Double) -> some Gesture {
        MagnifyGesture()
            .onChanged { g in
                panFrom = nil
                let from = zoomFrom ?? vp
                if zoomFrom == nil { zoomFrom = vp }
                viewport = from.zoomed(by: g.magnification, anchorX: min(plotW, g.startLocation.x), count: bars.count, width: plotW)
            }
            .onEnded { _ in zoomFrom = nil }
    }

    private func crosshairGesture(vp: Viewport, plotW: Double) -> some Gesture {
        LongPressGesture(minimumDuration: 0.3)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                guard case .second(true, let drag) = value, let drag else { return }
                let i = vp.index(at: drag.location.x, count: bars.count, width: plotW)
                crosshair = bars.isEmpty ? nil : min(max(i, 0), bars.count - 1)
            }
            .onEnded { _ in crosshair = nil }
    }

    // MARK: Drawing

    private func draw(_ ctx: inout GraphicsContext, size: CGSize, vp: Viewport, plotW: Double, plotH: Double) {
        guard !bars.isEmpty else { return }
        let range = vp.visible(count: bars.count, width: plotW)
        guard !range.isEmpty else { return }
        let shown = bars[range]
        let scale = PriceScale(bars: shown, extra: lines.map(\.price), top: 8, bottom: plotH - 8)
        let x = { (i: Int) in CGFloat(vp.x(of: i, count: bars.count, width: plotW)) }
        let y = { (p: Double) in CGFloat(scale.y(p)) }
        let muted = Theme.muted

        let ticks = PriceScale.ticks(lo: scale.lo, hi: scale.hi, height: plotH)
        let decimals = PriceScale.decimals(ticks)
        let tagDecimals = max(2, decimals)
        for p in ticks {
            var line = Path(); line.move(to: CGPoint(x: 0, y: y(p))); line.addLine(to: CGPoint(x: plotW, y: y(p)))
            ctx.stroke(line, with: .color(grid), lineWidth: 1)
            ctx.draw(Text(p.formatted(.number.precision(.fractionLength(decimals)).grouping(.never))).font(.open(11)).foregroundStyle(muted),
                     at: CGPoint(x: plotW + 8, y: y(p)), anchor: .leading)
        }

        let step = max(1, Int((90 / vp.barWidth).rounded(.up)))
        var lastDay: DateComponents?
        for i in range where i % step == 0 {
            let d = Date(timeIntervalSince1970: bars[i].t), day = Calendar.current.dateComponents([.year, .month, .day], from: d)
            let label = timeframe.seconds >= 86_400 || (lastDay != nil && lastDay != day) || lastDay == nil && isMidnight(d)
                ? d.formatted(.dateTime.month(.abbreviated).day()) : d.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
            lastDay = day
            var line = Path(); line.move(to: CGPoint(x: x(i), y: 0)); line.addLine(to: CGPoint(x: x(i), y: plotH))
            ctx.stroke(line, with: .color(grid), lineWidth: 1)
            ctx.draw(Text(label).font(.open(11, .semibold)).foregroundStyle(muted), at: CGPoint(x: x(i), y: plotH + 12), anchor: .center)
        }

        var plot = ctx
        plot.clip(to: Path(CGRect(x: 0, y: 0, width: plotW, height: plotH)))
        let body = max(1, CGFloat(vp.barWidth) * 0.68)
        switch style {
        case .line, .area:
            var path = Path()
            for i in range { let pt = CGPoint(x: x(i), y: y(bars[i].c)); i == range.lowerBound ? path.move(to: pt) : path.addLine(to: pt) }
            if style == .area, let first = range.first, let last = range.last {
                var fill = path; fill.addLine(to: CGPoint(x: x(last), y: plotH)); fill.addLine(to: CGPoint(x: x(first), y: plotH)); fill.closeSubpath()
                plot.fill(fill, with: .linearGradient(Gradient(colors: [up.opacity(0.28), up.opacity(0.02)]),
                                                      startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: plotH)))
            }
            plot.stroke(path, with: .color(up), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
        default:
            for i in range {
                let b = bars[i], rising = b.c >= b.o, color = rising ? up : down, cx = x(i)
                var wick = Path(); wick.move(to: CGPoint(x: cx, y: y(b.h))); wick.addLine(to: CGPoint(x: cx, y: y(b.l)))
                plot.stroke(wick, with: .color(color), lineWidth: 1)
                if style == .bars {
                    var ticksPath = Path()
                    ticksPath.move(to: CGPoint(x: cx - body / 2, y: y(b.o))); ticksPath.addLine(to: CGPoint(x: cx, y: y(b.o)))
                    ticksPath.move(to: CGPoint(x: cx, y: y(b.c))); ticksPath.addLine(to: CGPoint(x: cx + body / 2, y: y(b.c)))
                    plot.stroke(ticksPath, with: .color(color), lineWidth: 1.5)
                } else {
                    let top = y(max(b.o, b.c)), height = max(1, abs(y(b.o) - y(b.c)))
                    let rect = CGRect(x: cx - body / 2, y: top, width: body, height: height)
                    if style == .hollow && rising {
                        plot.fill(Path(rect), with: .color(background)); plot.stroke(Path(rect), with: .color(color), lineWidth: 1)
                    } else { plot.fill(Path(rect), with: .color(color)) }
                }
            }
        }

        let index = Dictionary(range.map { (bars[$0].t, $0) }, uniquingKeysWith: { first, _ in first })
        for m in markers {
            guard let i = index[m.t] else { continue }
            let b = bars[i], cx = x(i), below = m.shape == .up || m.shape == .dot
            let anchorY = below ? y(b.l) + 8 : y(b.h) - 8
            switch m.shape {
            case .up, .down:
                let s: CGFloat = 6, dir: CGFloat = below ? 1 : -1
                var tri = Path()
                tri.move(to: CGPoint(x: cx, y: anchorY)); tri.addLine(to: CGPoint(x: cx - s, y: anchorY + dir * s * 1.4))
                tri.addLine(to: CGPoint(x: cx + s, y: anchorY + dir * s * 1.4)); tri.closeSubpath()
                plot.fill(tri, with: .color(m.color))
                if let text = m.text {
                    plot.draw(Text(text).font(.open(11, .heavy)).foregroundStyle(m.color),
                              at: CGPoint(x: cx, y: anchorY + dir * (s * 1.4 + 8)), anchor: .center)
                }
            case .dot: plot.fill(Path(ellipseIn: CGRect(x: cx - 3, y: anchorY, width: 6, height: 6)), with: .color(m.color))
            case .square: plot.fill(Path(CGRect(x: cx - 3, y: anchorY - 6, width: 6, height: 6)), with: .color(m.color))
            }
        }

        let showTitle = declutter(lines.map { scale.y($0.price) }, gap: 16)
        for (k, l) in lines.enumerated() {
            var path = Path(); path.move(to: CGPoint(x: 0, y: y(l.price))); path.addLine(to: CGPoint(x: plotW, y: y(l.price)))
            let dash: [CGFloat] = l.dash == .dashed ? [6, 4] : l.dash == .dotted ? [2, 3] : []
            plot.stroke(path, with: .color(l.color), style: StrokeStyle(lineWidth: l.width, dash: dash))
            if showTitle[k] {
                plot.draw(Text(l.title).font(.open(11, .bold)).foregroundStyle(l.color),
                          at: CGPoint(x: plotW - 6, y: y(l.price) - 3), anchor: .bottomTrailing)
            }
            tag(&ctx, price: l.price, y: y(l.price), color: l.color, decimals: tagDecimals, plotW: plotW)
        }

        if let p = lastPrice ?? bars.last?.c, let lastBar = bars.last {
            let color = lastBar.c >= lastBar.o ? up : down
            var path = Path(); path.move(to: CGPoint(x: 0, y: y(p))); path.addLine(to: CGPoint(x: plotW, y: y(p)))
            plot.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
            tag(&ctx, price: p, y: y(p), color: color, decimals: tagDecimals, plotW: plotW)
        }

        if let c = crosshair, range.contains(c) {
            var v = Path(); v.move(to: CGPoint(x: x(c), y: 0)); v.addLine(to: CGPoint(x: x(c), y: plotH))
            var h = Path(); h.move(to: CGPoint(x: 0, y: y(bars[c].c))); h.addLine(to: CGPoint(x: plotW, y: y(bars[c].c)))
            ctx.stroke(v, with: .color(muted), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            ctx.stroke(h, with: .color(muted), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            tag(&ctx, price: bars[c].c, y: y(bars[c].c), color: Theme.fg, decimals: tagDecimals, plotW: plotW)
        }
    }

    private func tag(_ ctx: inout GraphicsContext, price: Double, y: CGFloat, color: Color, decimals: Int, plotW: Double) {
        let rect = CGRect(x: plotW + 2, y: y - 10, width: Self.axisWidth - 4, height: 20)
        ctx.fill(Path(roundedRect: rect, cornerRadius: 5), with: .color(color))
        ctx.draw(Text(price.formatted(.number.precision(.fractionLength(decimals)).grouping(.never))).font(.open(11, .bold))
                    .foregroundStyle(.white), at: CGPoint(x: rect.midX, y: rect.midY), anchor: .center)
    }

    private func isMidnight(_ d: Date) -> Bool { Calendar.current.dateComponents([.hour, .minute], from: d) == DateComponents(hour: 0, minute: 0) }
}
