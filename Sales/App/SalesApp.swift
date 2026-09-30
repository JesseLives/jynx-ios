import SwiftUI
import UserNotifications

@main
struct SalesApp: App {
    @StateObject private var runner: Runner
    @Environment(\.scenePhase) private var phase

    init() {
        if ProcessInfo.processInfo.arguments.contains("-uitest") { Storage.wipe() }   // UI tests start from nothing
        Sounds.install()
        UNUserNotificationCenter.current().delegate = NotificationShower.shared
        _runner = StateObject(wrappedValue: Runner())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(runner)
                .preferredColorScheme(.dark)
                .task { await runner.resume() }
        }
        .onChange(of: phase) { _, now in
            if now == .active { runner.appeared() }
            if now == .background { runner.saveNow() }
        }
    }
}

final class NotificationShower: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationShower()

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound, .badge])
    }
}
