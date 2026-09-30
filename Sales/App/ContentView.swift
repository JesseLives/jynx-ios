import AVFoundation
import SalesKit
import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject private var runner: Runner
    @State private var s = Storage.settings
    @State private var setups = Storage.setups
    @State private var player: AVAudioPlayer?
    @State private var naming = false
    @State private var newName = ""
    @State private var confirmReset = false
    @State private var toast: String?
    @FocusState private var typing: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(spacing: 16) {
                        todayCard
                        if let toast {
                            Text(toast).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.green)
                                .transition(.opacity).accessibilityIdentifier("toast")
                        }
                        preview
                        settingsSections
                            .disabled(runner.running)
                            .opacity(runner.running ? 0.4 : 1)
                        bottom
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                    .animation(.easeOut(duration: 0.2), value: runner.running)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .background(Color.black.ignoresSafeArea())
            .foregroundStyle(.white)
            .toolbar(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { typing = false }
                }
            }
        }
        .onChange(of: s) { _, new in Storage.settings = new }
        .alert("Save setup", isPresented: $naming) {
            TextField("Name, e.g. Drop day", text: $newName)
            Button("Save") { saveSetup() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Saves your text, products, timing and sound under a name.")
        }
        .confirmationDialog("Reset today's total to $0.00?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset", role: .destructive) { runner.resetToday() }
        }
    }

    // MARK: - Header, today, preview

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

    private var todayCard: some View {
        let t = runner.today.shown(at: Date())
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("TODAY").font(.system(size: 15, weight: .bold)).kerning(1.2).foregroundStyle(Palette.muted)
                Spacer()
                Menu {
                    Button { runner.clearShown(); flash("Notifications and badge cleared") } label: { Label("Clear notifications and badge", systemImage: "bell.slash") }
                    Button(role: .destructive) { confirmReset = true } label: { Label("Reset today's total", systemImage: "arrow.counterclockwise") }
                } label: {
                    Image(systemName: "ellipsis.circle").font(.system(size: 22)).foregroundStyle(Palette.muted).frame(width: 44, height: 44)
                }
                .accessibilityIdentifier("todayMenu")
                .accessibilityLabel("More")
            }
            Text(money(t.cents))
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .accessibilityIdentifier("todayTotal")
            Text(t.orders == 1 ? "1 order" : "\(t.orders.formatted()) orders")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Palette.muted)
                .accessibilityIdentifier("todayOrders")
            if let session = runner.session {
                ProgressView(value: Double(session.counted), total: Double(max(1, session.total)))
                    .tint(Palette.green)
                    .padding(.top, 8)
                Text(status(session))
                    .font(.subheadline)
                    .foregroundStyle(Palette.muted)
                    .accessibilityIdentifier("progressText")
                BigButton(title: "Stop", color: Palette.stop, id: "stopButton") { runner.stop() }
                    .padding(.top, 6)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Palette.card))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Palette.line, lineWidth: 1))
        .animation(.snappy, value: runner.today)
    }

    private func status(_ session: Session) -> String {
        let time = Date.FormatStyle(date: .omitted, time: .shortened)
        if session.start > Date() {
            let day = Calendar.current.isDateInToday(session.start) ? "" : " " + session.start.formatted(.dateTime.weekday(.abbreviated))
            return "Starts\(day) at \(session.start.formatted(time)) · \(session.total.formatted()) to send"
        }
        let sent = "Sent \(session.delivered.formatted()) of \(session.total.formatted())"
        return session.total == 1 ? sent : "\(sent) · ends \(session.end.formatted(time))"
    }

    private var preview: some View {
        let product = s.sellable[0]
        let sale = Sale(order: 7481, product: product.shownName, items: 1, cents: product.priceCents)
        return HStack(spacing: 12) {
            Image("logo").resizable().scaledToFit().frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline) {
                    Text(fill(s.text.title, sale: sale, store: s.store)).font(.system(size: 16, weight: .semibold)).lineLimit(1)
                    Spacer(minLength: 4)
                    Text("now").font(.system(size: 13)).foregroundStyle(Color(white: 0.75))
                }
                Text(fill(s.text.body, sale: sale, store: s.store)).font(.system(size: 15)).foregroundStyle(Color(white: 0.88)).lineLimit(2)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color(white: 0.3)))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("preview")
    }

    // MARK: - Settings

    @ViewBuilder private var settingsSections: some View {
        if runner.running {
            Text("Stop the session to change anything below.").font(.subheadline).foregroundStyle(Palette.muted)
        }
        setupsCard
        textCard
        productsCard
        whenCard
        if s.length != .now {
            rateCard
            pacingCard
        }
        soundCard
        extrasCard
    }

    private var setupsCard: some View {
        Card("Setups") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(setups) { setup in
                        Button {
                            s = setup.settings
                            flash("Loaded \(setup.name)")
                        } label: {
                            HStack(spacing: 6) {
                                if setup.settings == s { Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)) }
                                Text(setup.name).lineLimit(1)
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .background(Capsule().fill(setup.settings == s ? Palette.blue.opacity(0.3) : Palette.field))
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button { update(setup) } label: { Label("Update with current", systemImage: "square.and.arrow.down") }
                            Button(role: .destructive) { delete(setup) } label: { Label("Delete", systemImage: "trash") }
                        }
                        .accessibilityIdentifier("setup-\(setup.name)")
                    }
                    Button {
                        newName = ""
                        naming = true
                    } label: {
                        Label("Save current", systemImage: "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .background(Capsule().stroke(Palette.blue, lineWidth: 1.5))
                            .foregroundStyle(Palette.blue)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("saveSetup")
                }
            }
            Text(setups.isEmpty ? "Save what you've set up to switch back to it with one tap." : "Tap to load. Press and hold to update or delete.")
                .font(.footnote).foregroundStyle(Palette.muted)
        }
    }

    private var textCard: some View {
        Card("Notification text") {
            Segments(items: [TextMode.preset, .custom], label: { $0 == .preset ? "Presets" : "Custom" },
                     id: { $0 == .preset ? "textPresets" : "textCustom" }, selected: s.textMode) { s.textMode = $0 }
            if s.textMode == .preset {
                Menu {
                    ForEach(Array(presets.enumerated()), id: \.offset) { i, p in
                        Button { s.presetIndex = i } label: {
                            if i == min(max(0, s.presetIndex), presets.count - 1) {
                                Label(p.title + " · " + p.body, systemImage: "checkmark")
                            } else {
                                Text(p.title + " · " + p.body)
                            }
                        }
                    }
                } label: {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Choose preset").font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.blue)
                            Text(s.text.title).font(.system(size: 17, weight: .semibold))
                            Text(s.text.body).font(.system(size: 16)).foregroundStyle(Palette.muted)
                        }
                        .multilineTextAlignment(.leading)
                        Spacer()
                        Image(systemName: "chevron.down").foregroundStyle(Palette.muted)
                    }
                    .foregroundStyle(.white)
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 14).stroke(Palette.line, lineWidth: 1.5))
                    .contentShape(Rectangle())
                }
                .accessibilityIdentifier("presetMenu")
            } else {
                Field(label: "Title", text: $s.custom.title).focused($typing)
                Field(label: "Message", text: $s.custom.body).focused($typing)
                Text("{order} {amount} {items} {product} {store} are filled in for each sale.")
                    .font(.footnote).foregroundStyle(Palette.muted)
            }
        }
    }

    private var productsCard: some View {
        Card("Products") {
            ForEach($s.products) { $product in
                HStack(spacing: 10) {
                    TextField("Product name", text: $product.name)
                        .font(.system(size: 17, weight: .semibold))
                        .focused($typing)
                        .accessibilityIdentifier("productName")
                    PriceField(cents: $product.priceCents).focused($typing)
                    if s.products.count > 1 {
                        Button {
                            typing = false
                            let id = product.id
                            s.products.removeAll { $0.id == id }
                        } label: {
                            Image(systemName: "minus.circle.fill").font(.system(size: 22)).foregroundStyle(Palette.stop)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove product")
                        .accessibilityIdentifier("removeProduct")
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.field))
            }
            if s.products.count < 20 {
                Button {
                    s.products.append(Product(name: "", priceCents: 2_500))
                } label: {
                    Label("Add product", systemImage: "plus.circle.fill").font(.system(size: 17, weight: .semibold)).foregroundStyle(Palette.blue)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("addProduct")
            }
            if s.products.allSatisfy({ $0.priceCents == 0 }) {
                Text("Every product is $0.00, so sales use $38.99 until you set a price.").font(.footnote).foregroundStyle(.orange)
            }
            Stepper(value: $s.maxItems, in: 1...10) {
                Text(s.maxItems == 1 ? "1 item per order" : "Up to \(s.maxItems) items per order").font(.system(size: 17))
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.field))
            Field(label: "Store name", text: $s.store).focused($typing)
            Text("Each order picks one product at random.").font(.footnote).foregroundStyle(Palette.muted)
        }
    }

    private var whenCard: some View {
        Card("When to send") {
            Segments(items: SessionLength.allCases, columns: 3, label: { $0.label }, id: { "length-\($0.rawValue)" }, selected: s.length) { s.length = $0 }
            Toggle(isOn: Binding(get: { s.startLater }, set: { on in
                s.startLater = on
                if on && s.startAt < Date().addingTimeInterval(60) { s.startAt = nextRoundTime() }
            })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Start at a set time").font(.system(size: 17, weight: .semibold))
                    Text("Leave the app open or in the background").font(.system(size: 14)).foregroundStyle(Palette.muted)
                }
            }
            .tint(Palette.blue)
            .accessibilityIdentifier("startLaterToggle")
            if s.startLater {
                DatePicker("Starts", selection: $s.startAt, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                    .font(.system(size: 17))
                    .accessibilityIdentifier("startAtPicker")
            }
        }
    }

    private var rateCard: some View {
        Card("Notifications per 10 seconds") {
            WholeNumberRow(label: "Amount", value: $s.perTenSeconds, range: 1...Limits.maxPerTenSeconds, id: "rateField").focused($typing)
            Text("Up to 500 per 10 sec · 5,000 max per session").font(.subheadline).foregroundStyle(Palette.muted)
            Text(countLine).font(.subheadline).foregroundStyle(Palette.muted).accessibilityIdentifier("countLine")
        }
    }

    private var countLine: String {
        let uncapped = Double(max(1, s.perTenSeconds)) * s.length.seconds / 10
        let capped = uncapped > Double(Limits.maxPerSession)
        return "\(s.count.formatted()) notifications \(s.length.span)" + (capped ? " (the 5,000 limit)" : "")
    }

    private var pacingCard: some View {
        Card("Pacing") {
            Choice(title: "Linear", note: "Even spacing between each notification", on: s.pacing == .linear) { s.pacing = .linear }
            Choice(title: "Variable ratio", note: "Unpredictable bursts — sometimes more, sometimes none", on: s.pacing == .variable) { s.pacing = .variable }
        }
    }

    private var soundCard: some View {
        Card("Sound") {
            ForEach(SoundChoice.allCases) { sound in
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
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .accessibilityIdentifier("sound-\(sound.rawValue)")
            }
            Text("Tap to hear it. Notifications play it even with the app closed; the ring/silent switch still applies.")
                .font(.footnote).foregroundStyle(Palette.muted)
        }
    }

    private var extrasCard: some View {
        Card("Extras") {
            Toggle(isOn: $s.badge) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Badge on the app icon").font(.system(size: 17, weight: .semibold))
                    Text("The red number counts up with each order").font(.system(size: 14)).foregroundStyle(Palette.muted)
                }
            }
            .tint(Palette.blue)
            Toggle(isOn: $s.liveActivity) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Live total on the lock screen").font(.system(size: 17, weight: .semibold))
                    Text("Today's total and orders, updating as they come in").font(.system(size: 14)).foregroundStyle(Palette.muted)
                }
            }
            .tint(Palette.blue)
        }
    }

    // MARK: - Start

    @ViewBuilder private var bottom: some View {
        if !runner.running {
            BigButton(title: s.startLater ? "Schedule" : "Start", color: Palette.start, id: "startButton") {
                typing = false
                Task { await runner.start(s) }
            }
        }
        if let p = runner.problem {
            VStack(spacing: 10) {
                Text(p).font(.subheadline).foregroundStyle(.orange).multilineTextAlignment(.center)
                if runner.notificationsOff {
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                    .font(.subheadline.weight(.semibold))
                }
            }
            .accessibilityIdentifier("problem")
        }
    }

    // MARK: - Actions

    private func saveSetup() {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        if let i = setups.firstIndex(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            setups[i].settings = s
        } else {
            setups.append(Setup(name: name, settings: s))
        }
        Storage.setups = setups
        flash("Saved \(name)")
    }

    private func update(_ setup: Setup) {
        guard let i = setups.firstIndex(where: { $0.id == setup.id }) else { return }
        setups[i].settings = s
        Storage.setups = setups
        flash("Updated \(setup.name)")
    }

    private func delete(_ setup: Setup) {
        setups.removeAll { $0.id == setup.id }
        Storage.setups = setups
    }

    private func flash(_ text: String) {
        withAnimation { toast = text }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { if toast == text { toast = nil } }
        }
    }

    private func play(_ sound: SoundChoice) {
        guard let url = Sounds.url(sound) else { return }
        if !runner.running { try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers]) }
        player = try? AVAudioPlayer(contentsOf: url)
        player?.play()
    }

    private func nextRoundTime() -> Date {
        let t = Date().addingTimeInterval(3_600).timeIntervalSinceReferenceDate
        return Date(timeIntervalSinceReferenceDate: (t / 300).rounded(.up) * 300)
    }
}
