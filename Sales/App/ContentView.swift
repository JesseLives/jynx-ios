import AVFoundation
import SwiftUI
import UIKit

private enum Palette {
    static let card = Color(white: 0.11)
    static let field = Color(white: 0.16)
    static let line = Color.white.opacity(0.07)
    static let muted = Color(white: 0.62)
    static let blue = Color(red: 0.36, green: 0.66, blue: 1.0)
    static let start = Color(red: 0.45, green: 0.72, blue: 1.0)
}

struct ContentView: View {
    @State private var s = Settings.load()
    @StateObject private var runner = Runner()
    @State private var player: AVAudioPlayer?
    @FocusState private var typing: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 16) {
                    preview
                    textCard
                    saleCard
                    whenCard
                    if s.when == .tenMinutes {
                        rateCard
                        pacingCard
                    }
                    soundCard
                    startButton
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Color.black.ignoresSafeArea())
        .foregroundStyle(.white)
        .onChange(of: s) { _, new in new.save() }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { typing = false }
            }
        }
    }

    // MARK: - Header and preview

    private var header: some View {
        HStack(spacing: 4) {
            Text("$")
                .font(.system(size: 26, weight: .black))
                .foregroundStyle(.black)
                .frame(width: 32, height: 36)
                .background(RoundedRectangle(cornerRadius: 7).fill(.white))
            Text("SALES").font(.system(size: 30, weight: .black))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private var preview: some View {
        let sale = Sale(order: 7481, items: 1, cents: Int((s.price * 100).rounded()))
        return HStack(spacing: 12) {
            Image("logo").resizable().scaledToFit().frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(fill(s.text.title, sale: sale, store: s.store, product: s.product)).font(.system(size: 16, weight: .semibold)).lineLimit(1)
                Text(fill(s.text.body, sale: sale, store: s.store, product: s.product)).font(.system(size: 15)).foregroundStyle(Color(white: 0.85)).lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color(white: 0.32)))
    }

    // MARK: - Cards

    private var textCard: some View {
        Card("Notification text") {
            Segments(items: [TextMode.preset, .custom], label: { $0 == .preset ? "Presets" : "Custom" }, selected: s.textMode) { s.textMode = $0 }
            if s.textMode == .preset {
                Menu {
                    ForEach(Array(presets.enumerated()), id: \.offset) { i, p in
                        Button("\(p.title)\n\(p.body)") { s.presetIndex = i }
                    }
                } label: {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Choose preset").font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.blue)
                            Text(s.preset.title).font(.system(size: 17, weight: .semibold))
                            Text(s.preset.body).font(.system(size: 16)).foregroundStyle(Palette.muted)
                        }
                        .multilineTextAlignment(.leading)
                        Spacer()
                        Image(systemName: "chevron.down").foregroundStyle(Palette.muted)
                    }
                    .foregroundStyle(.white)
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 14).stroke(Palette.line, lineWidth: 1.5))
                }
            } else {
                Field("Title", text: $s.customTitle).focused($typing)
                Field("Message", text: $s.customBody).focused($typing)
                Text("{order} {amount} {items} {store} {product} are filled in for each sale.")
                    .font(.footnote).foregroundStyle(Palette.muted)
            }
        }
    }

    private var saleCard: some View {
        Card("Sale") {
            NumberRow(label: "Price", value: $s.price, decimals: true).focused($typing)
            NumberRow(label: "Items per order, up to", value: Binding(get: { Double(s.maxItems) }, set: { s.maxItems = max(1, min(20, Int($0))) })).focused($typing)
            Field("Store name", text: $s.store).focused($typing)
            if s.text.body.contains("{product}") || s.text.title.contains("{product}") {
                Field("Product", text: $s.product).focused($typing)
            }
        }
    }

    private var whenCard: some View {
        Card("When to send") {
            Choice(title: "Single notification", note: "One-time ping right now", on: s.when == .single) { s.when = .single }
            Choice(title: "Over 10 minutes", note: "Burst spread across 10 minutes", on: s.when == .tenMinutes) { s.when = .tenMinutes }
        }
    }

    private var rateCard: some View {
        Card("Notifications per 10 seconds") {
            NumberRow(label: "Amount", value: Binding(get: { Double(s.perTenSeconds) }, set: { s.perTenSeconds = max(1, min(Limits.maxPerTenSeconds, Int($0))) }))
                .focused($typing)
            Text("Up to 500 per 10 sec · 5,000 max per session").font(.subheadline).foregroundStyle(Palette.muted)
            Text("\(sessionCount(perTenSeconds: s.perTenSeconds).formatted()) notifications over 10 minutes").font(.subheadline).foregroundStyle(Palette.muted)
        }
    }

    private var pacingCard: some View {
        Card("Pacing") {
            Choice(title: "Linear", note: "Even spacing between each notification", on: s.pacing == .linear) { s.pacing = .linear }
            Choice(title: "Variable ratio", note: "Unpredictable bursts — sometimes more, sometimes none", on: s.pacing == .variable) { s.pacing = .variable }
        }
    }

    private var soundCard: some View {
        Card("Sound") {
            ForEach(NotificationSound.allCases) { sound in
                Button {
                    s.sound = sound
                    play(sound)
                } label: {
                    HStack {
                        Text(sound.label).font(.system(size: 17))
                        Spacer()
                        if s.sound == sound { Image(systemName: "checkmark").font(.system(size: 18, weight: .semibold)).foregroundStyle(Palette.blue) }
                    }
                    .contentShape(Rectangle())
                    .padding(.vertical, 8)
                }
                .foregroundStyle(.white)
            }
        }
    }

    @ViewBuilder private var startButton: some View {
        if runner.running {
            VStack(spacing: 10) {
                ProgressView(value: Double(runner.sent), total: Double(max(1, runner.total))).tint(Palette.start)
                Text("Sent \(runner.sent.formatted()) of \(runner.total.formatted())").font(.subheadline).foregroundStyle(Palette.muted)
                BigButton(title: "Stop", color: Color(red: 1, green: 0.27, blue: 0.3)) { runner.stop() }
            }
        } else {
            BigButton(title: "Start", color: Palette.start) {
                typing = false
                Task { await runner.start(s) }
            }
        }
        if let p = runner.problem { Text(p).font(.subheadline).foregroundStyle(.orange).multilineTextAlignment(.center) }
        Button("Clear shown notifications") { runner.clearShown() }
            .font(.subheadline).foregroundStyle(Palette.muted)
    }

    // MARK: - Actions

    private func play(_ sound: NotificationSound) {
        guard let url = Sounds.url(sound) else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
        player = try? AVAudioPlayer(contentsOf: url)
        player?.play()
    }
}

// MARK: - Pieces

private struct Card<Content: View>: View {
    let title: String
    let content: Content
    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title.uppercased()).font(.system(size: 15, weight: .bold)).kerning(1.2).foregroundStyle(Palette.muted)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Palette.card))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Palette.line, lineWidth: 1))
    }
}

private struct Segments<T: Hashable>: View {
    let items: [T]
    let label: (T) -> String
    let selected: T
    let pick: (T) -> Void
    var body: some View {
        HStack(spacing: 4) {
            ForEach(items, id: \.self) { item in
                Button { pick(item) } label: {
                    Text(label(item))
                        .font(.system(size: 17, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(item == selected ? Color(white: 0.3) : .clear))
                        .foregroundStyle(item == selected ? .white : Color(white: 0.75))
                }
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(Palette.field))
    }
}

private struct Choice: View {
    let title: String
    let note: String
    let on: Bool
    let pick: () -> Void
    var body: some View {
        Button(action: pick) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 18, weight: .semibold))
                    Text(note).font(.system(size: 15)).foregroundStyle(Palette.muted)
                }
                .multilineTextAlignment(.leading)
                Spacer()
                if on { Image(systemName: "checkmark.circle.fill").font(.system(size: 22)).foregroundStyle(.white, Palette.blue) }
            }
            .contentShape(Rectangle())
            .padding(.vertical, 6)
        }
        .foregroundStyle(.white)
    }
}

private struct Field: View {
    let label: String
    @Binding var text: String
    init(_ label: String, text: Binding<String>) {
        self.label = label
        self._text = text
    }
    var body: some View {
        HStack {
            Text(label).foregroundStyle(Palette.muted)
            TextField(label, text: $text).multilineTextAlignment(.trailing).font(.system(size: 17, weight: .semibold))
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.field))
    }
}

private struct NumberRow: View {
    let label: String
    @Binding var value: Double
    var decimals = false
    var body: some View {
        HStack {
            Text(label).font(.system(size: 18)).foregroundStyle(Palette.muted)
            TextField("0", value: $value, format: decimals ? .number.precision(.fractionLength(2)) : .number.precision(.fractionLength(0)))
                .keyboardType(decimals ? .decimalPad : .numberPad)
                .multilineTextAlignment(.trailing)
                .font(.system(size: 22, weight: .bold))
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.field))
    }
}

private struct BigButton: View {
    let title: String
    let color: Color
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 22, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 22)
                .background(Capsule().fill(color))
                .foregroundStyle(.white)
        }
    }
}
