import SwiftUI
import JynxKit

struct SignalCardView: View {
    let signal: Signal?
    let chartURL: URL?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(PriceFeed.self) private var prices
    @State private var turn = false

    var body: some View {
        Group {
            if let s = signal { card(s) }
            else {
                RoundedRectangle(cornerRadius: 24).fill(Theme.card).frame(height: 250)
                    .overlay(ProgressView())
            }
        }
        .frame(maxWidth: 420, alignment: .leading)
    }

    private func card(_ s: Signal) -> some View {
        inner(s)
            .padding(1.5)
            .background { border(running: s.status == .running) }
            .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    @ViewBuilder private func border(running: Bool) -> some View {
        if running {
            GeometryReader { g in
                let side = hypot(g.size.width, g.size.height)
                AngularGradient(colors: [Color(hex: 0x16c784), Theme.primary, Color(hex: 0xf5c542), Color(hex: 0x16c784)], center: .center)
                    .frame(width: side, height: side)
                    .rotationEffect(.degrees(turn ? 360 : 0))
                    .animation(reduceMotion ? nil : .linear(duration: 6).repeatForever(autoreverses: false), value: turn)
                    .position(x: g.size.width / 2, y: g.size.height / 2)
            }
            .onAppear { turn = true }
        } else {
            Theme.border
        }
    }

    private func live(_ s: Signal) -> PriceTick? { s.status == .running && s.symbol == PriceFeed.symbol ? prices.last : nil }

    private func inner(_ s: Signal) -> some View {
        let done = s.status != .running
        let tick = live(s)
        let livePips = tick.flatMap { Pips.value(symbol: s.symbol, side: s.side, entry: Double(s.entry) ?? 0, exit: $0.p) }
        let fresh = tick.map { Date().timeIntervalSince1970 - $0.t < 60 } ?? false
        let fills = TargetProgress.fills(side: s.side, entry: Double(s.entry) ?? 0, tps: s.tps.compactMap(Double.init),
                                         hits: s.tpHits, price: tick?.p)
        let sideColor = done ? Theme.muted : s.side == .buy ? Theme.up : Theme.down
        return VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: s.side == .buy ? "arrow.up.right" : "arrow.down.right").font(.system(size: 12, weight: .bold))
                    Text(headline(s)).font(.open(11, .heavy)).tracking(0.8)
                }.foregroundStyle(sideColor)
                switch s.status {
                case .closed:
                    Text(Format.pips(s.resultPips ?? 0)).font(.open(34, .heavy)).tracking(-1.3)
                        .foregroundStyle((s.resultPips ?? 0) > 0 ? Theme.up : (s.resultPips ?? 0) < 0 ? Theme.down : Theme.fg)
                    Text("Result").font(.open(13.5, .semibold)).foregroundStyle(Theme.muted)
                case .cancelled:
                    Text("Cancelled").font(.open(34, .heavy)).tracking(-1.3).foregroundStyle(Theme.muted)
                default:
                    HStack(spacing: 8) {
                        if fresh { LiveDot() }
                        Text(Format.money(tick.map { String($0.p) } ?? s.entry)).font(.open(34, .heavy)).tracking(-1.3)
                            .foregroundStyle(Theme.fg).monospacedDigit().contentTransition(.numericText())
                    }
                    HStack(spacing: 12) {
                        if let livePips {
                            Text(Format.pips(livePips)).fontWeight(.heavy)
                                .foregroundStyle(livePips > 0 ? Theme.up : livePips < 0 ? Theme.down : Theme.muted)
                        } else { Text("Entry price") }
                        if s.realizedPips != 0 { Text("Realized \(Format.pips(s.realizedPips))") }
                    }.font(.open(13.5, .semibold)).foregroundStyle(Theme.muted)
                }
            }
            HStack(alignment: .top, spacing: 8) {
                ForEach(Array(s.tps.enumerated()), id: \.offset) { i, tp in
                    step(s, i, tp, fill: done && !s.tpHits.contains(i + 1) ? 0 : (i < fills.count ? fills[i] : 0))
                }
            }
            HStack(spacing: 8) {
                tile(s.market ? "ENTRY (MKT)" : "ENTRY") { Text(Format.money(s.entry)) }
                tile(s.slMovedTo == s.entry ? "SL AT ENTRY" : s.slMovedTo != nil ? "SL MOVED" : "STOP") {
                    if let moved = s.slMovedTo, moved != s.sl {
                        HStack(spacing: 4) {
                            Text(Format.money(s.sl)).strikethrough().font(.open(11)).foregroundStyle(Theme.muted)
                            Text(Format.money(moved))
                        }
                    } else { Text(Format.money(s.sl)) }
                }
                tile("CLOSED") { Text("\(Int(((1 - (Double(s.openFraction) ?? 1)) * 100).rounded()))%") }
            }
            if !s.note.isEmpty { Text(s.note).font(.open(13.5)).foregroundStyle(Theme.fg) }
            if s.hasChart, let chartURL {
                AsyncImage(url: chartURL) { img in img.resizable().scaledToFill() } placeholder: { Theme.raised }
                    .frame(height: 180).frame(maxWidth: .infinity).clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border))
            }
        }
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 22.5))
    }

    private func headline(_ s: Signal) -> String {
        let tail = s.status == .closed ? ", CLOSED" : s.status == .cancelled ? ", CANCELLED" : s.market ? ", MARKET" : ""
        return "\(s.side == .buy ? "BUY" : "SELL") \(s.symbol)\(tail)"
    }

    private func step(_ s: Signal, _ i: Int, _ tp: String, fill: Double) -> some View {
        let hit = s.tpHits.contains(i + 1)
        let pips = s.updates.first { $0.kind == "tp_hit" && $0.tp == i + 1 }?.pips
        return VStack(alignment: .leading, spacing: 5) {
            Capsule().fill(Theme.raised).frame(height: 8)
                .overlay(alignment: .leading) {
                    GeometryReader { g in
                        Capsule().fill(Theme.gain).frame(width: g.size.width * fill)
                            .animation(.easeOut(duration: 0.4), value: fill)
                    }
                }
                .clipShape(Capsule())
            HStack(spacing: 4) {
                Text("TP\(i + 1)")
                if hit, let pips { Text(Format.pips(pips)).fontWeight(.heavy) }
            }.font(.open(11, .bold)).foregroundStyle(hit ? Theme.up : Theme.muted).lineLimit(1)
            Text(Format.money(tp)).font(.open(12.5, .bold)).foregroundStyle(Theme.fg).monospacedDigit()
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func tile<V: View>(_ label: String, @ViewBuilder value: () -> V) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.open(9, .heavy)).tracking(0.5).foregroundStyle(Theme.muted).lineLimit(1)
            value().font(.open(13, .bold)).foregroundStyle(Theme.fg).monospacedDigit().lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10).padding(.vertical, 9)
        .background(Theme.bg, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border))
    }
}

struct LiveDot: View {
    @State private var on = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        Circle().fill(Theme.up).frame(width: 8, height: 8)
            .opacity(on ? 0.35 : 1)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: on)
            .onAppear { on = true }
            .accessibilityLabel("Live price")
    }
}
