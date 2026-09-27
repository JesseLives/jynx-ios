import SwiftUI
import JynxKit

struct PlansView: View {
    @Environment(Session.self) private var session
    @State private var plans: PlansBody?
    @State private var error: String?
    @State private var kind: ProductKind = .channel
    @State private var picked: String?
    @State private var months: Int?
    @State private var paying: PayOrder?
    var preselect: String? = nil
    var startKind: ProductKind = .channel

    var body: some View {
        NavigationStack {
            Group {
                if let plans { content(plans) }
                else if let error { retry(error) }
                else { ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity) }
            }
            .background(Theme.bg)
            .navigationDestination(item: $paying) { order in PayView(order: order, payment: plans?.payment) }
            .toolbar(.hidden, for: .navigationBar)
            .task { if preselect == nil { kind = startKind }; await load() }
            .refreshable { await load(); await session.refreshMe() }
        }
    }

    private func load() async {
        do {
            let p = try await session.api.plans(); plans = p; error = nil
            if let preselect, let product = p.products.first(where: { $0.id == preselect }) { kind = product.kind; picked = product.id }
        } catch is CancellationError {
        } catch { session.handle(error); if plans == nil { self.error = Copy.error(error) } }
    }

    private func retry(_ message: String) -> some View {
        VStack(spacing: 12) {
            Text(message).font(.open(15)).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
            Button("Try again") { Task { await load() } }.font(.open(15, .semibold))
        }.padding(24).frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder private func content(_ plans: PlansBody) -> some View {
        if Features.sells { shop(plans) } else { owned }
    }

    private var owned: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PageTitle(text: "Plans")
                let subs = session.me?.subscriptions ?? []
                if subs.isEmpty { Text("No active plan.").font(.open(15)).foregroundStyle(Theme.muted) }
                ForEach(subs, id: \.productId) { s in
                    HStack(spacing: 14) {
                        IconTile(symbol: "square.stack.3d.up")
                        VStack(alignment: .leading, spacing: 2) {
                            Text(s.productName).font(.open(17, .bold)).foregroundStyle(Theme.fg)
                            Text("Active until \(s.endsAt.formatted(.dateTime.day().month(.abbreviated).year()))").font(.open(14)).foregroundStyle(Theme.muted)
                        }
                        Spacer()
                    }
                    .padding(16).background(Theme.card, in: RoundedRectangle(cornerRadius: 22))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.borderSoft))
                }
            }.padding(.horizontal, 16)
        }
    }

    @ViewBuilder private func shop(_ plans: PlansBody) -> some View {
        let products = plans.products.filter { $0.kind == kind }
        let product = products.first { $0.id == picked } ?? products.first
        let lengths = product?.lengths ?? []
        let chosen = months.flatMap { lengths.contains($0) ? $0 : nil } ?? lengths.first
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageTitle(text: "Plans", subtitle: "Choose the plan that fits your needs.")
                if plans.products.contains(where: { $0.kind == .copier }) {
                    Segmented(options: [(ProductKind.channel, "Channels"), (.copier, "Copier Pass")], selection: $kind)
                }
                if !products.isEmpty {
                    StepLabel(kind == .copier ? "Choose a pass" : "Choose a channel")
                    VStack(spacing: 10) {
                        ForEach(products) { p in
                            ChannelCard(product: p, selected: p.id == product?.id, active: active(p))
                                .onTapGesture { withAnimation(.snappy) { picked = p.id; months = nil } }
                        }
                    }
                } else {
                    Text("Nothing to buy here yet.").font(.open(15)).foregroundStyle(Theme.muted)
                }
                if Features.sells, let product, !lengths.isEmpty {
                    StepLabel("Choose how long")
                    VStack(spacing: 10) {
                        ForEach(lengths, id: \.self) { m in
                            LengthRow(product: product, months: m, selected: m == chosen, best: m == PlanMath.bestValue(product.prices))
                                .onTapGesture { withAnimation(.snappy) { months = m } }
                        }
                    }
                } else if !Features.sells {
                    Text("Plans are managed on the website.").font(.open(15)).foregroundStyle(Theme.muted)
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 24)
        }
        .safeAreaInset(edge: .bottom) {
            if Features.sells, let product, let chosen, let cents = product.prices[chosen] {
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Total").font(.open(13)).foregroundStyle(Theme.muted)
                        Text(Money.dollars(cents)).font(.open(24, .heavy)).foregroundStyle(Theme.fg).monospacedDigit()
                            .contentTransition(.numericText())
                    }
                    Divider().frame(height: 40)
                    Button { paying = .plan(product, months: chosen) } label: {
                        HStack(spacing: 8) { Text("Continue to payment"); Image(systemName: "arrow.right") }
                            .font(.open(16, .bold)).foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 52)
                            .background(Theme.primary, in: Capsule())
                    }
                }
                .padding(12)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 26))
                .overlay(RoundedRectangle(cornerRadius: 26).stroke(Theme.borderSoft))
                .padding(.horizontal, 16).padding(.bottom, 8)
            }
        }
    }

    private func active(_ p: Product) -> Subscription? { session.me?.subscriptions.first { $0.productId == p.id } }
}

enum PayOrder: Hashable, Identifiable {
    case plan(Product, months: Int)
    case deposit(cents: Int)
    var id: String { switch self { case let .plan(p, m): "\(p.id)-\(m)"; case let .deposit(c): "deposit-\(c)" } }
    var cents: Int { switch self { case let .plan(p, m): p.prices[m] ?? 0; case let .deposit(c): c } }
    static func == (a: PayOrder, b: PayOrder) -> Bool { a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }
}

struct StepLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View { Text(text.uppercased()).font(.open(12.5, .heavy)).tracking(1.6).foregroundStyle(Theme.muted) }
}

struct Segmented<T: Hashable>: View {
    let options: [(T, String)]
    @Binding var selection: T
    @Namespace private var pill
    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.0) { value, label in
                Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { selection = value } } label: {
                    Text(label).font(.open(15, value == selection ? .bold : .semibold))
                        .foregroundStyle(value == selection ? Theme.fg : Theme.muted)
                        .frame(maxWidth: .infinity).frame(height: 44)
                        .background {
                            if value == selection {
                                Capsule().fill(Theme.bg).shadow(color: .black.opacity(0.08), radius: 3, y: 1)
                                    .matchedGeometryEffect(id: "pill", in: pill)
                            }
                        }
                }.buttonStyle(.plain)
            }
        }
        .padding(4).background(Theme.mutedBg, in: Capsule())
        .sensoryFeedback(.selection, trigger: selection)
    }
}

private struct ChannelCard: View {
    let product: Product
    let selected: Bool
    let active: Subscription?
    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 14).fill(Theme.bg).frame(width: 50, height: 50)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.borderSoft))
                .overlay(Image(systemName: product.kind == .copier ? "doc.on.doc" : "chart.line.uptrend.xyaxis")
                    .font(.system(size: 18, weight: .semibold)).foregroundStyle(Theme.primary))
            VStack(alignment: .leading, spacing: 3) {
                Text(product.name).font(.open(17, .bold)).foregroundStyle(Theme.fg).lineLimit(1)
                if let active {
                    Text("Active until \(active.endsAt.formatted(.dateTime.day().month(.abbreviated).year()))")
                        .font(.open(13.5, .semibold)).foregroundStyle(Theme.up)
                } else if let from = PlanMath.cheapestMonthly(product.prices) {
                    (Text("From ") + Text(Money.dollars(from)).fontWeight(.bold).foregroundColor(Theme.fg) + Text(" / month"))
                        .font(.open(14)).foregroundStyle(Theme.muted)
                }
            }
            Spacer(minLength: 8)
            Circle().fill(selected ? Theme.primary : Color.clear).frame(width: 26, height: 26)
                .overlay(Circle().stroke(selected ? Theme.primary : Theme.border, lineWidth: 1.5))
                .overlay(Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(.white).opacity(selected ? 1 : 0))
        }
        .padding(16)
        .background(selected ? Theme.primarySoft : Theme.card, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(selected ? Theme.primary : Theme.borderSoft, lineWidth: selected ? 1.5 : 1))
        .contentShape(Rectangle())
    }
}

private struct LengthRow: View {
    let product: Product
    let months: Int
    let selected: Bool
    let best: Bool
    var body: some View {
        HStack(spacing: 14) {
            Circle().stroke(selected ? Theme.primary : Theme.border, lineWidth: selected ? 7 : 1.5).frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text("\(months) \(months == 1 ? "month" : "months")").font(.open(17, .bold)).foregroundStyle(Theme.fg)
                    if best {
                        Text("Best value").font(.open(12, .bold)).foregroundStyle(Theme.primary)
                            .padding(.horizontal, 8).padding(.vertical, 3).background(Theme.primarySoft, in: RoundedRectangle(cornerRadius: 7))
                    }
                }
                Text("\(Money.dollars(PlanMath.perMonth(product.prices, months))) per month").font(.open(14)).foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 3) {
                Text(Money.dollars(product.prices[months] ?? 0)).font(.open(20, .heavy)).foregroundStyle(Theme.fg).monospacedDigit()
                if let off = PlanMath.percentOff(product.prices, months) {
                    Text("Save \(off)%").font(.open(13.5, .bold)).foregroundStyle(Theme.up)
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 18)
        .background(selected ? Theme.primarySoft : Theme.card, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(selected ? Theme.primary : Theme.borderSoft, lineWidth: selected ? 1.5 : 1))
        .contentShape(Rectangle())
    }
}
