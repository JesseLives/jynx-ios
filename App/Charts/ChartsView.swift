import SwiftUI
import JynxKit

struct ChartsView: View {
    @Environment(Session.self) private var session
    @Environment(Live.self) private var live
    @Environment(PriceFeed.self) private var prices
    @Environment(\.colorScheme) private var scheme
    @Environment(\.scenePhase) private var phase

    @State private var config: ChartConfig?
    @State private var tf: Timeframe = .h1
    @State private var bars: [Bar] = []
    @State private var sniper: Sniper?
    @State private var signals: [ChartSignal] = []
    @State private var picked: String?
    @State private var dayOpen: Double?
    @State private var viewport: Viewport?
    @State private var crosshair: Int?
    @State private var failed = false
    @State private var switching = false
    @State private var sniperReload: Task<Void, Never>?
    @State private var lastTickAt: Double?

    var body: some View {
        let c = config ?? .standard
        let up = Color(hexString: c.upColor) ?? Theme.up, down = Color(hexString: c.downColor) ?? Theme.down
        VStack(spacing: 12) {
            ChartQuote(price: prices.last?.p ?? bars.last?.c, dayOpen: dayOpen, up: up, down: down,
                       held: crosshair.flatMap { $0 < shownBars.count ? shownBars[$0] : nil }, timeframe: tf,
                       closed: marketClosed)
                .padding(.top, 6)
            if c.toolbar { TimeframePill(selection: $tf).padding(.horizontal, 16) }
            strip(up: up, down: down).frame(minHeight: 24).animation(.easeOut(duration: 0.2), value: signals.isEmpty)
            if failed {
                VStack(spacing: 12) {
                    Text("The chart could not load. Check your connection and try again.").font(.open(15)).foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center)
                    Button("Try again") { Task { await start() } }.font(.open(15, .semibold))
                }.padding(24).frame(maxHeight: .infinity)
            } else {
                CandleCanvas(bars: shownBars, timeframe: tf, style: c.style, up: up, down: down,
                             grid: scheme == .dark ? Color(hex: 0x16181c) : c.grid.flatMap(Color.init(hexString:)) ?? Color(hex: 0xeef2f5),
                             background: c.background.flatMap(Color.init(hexString:)) ?? Theme.bg,
                             lines: lines(up: up, down: down), markers: markers(up: up, down: down),
                             lastPrice: prices.last?.p, viewport: $viewport, crosshair: $crosshair)
                    .opacity(switching ? 0.35 : 1).animation(.easeOut(duration: 0.15), value: switching)
                    .overlay { if bars.isEmpty && !failed { ProgressView() } }
            }
        }
        .background(Theme.bg)
        .task { await start() }
        .onChange(of: tf) { Task { await switchTo(tf) } }
        .onChange(of: prices.last) { if let t = prices.last { take(t) } }
        .onChange(of: prices.reconnects) { Task { await loadCandles() } }
        .onChange(of: phase) { if phase == .active { Task { await loadCandles() } } }
        .task(id: live.any) { await loadSignals() }
    }

    private var marketClosed: Bool {
        let newest = max(prices.last?.t ?? 0, lastTickAt ?? 0)
        return prices.connected && MarketClock.closed(lastTickAt: newest > 0 ? newest : nil)
    }

    private var shownBars: [Bar] { config?.style == .heikin ? heikinAshi(bars) : bars }

    @ViewBuilder private func strip(up: Color, down: Color) -> some View {
        if !signals.isEmpty {
            SignalChips(signals: signals, picked: picked, up: up, down: down) { picked = $0 }
        } else if let sniper {
            SniperStrip(sniper: sniper, up: up, down: down) { tf = $0 }.padding(.horizontal, 16)
        }
    }

    private var active: ChartSignal? { signals.first { $0.id == picked } ?? signals.first }

    private func lines(up: Color, down: Color) -> [PriceLine] {
        guard let s = active else { return [] }
        let p = { (v: Double) in v.formatted(.number.precision(.fractionLength(2)).grouping(.never)) }
        var out = [PriceLine(price: s.entry, color: Theme.fg, title: "\(s.side == .buy ? "Buy" : "Sell") \(p(s.entry))", dash: .solid, width: 2),
                   PriceLine(price: s.sl, color: down, title: s.slMoved && s.sl == s.entry ? "SL at entry" : "SL", dash: .dashed, width: 1)]
        for (i, tp) in s.tps.enumerated() {
            let hit = s.tpHits.contains(i + 1)
            out.append(PriceLine(price: tp, color: hit ? up.opacity(0.55) : up, title: hit ? "TP\(i + 1) hit" : "TP\(i + 1)",
                                 dash: hit ? .dotted : .dashed, width: 1))
        }
        return out
    }

    private func markers(up: Color, down: Color) -> [Marker] {
        var out: [Marker] = []
        if let s = active, let bar = bars.last(where: { $0.t <= s.createdAt }) {
            out.append(Marker(t: bar.t, shape: s.side == .buy ? .up : .down, color: s.side == .buy ? up : down, text: s.side == .buy ? "Buy" : "Sell"))
        }
        if case let .working(w) = sniper {
            out += w.buys.map { Marker(t: $0, shape: .up, color: up, text: "BUY") }
            out += w.sells.map { Marker(t: $0, shape: .down, color: down, text: "SELL") }
            out += w.wins.map { Marker(t: $0, shape: .dot, color: up, text: nil) }
            out += w.losses.map { Marker(t: $0, shape: .square, color: down, text: nil) }
        }
        return out
    }

    // MARK: Data

    private func start() async {
        failed = false
        if config == nil {
            do { let c = try await session.api.chartConfig(); config = c; tf = c.timeframe }
            catch is CancellationError { return }
            catch { session.handle(error); config = .standard }
        }
        await loadCandles(); await loadSignals()
        lastTickAt = try? await session.api.lastPrice().at
    }

    private func switchTo(_ next: Timeframe) async {
        switching = true; sniper = nil; crosshair = nil
        await loadCandles(resetView: true)
        if tf == next { switching = false }
    }

    private func loadCandles(resetView: Bool = false) async {
        let want = tf
        do {
            let c = try await session.api.candles(want)
            guard tf == want else { return }
            bars = c; failed = false
            if resetView { viewport = nil }
            await loadDayOpen()
            await loadSniper()
        } catch is CancellationError {
        } catch {
            session.handle(error)
            if resetView || bars.count < 2 { bars = []; failed = true }
        }
    }

    private func loadSniper() async {
        let want = tf
        guard let s = try? await session.api.indicator(want), tf == want else { return }
        withAnimation(.easeOut(duration: 0.2)) { sniper = s }
    }

    private func loadSignals() async {
        guard let s = try? await session.api.chartSignals() else { return }
        signals = s
        if let picked, !s.contains(where: { $0.id == picked }) { self.picked = nil }
    }

    private func loadDayOpen() async {
        if let d = try? await session.api.candles(.d1, limit: 1).first { dayOpen = d.o }
    }

    private func take(_ tick: PriceTick) {
        guard !switching, !failed, !bars.isEmpty else { return }
        let (bar, fresh) = fold(bars.last, tf, t: tick.t, price: tick.p)
        if !fresh && bar == bars.last { return }
        if fresh {
            bars.append(bar)
            viewport = viewport?.afterNewBar()
            sniperReload?.cancel()
            sniperReload = Task { try? await Task.sleep(for: .seconds(4)); if !Task.isCancelled { await loadSniper() } }
        } else if !bars.isEmpty {
            bars[bars.count - 1] = bar
        }
    }
}

extension Color {
    init?(hexString s: String) {
        guard s.count == 7, s.first == "#", let v = UInt32(s.dropFirst(), radix: 16) else { return nil }
        self.init(hex: v)
    }
}
