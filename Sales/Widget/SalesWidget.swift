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
                    HStack(spacing: 8) {
                        LiveLogo(size: 26)
                        Text("Total sales").font(.system(size: 13, weight: .medium)).foregroundStyle(.secondary)
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.orders.formatted()) orders").font(.system(size: 13, weight: .medium)).foregroundStyle(.secondary)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(money(context.state.todayCents)).font(.system(size: 28, weight: .bold)).monospacedDigit()
                            .lineLimit(1).minimumScaleFactor(0.6).contentTransition(.numericText())
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                LiveLogo(size: 22)
            } compactTrailing: {
                Text(shortMoney(context.state.todayCents)).font(.system(size: 14, weight: .semibold)).monospacedDigit()
            } minimal: {
                LiveLogo(size: 22)
            }
        }
    }
}
