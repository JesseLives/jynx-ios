import SwiftUI
import JynxKit

struct CopierView: View {
    @Environment(Session.self) private var session
    @State private var state: CopierState?
    @State private var error: String?
    @State private var busy = false
    @State private var flips = 0
    @State private var buying = false
    @State private var confirmDisconnect = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    PageTitle(text: "Copier")
                    if let state { content(state) }
                    else if let error { Text(error).font(.open(15)).foregroundStyle(Theme.muted).padding(.top, 40) }
                    else { ProgressView().padding(.top, 60) }
                }
                .padding(.horizontal, 16).padding(.bottom, 28)
            }
            .background(Theme.bg)
            .toolbar(.hidden, for: .navigationBar)
            .refreshable { await load() }
            .task(id: state?.account?.status) { await poll() }
            .sheet(isPresented: $buying) { PlansView(startKind: .copier) }
            .confirmationDialog("Disconnect this account?", isPresented: $confirmDisconnect, titleVisibility: .visible) {
                Button("Disconnect", role: .destructive) { Task { await disconnect() } }
            } message: { Text("Open copied trades stay open in MT5.") }
            .sensoryFeedback(.impact(weight: .medium), trigger: flips)
        }
    }

    private func poll() async {
        await load()
        while let s = state?.account?.status, s == .pending || s == .connecting, !Task.isCancelled {
            try? await Task.sleep(for: .seconds(5))
            await load()
        }
    }

    private func load() async {
        do { state = try await session.api.copier(); error = nil }
        catch is CancellationError {
        } catch { session.handle(error); if state == nil { self.error = Copy.error(error) } }
    }

    @ViewBuilder private func content(_ s: CopierState) -> some View {
        let power = CopierPower.of(hasPass: s.hasPass, account: s.account)
        PowerButton(power: power, busy: busy) { Task { await flip() } }
        if let a = s.account {
            if a.status == .error {
                Text(a.lastError ?? "Check the login, password and server.").font(.open(14)).foregroundStyle(Theme.down).multilineTextAlignment(.center)
            }
            if !s.hasPass {
                VStack(spacing: 8) {
                    Text("Your Copier Pass has ended. Open trades are still managed; new signals are not copied.")
                        .font(.open(14)).foregroundStyle(Theme.wait).multilineTextAlignment(.center)
                    if Features.sells { Button("Renew") { buying = true }.font(.open(15, .bold)) }
                }
            }
            if a.status == .online { SizingChips(account: a) { await save($0) } }
            if let error { Text(error).font(.open(14)).foregroundStyle(Theme.down) }
            if !s.copies.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(s.copies.enumerated()), id: \.element.id) { i, c in
                        if i > 0 { Divider().padding(.leading, 70) }
                        CopyRowView(copy: c)
                    }
                }
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.borderSoft))
            }
            Button("Disconnect MT5") { confirmDisconnect = true }
                .font(.open(16, .bold)).foregroundStyle(Theme.down).frame(minHeight: 44)
        } else if s.hasPass {
            ConnectForm { await load() }
        } else if Features.sells {
            PrimaryButton(title: "Get Copier Pass") { buying = true }
        }
    }

    private func flip() async {
        guard let a = state?.account, !busy else { return }
        busy = true
        if await save(CopierSettings(a, enabled: !a.enabled)) { flips += 1 }
        busy = false
    }

    @discardableResult
    private func save(_ next: CopierSettings) async -> Bool {
        error = nil
        do {
            try await session.api.copierSettings(mode: next.mode, fixedLot: next.fixedLot, riskPct: next.riskPct, maxLot: next.maxLot, enabled: next.enabled)
            await load(); return true
        } catch { session.handle(error); self.error = Copy.error(error); return false }
    }

    private func disconnect() async {
        do { try await session.api.disconnectMT5() } catch { session.handle(error); self.error = Copy.error(error) }
        await load()
    }
}

struct CopierSettings {
    var mode: CopierAccount.Mode, fixedLot: Double, riskPct: Double, maxLot: Double, enabled: Bool
    init(_ a: CopierAccount, enabled: Bool? = nil) {
        mode = a.mode; fixedLot = a.fixedLot; riskPct = a.riskPct; maxLot = a.maxLot; self.enabled = enabled ?? a.enabled
    }
}

private struct PowerButton: View {
    let power: CopierPower
    let busy: Bool
    let tap: () -> Void
    @State private var breathe = false
    @State private var spin = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                if power.ring == .on {
                    Circle().fill(Theme.primary.opacity(0.10)).frame(width: 250, height: 250).scaleEffect(breathe ? 1.04 : 0.96)
                    Circle().fill(Theme.primary.opacity(0.16)).frame(width: 222, height: 222)
                }
                Circle().fill(face).frame(width: 196, height: 196)
                    .overlay(Circle().stroke(power.ring == .on ? Color.clear : Theme.border, lineWidth: 1))
                    .shadow(color: power.ring == .on ? Theme.primary.opacity(0.45) : .clear, radius: 24, y: 10)
                if power.ring == .wait {
                    Circle().trim(from: 0, to: 0.28).stroke(Theme.primary, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 210, height: 210).rotationEffect(.degrees(spin ? 360 : 0))
                        .animation(reduceMotion ? nil : .linear(duration: 1.1).repeatForever(autoreverses: false), value: spin)
                        .onAppear { spin = true }
                }
                Image(systemName: "power").font(.system(size: 54, weight: .medium))
                    .foregroundStyle(power.ring == .on ? .white : power.ring == .error ? Theme.down : Theme.muted)
            }
            .frame(width: 256, height: 256)
            .contentShape(Circle())
            .onTapGesture { if power.tappable && !busy { tap() } }
            .opacity(busy ? 0.7 : 1)
            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: power.ring)
            .animation(reduceMotion ? nil : .easeInOut(duration: 2).repeatForever(autoreverses: true), value: breathe)
            .onAppear { breathe = true }
            .accessibilityElement()
            .accessibilityLabel(power.label)
            .accessibilityValue(power.sub ?? "")
            .accessibilityAddTraits(power.tappable ? .isButton : [])
            .accessibilityHint(power.tappable ? (power.ring == .on ? "Stops copying" : "Starts copying") : "")
            Text(power.label).font(.open(26, .heavy)).foregroundStyle(power.ring == .off && !power.tappable ? Theme.muted : Theme.fg)
            if let sub = power.sub { Text(sub).font(.open(15)).foregroundStyle(Theme.muted) }
        }
    }

    private var face: AnyShapeStyle {
        switch power.ring {
        case .on: AnyShapeStyle(RadialGradient(colors: [Color(hex: 0x5cbcf6), Theme.primary, Color(hex: 0x1379c4)],
                                               center: UnitPoint(x: 0.4, y: 0.3), startRadius: 10, endRadius: 140))
        case .error: AnyShapeStyle(Theme.down.opacity(0.12))
        default: AnyShapeStyle(Theme.mutedBg)
        }
    }
}

private struct SizingChips: View {
    let account: CopierAccount
    let save: (CopierSettings) async -> Bool
    @State private var editing: CopierInput.Field?
    @State private var text = ""
    @State private var problem: String?
    @State private var busy = false

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                chip(account.mode == .fixed ? account.fixedLot.formatted(.number.precision(.fractionLength(2))) : "\(account.riskPct.formatted())%",
                     account.mode == .fixed ? "Lot" : "Risk", field: account.mode == .fixed ? .lot : .risk)
                chip(account.maxLot.formatted(.number.precision(.fractionLength(2))), "Max", field: .max)
                Menu {
                    Button("Fixed lot") { Task { var s = CopierSettings(account); s.mode = .fixed; _ = await save(s) } }
                    Button("Risk %") { Task { var s = CopierSettings(account); s.mode = .risk; _ = await save(s) } }
                } label: { chipFace(account.mode == .fixed ? "Fixed" : "Risk", "Size", on: false) }
            }
            if let field = editing {
                VStack(alignment: .leading, spacing: 6) {
                    Text(field == .max ? "Never more than (lot)" : field == .risk ? "Risk per trade (%)" : "Lot per signal")
                        .font(.open(14, .semibold)).foregroundStyle(Theme.fg)
                    HStack(spacing: 10) {
                        TextField(CopierInput.range(field), text: $text).keyboardType(.decimalPad).font(.open(16))
                            .padding(.horizontal, 14).frame(minHeight: 48)
                            .background(Theme.raised, in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border))
                        Button(busy ? "Saving" : "Save") { Task { await submit(field) } }
                            .font(.open(15, .bold)).foregroundStyle(.white).padding(.horizontal, 18).frame(minHeight: 48)
                            .background(Theme.primary, in: Capsule()).disabled(busy)
                    }
                    if let problem { Text(problem).font(.open(13.5)).foregroundStyle(Theme.down) }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.snappy, value: editing)
    }

    private func chip(_ value: String, _ label: String, field: CopierInput.Field) -> some View {
        Button {
            if editing == field { editing = nil; return }
            editing = field; problem = nil
            let v = field == .max ? account.maxLot : field == .risk ? account.riskPct : account.fixedLot
            text = v.formatted(.number.precision(.fractionLength(0...2)).grouping(.never))
        } label: { chipFace(value, label, on: editing == field) }
        .buttonStyle(.plain)
    }

    private func chipFace(_ value: String, _ label: String, on: Bool) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.open(22, .heavy)).foregroundStyle(Theme.fg).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(.open(14)).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, minHeight: 76)
        .background(on ? Theme.primarySoft : Theme.card, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(on ? Theme.primary : Theme.borderSoft, lineWidth: on ? 1.5 : 1))
    }

    private func submit(_ field: CopierInput.Field) async {
        guard let v = CopierInput.value(text, separator: Locale.current.decimalSeparator ?? ".", field: field) else {
            problem = "Use \(CopierInput.range(field))."; return
        }
        var s = CopierSettings(account)
        switch field { case .lot: s.fixedLot = v; case .risk: s.riskPct = v; case .max: s.maxLot = v }
        busy = true
        if await save(s) { editing = nil }
        busy = false
    }
}

private struct CopyRowView: View {
    let copy: CopyRow
    var body: some View {
        HStack(spacing: 14) {
            Text(copy.side == .buy ? "Buy" : "Sell").font(.open(13, .heavy))
                .foregroundStyle(copy.side == .buy ? Theme.up : Theme.down)
                .frame(width: 44, height: 44)
                .background((copy.side == .buy ? Theme.up : Theme.down).opacity(0.14), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 2) {
                Text(copy.symbol).font(.open(16, .bold)).foregroundStyle(Theme.fg)
                Text(copy.reason.map(CopyText.reason) ?? copy.volume.map { "\($0.formatted()) lot" } ?? "")
                    .font(.open(13.5)).foregroundStyle(Theme.muted).lineLimit(2)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(CopyText.status(copy.status)).font(.open(15, .bold))
                    .foregroundStyle(copy.status == .opened ? Theme.up : copy.status == .failed ? Theme.down : Theme.muted)
                Text(copy.createdAt.formatted(.dateTime.day().month(.abbreviated).year())).font(.open(12.5)).foregroundStyle(Theme.muted)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }
}

private struct ConnectForm: View {
    let connected: () async -> Void
    @Environment(Session.self) private var session
    @State private var login = ""
    @State private var password = ""
    @State private var server = ""
    @State private var busy = false
    @State private var error: String?
    @FocusState private var focus: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(spacing: 0) {
                row("Login") { TextField("", text: $login).keyboardType(.numberPad).focused($focus, equals: 0) }
                Divider().padding(.leading, 16)
                row("Password") { SecureField("", text: $password).textContentType(.password).submitLabel(.next).focused($focus, equals: 1).onSubmit { focus = 2 } }
                Divider().padding(.leading, 16)
                row("Server") { TextField("Exness-MT5Real8", text: $server).submitLabel(.go).focused($focus, equals: 2).onSubmit { Task { await submit() } } }
            }
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.borderSoft))
            Text("Use your trading password. MT5 can't withdraw funds.").font(.open(14)).foregroundStyle(Theme.muted)
            if let error { Text(error).font(.open(14)).foregroundStyle(Theme.down) }
            PrimaryButton(title: busy ? "Connecting" : "Connect", busy: busy) { Task { await submit() } }
                .disabled(login.isEmpty || password.isEmpty || server.isEmpty)
        }
    }

    private func row<F: View>(_ label: String, @ViewBuilder field: () -> F) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.open(14, .semibold)).foregroundStyle(Theme.muted)
            field().font(.open(17)).textInputAutocapitalization(.never).autocorrectionDisabled()
        }
        .padding(.horizontal, 16).padding(.vertical, 12).frame(maxWidth: .infinity, alignment: .leading)
    }

    private func submit() async {
        guard !login.isEmpty, !password.isEmpty, !server.isEmpty, !busy else { return }
        busy = true; error = nil
        do {
            try await session.api.connectMT5(login: login.trimmingCharacters(in: .whitespaces), password: password,
                                            server: server.trimmingCharacters(in: .whitespaces))
            password = ""
            await connected()
        } catch {
            session.handle(error)
            self.error = (error as? APIError) == .server(status: 400, code: "invalid", field: nil, message: nil)
                ? "Check the login (numbers only) and the server name." : Copy.error(error)
        }
        busy = false
    }
}
