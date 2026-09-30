import ActivityKit
import Foundation

@MainActor
final class LiveTotal {
    private var activity: Activity<SalesActivityAttributes>?
    private var pending: SalesActivityAttributes.ContentState?
    private var lastSent = Date.distantPast

    var enabled: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    func start(store: String, state: SalesActivityAttributes.ContentState) {
        endAll()
        guard enabled else { return }
        activity = try? Activity.request(attributes: SalesActivityAttributes(store: store),
                                         content: ActivityContent(state: state, staleDate: nil), pushType: nil)
        lastSent = Date()
    }

    func adopt() {
        activity = Activity<SalesActivityAttributes>.activities.first
    }

    func update(_ state: SalesActivityAttributes.ContentState) {
        pending = state
        flush()
    }

    func flush() {
        guard let activity, let state = pending, Date().timeIntervalSince(lastSent) >= 1 else { return }
        pending = nil
        lastSent = Date()
        Task { await activity.update(ActivityContent(state: state, staleDate: nil)) }
    }

    func end(_ state: SalesActivityAttributes.ContentState) {
        guard let activity else { return endAll() }
        self.activity = nil
        pending = nil
        Task { await activity.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: .after(Date().addingTimeInterval(15 * 60))) }
    }

    func endAll() {
        activity = nil
        pending = nil
        for a in Activity<SalesActivityAttributes>.activities {
            Task { await a.end(nil, dismissalPolicy: .immediate) }
        }
    }
}
