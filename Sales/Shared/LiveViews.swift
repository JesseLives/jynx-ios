import SalesKit
import SwiftUI

struct LockScreenTotal: View {
    let state: SalesActivityAttributes.ContentState
    let store: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                LiveLogo(size: 22)
                Text(storeName).font(.system(size: 15, weight: .semibold)).lineLimit(1)
                Spacer()
                Text("Today").font(.system(size: 14, weight: .medium)).foregroundStyle(.white.opacity(0.6))
            }
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total sales").font(.system(size: 14, weight: .medium)).foregroundStyle(.white.opacity(0.6))
                    Text(money(state.todayCents))
                        .font(.system(size: 34, weight: .bold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .contentTransition(.numericText())
                }
                Spacer(minLength: 12)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Orders").font(.system(size: 14, weight: .medium)).foregroundStyle(.white.opacity(0.6))
                    Text(state.orders.formatted()).font(.system(size: 22, weight: .bold)).monospacedDigit()
                        .contentTransition(.numericText())
                }
            }
        }
        .foregroundStyle(.white)
        .padding(16)
    }

    private var storeName: String {
        let s = store.trimmingCharacters(in: .whitespacesAndNewlines)
        return s.isEmpty ? "Shopify" : s
    }
}

struct LiveLogo: View {
    let size: CGFloat
    var body: some View {
        Image("bag").resizable().scaledToFit().frame(width: size, height: size)
    }
}

struct LivePreview: View {
    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(colors: [Color(red: 0.12, green: 0.2, blue: 0.4), Color(red: 0.35, green: 0.2, blue: 0.45)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 10) {
                Text("Wednesday 30 September").font(.system(size: 20, weight: .semibold)).foregroundStyle(.white.opacity(0.85)).padding(.top, 60)
                Text("9:41").font(.system(size: 88, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.9))
                Spacer()
                LockScreenTotal(state: .init(todayCents: 194_470, orders: 61, sent: 61, total: 600, startsAt: .now, endsAt: .now), store: "Dopamine ")
                    .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color.black.opacity(0.85)))
                    .padding(.horizontal, 12)
                    .padding(.bottom, 60)
                    .accessibilityIdentifier("livePreview")
            }
        }
    }
}
