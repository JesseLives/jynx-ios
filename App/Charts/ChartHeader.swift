import SwiftUI
import JynxKit

struct ChartQuote: View {
    let price: Double?
    let dayOpen: Double?
    let up: Color, down: Color
    let held: Bar?
    let timeframe: Timeframe

    var body: some View {
        VStack(spacing: 2) {
            Text(PriceFeed.symbol).font(.open(13, .heavy)).tracking(1).foregroundStyle(Theme.muted)
            Text(price.map(money) ?? "—").font(.open(40, .heavy)).tracking(-1.5).monospacedDigit()
                .foregroundStyle(Theme.fg).contentTransition(.numericText()).animation(.snappy, value: price)
            Group {
                if let b = held {
                    HStack(spacing: 10) {
                        Text(Date(timeIntervalSince1970: b.t).formatted(timeframe.seconds >= 86_400
                            ? .dateTime.day().month(.abbreviated).year() : .dateTime.day().month(.abbreviated).hour().minute()))
                        Text("O \(money(b.o))  H \(money(b.h))  L \(money(b.l))  C \(money(b.c))").monospacedDigit()
                    }.foregroundStyle(Theme.muted)
                } else if let price, let dayOpen, dayOpen > 0 {
                    let d = price - dayOpen, sign = d >= 0 ? "+" : "−"
                    HStack(spacing: 8) {
                        Text("\(sign)\(money(abs(d)))")
                        Text("\(sign)\((abs(d) / dayOpen * 100).formatted(.number.precision(.fractionLength(2))))%")
                    }
                    .foregroundStyle(d >= 0 ? up : down).monospacedDigit()
                } else { Text(" ") }
            }.font(.open(13.5, .bold))
        }
        .frame(maxWidth: .infinity)
    }

    private func money(_ v: Double) -> String { v.formatted(.number.locale(Locale(identifier: "en_US")).precision(.fractionLength(2))) }
}

struct TimeframePill: View {
    @Binding var selection: Timeframe
    @Namespace private var pill

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Timeframe.allCases) { tf in
                Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { selection = tf } } label: {
                    Text(tf.label).font(.open(14, tf == selection ? .bold : .semibold))
                        .foregroundStyle(tf == selection ? Theme.fg : Theme.muted)
                        .frame(maxWidth: .infinity).frame(height: 34)
                        .background {
                            if tf == selection {
                                Capsule().fill(Theme.bg).shadow(color: .black.opacity(0.08), radius: 3, y: 1)
                                    .matchedGeometryEffect(id: "pill", in: pill)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Theme.mutedBg, in: Capsule())
    }
}

struct SniperStrip: View {
    let sniper: Sniper
    let up: Color, down: Color
    let pick: (Timeframe) -> Void

    var body: some View {
        switch sniper {
        case .locked:
            Label("Gold Sniper is on paid plans", systemImage: "lock.fill")
                .font(.open(13.5, .semibold)).foregroundStyle(Theme.muted)
        case .off:
            HStack(spacing: 8) {
                (Text("Gold Sniper").fontWeight(.bold).foregroundColor(Theme.fg) + Text(" works on the 1h and 4h charts"))
                    .font(.open(13.5)).foregroundStyle(Theme.muted)
                ForEach([Timeframe.h1, .h4]) { tf in
                    Button(tf.label) { pick(tf) }.font(.open(13, .bold)).foregroundStyle(Theme.primary)
                        .padding(.horizontal, 10).padding(.vertical, 4).background(Theme.primarySoft, in: Capsule())
                }
            }
        case .working(let w):
            VStack(spacing: 8) {
                HStack(spacing: 7) {
                    Circle().fill(w.panel.direction == .buy ? up : w.panel.direction == .sell ? down : Theme.muted).frame(width: 8, height: 8)
                    Text("Gold Sniper").font(.open(14, .bold)).foregroundStyle(Theme.fg)
                    Text("·").foregroundStyle(Theme.muted)
                    Text(SniperPanel.say(w.panel.state)).font(.open(14)).foregroundStyle(Theme.fg)
                }
                .id(w.panel.state).transition(.opacity)
                if w.panel.direction != nil {
                    HStack(spacing: 8) {
                        cell("Entry", w.panel.entry); cell("Stop", w.panel.stop); cell("Target", w.panel.target)
                    }
                }
                if w.record {
                    Text("Staff only: past \(w.panel.trades) trades, \(w.panel.winRate.map { "\(Int($0.rounded()))%" } ?? "none") won, profit factor \(num(w.panel.profitFactor))")
                        .font(.open(11.5)).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
                }
                if let live = w.live {
                    Text(liveLine(live)).font(.open(11.5)).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
                }
            }
        }
    }

    private func cell(_ label: String, _ value: Double?) -> some View {
        VStack(spacing: 1) {
            Text(label.uppercased()).font(.open(9, .heavy)).tracking(0.5).foregroundStyle(Theme.muted)
            Text(num(value)).font(.open(13, .bold)).foregroundStyle(Theme.fg).monospacedDigit()
        }
        .frame(maxWidth: .infinity).padding(.vertical, 7)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
    }

    private func num(_ v: Double?) -> String { v.map { $0.formatted(.number.precision(.fractionLength(2)).grouping(.never)) } ?? "—" }

    private func liveLine(_ l: SniperLive) -> String {
        let since = l.since.flatMap(JSON.parseDate).map { "Live since \($0.formatted(.dateTime.day().month(.abbreviated))): " } ?? "Live record: "
        if l.calls == 0 { return since + (l.since == nil ? "starts with the next call" : "no calls yet") }
        let r = (l.netR >= 0 ? "+" : "") + l.netR.formatted(.number.precision(.fractionLength(1)))
        return since + "\(l.calls) \(l.calls == 1 ? "call" : "calls"), \(l.wins) won of \(l.closed) closed, \(r)R"
    }
}

struct SignalChips: View {
    let signals: [ChartSignal]
    let picked: String?
    let up: Color, down: Color
    let pick: (String) -> Void

    var body: some View {
        if signals.count == 1, let s = signals.first {
            card(s, on: false).padding(.horizontal, 16)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(signals) { s in
                        Button { pick(s.id) } label: { card(s, on: s.id == (picked ?? signals.first?.id)) }
                            .buttonStyle(.plain)
                            .containerRelativeFrame(.horizontal) { w, _ in w * 0.82 }
                    }
                }.scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .contentMargins(.horizontal, 16, for: .scrollContent)
        }
    }

    private func card(_ s: ChartSignal, on: Bool) -> some View {
        HStack(spacing: 10) {
            Text(s.side == .buy ? "BUY" : "SELL").font(.open(11, .heavy)).tracking(0.7).foregroundStyle(.white)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(s.side == .buy ? up : down, in: RoundedRectangle(cornerRadius: 8))
            Text(s.entry.formatted(.number.locale(Locale(identifier: "en_US")).precision(.fractionLength(2))))
                .font(.open(15.5, .heavy)).foregroundStyle(Theme.fg).monospacedDigit()
            Spacer(minLength: 8)
            Text(s.room).font(.open(12.5)).foregroundStyle(Theme.muted).lineLimit(1)
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(on ? Theme.primary : Theme.borderSoft, lineWidth: on ? 1.5 : 1))
    }
}
