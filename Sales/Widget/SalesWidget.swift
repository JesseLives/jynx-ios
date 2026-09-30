import ActivityKit
import SalesKit
import SwiftUI
import WidgetKit

@main
struct SalesWidgets: WidgetBundle {
    var body: some Widget { SalesLiveActivity() }
}

struct SalesLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SalesActivityAttributes.self) { context in
            LockScreenTotal(state: context.state, store: context.attributes.store)
                .activityBackgroundTint(Color.black.opacity(0.85))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Logo(size: 40).padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(money(context.state.todayCents)).font(.title3.bold()).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
                        Text(orders(context.state.orders)).font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressLine(state: context.state).padding(.horizontal, 4)
                }
            } compactLeading: {
                Logo(size: 22)
            } compactTrailing: {
                Text(shortMoney(context.state.todayCents)).font(.caption.bold()).monospacedDigit().foregroundStyle(green)
            } minimal: {
                Logo(size: 22)
            }
        }
    }
}

private let green = Color(red: 0.36, green: 0.75, blue: 0.29)

private func orders(_ n: Int) -> String { n == 1 ? "1 order" : "\(n.formatted()) orders" }

private struct Logo: View {
    let size: CGFloat
    var body: some View {
        Image("logo").resizable().scaledToFit().frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
    }
}

private struct ProgressLine: View {
    let state: SalesActivityAttributes.ContentState
    var body: some View {
        if state.startsAt > Date() {
            Text("Starts at \(state.startsAt.formatted(date: .omitted, time: .shortened))").font(.caption).foregroundStyle(.secondary)
        } else if state.total > 1 {
            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: Double(min(state.sent, state.total)), total: Double(max(1, state.total))).tint(green)
                Text("\(state.sent.formatted()) of \(state.total.formatted()) · ends \(state.endsAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

private struct LockScreenTotal: View {
    let state: SalesActivityAttributes.ContentState
    let store: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Logo(size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.isEmpty ? "Today" : "\(store) · Today").font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                    Text(money(state.todayCents)).font(.system(size: 30, weight: .bold, design: .rounded)).monospacedDigit()
                        .lineLimit(1).minimumScaleFactor(0.6)
                }
                Spacer()
                Text(orders(state.orders)).font(.headline).foregroundStyle(green)
            }
            ProgressLine(state: state)
        }
        .foregroundStyle(.white)
        .padding(16)
    }
}
