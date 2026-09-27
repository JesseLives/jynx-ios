import SwiftUI
import JynxKit

@MainActor private var finished: [String: Signal] = [:]

struct SignalCardView: View {
    let id: String
    let version: Int
    @Environment(Session.self) private var session
    @State private var signal: Signal?
    @State private var missing = false

    var body: some View {
        Group {
            if let s = signal { card(s) }
            else { Text(missing ? "Signal unavailable." : "Loading signal").font(.open(14)).foregroundStyle(Theme.muted) }
        }
        .task(id: version) {
            if let done = finished[id] { signal = done; return }
            do {
                let s = try await session.api.signal(id: id)
                signal = s
                if s.status != .running { finished[id] = s }
            } catch { session.handle(error); if signal == nil { missing = true } }
        }
    }

    private func headline(_ s: Signal) -> String {
        let side = s.side == .buy ? "BUY" : "SELL"
        let tail = s.status == .closed ? ", CLOSED" : s.status == .cancelled ? ", CANCELLED" : s.market ? ", MARKET" : ""
        return "\(side) \(s.symbol)\(tail)"
    }

    private func card(_ s: Signal) -> some View {
        let sideColor = s.side == .buy ? Theme.up : Theme.down
        let sl = s.slMovedTo ?? s.sl
        let slLabel = s.slMovedTo == s.entry ? "SL AT ENTRY" : s.slMovedTo != nil ? "SL MOVED" : "STOP"
        let closedPct = Int(((1 - (Double(s.openFraction) ?? 1)) * 100).rounded())
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: s.side == .buy ? "arrow.up.right" : "arrow.down.right").font(.system(size: 13, weight: .bold))
                Text(headline(s)).font(.open(13, .bold))
            }.foregroundStyle(sideColor)
            switch s.status {
            case .closed:
                Text(Format.pips(s.resultPips ?? 0)).font(.open(28, .bold))
                    .foregroundStyle((s.resultPips ?? 0) >= 0 ? Theme.up : Theme.down)
            case .cancelled:
                Text("Cancelled").font(.open(28, .bold)).foregroundStyle(Theme.muted)
            default:
                Text(Format.money(s.entry)).font(.open(28, .bold)).foregroundStyle(Theme.fg).monospacedDigit()
                if s.realizedPips != 0 {
                    Text("Realized \(Format.pips(s.realizedPips))").font(.open(13)).foregroundStyle(Theme.muted)
                }
            }
            HStack(spacing: 8) {
                ForEach(Array(s.tps.enumerated()), id: \.offset) { i, tp in
                    let hit = s.tpHits.contains(i + 1)
                    VStack(alignment: .leading, spacing: 4) {
                        Capsule().fill(hit ? Theme.up : Theme.border).frame(height: 4)
                        Text("TP\(i + 1)").font(.open(11, .bold)).foregroundStyle(hit ? Theme.up : Theme.muted)
                        Text(Format.money(tp)).font(.open(13, .semibold)).foregroundStyle(Theme.fg).monospacedDigit()
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            HStack {
                level(s.market ? "ENTRY (MKT)" : "ENTRY", Format.money(s.entry))
                level(slLabel, Format.money(sl))
                level("CLOSED", "\(closedPct)%")
            }
            if !s.note.isEmpty { Text(s.note).font(.open(14)).foregroundStyle(Theme.fg) }
            if s.hasChart {
                AsyncImage(url: session.api.base.appending(path: "api/signals/\(s.id)/chart")) { img in
                    img.resizable().scaledToFit()
                } placeholder: { Theme.card.frame(height: 160) }
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(14).frame(maxWidth: 340, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.border))
        .opacity(s.status == .running ? 1 : 0.85)
    }

    private func level(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.open(10, .bold)).foregroundStyle(Theme.muted)
            Text(value).font(.open(14, .semibold)).foregroundStyle(Theme.fg).monospacedDigit()
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
