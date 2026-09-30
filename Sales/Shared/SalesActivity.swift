import ActivityKit
import Foundation

struct SalesActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var todayCents: Int
        var orders: Int
        var sent: Int
        var total: Int
        var startsAt: Date
        var endsAt: Date
    }
    var store: String
}
