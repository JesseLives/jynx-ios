import AVFoundation
import UserNotifications

@MainActor
final class Runner: ObservableObject {
    @Published private(set) var running = false
    @Published private(set) var sent = 0
    @Published private(set) var total = 0
    @Published var problem: String?

    private let window = 60
    private var times: [Double] = []
    private var scheduled = 0
    private var started = Date()
    private var order = 0
    private var settings = Settings()
    private var timer: Timer?
    private var keepAwake: AVAudioPlayer?

    func start(_ s: Settings) async {
        let center = UNUserNotificationCenter.current()
        let allowed = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        guard allowed else {
            problem = "Notifications are off for this app. Turn them on in Settings > Notifications."
            return
        }
        problem = nil
        settings = s
        order = Int.random(in: 1_000...9_000)
        var rng = SystemRandomNumberGenerator()
        times = s.when == .single ? [0.5]
            : fireTimes(count: sessionCount(perTenSeconds: s.perTenSeconds), over: Limits.sessionSeconds, pacing: s.pacing, rng: &rng)
        total = times.count
        sent = 0
        scheduled = 0
        started = Date()
        running = true
        if s.when == .tenMinutes { stayAwake() }
        refill()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        keepAwake?.stop()
        keepAwake = nil
        running = false
    }

    func clearShown() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }

    private func tick() {
        let elapsed = Date().timeIntervalSince(started)
        while sent < times.count && times[sent] <= elapsed { sent += 1 }
        if sent >= total {
            stop()
        } else {
            refill()
        }
    }

    private func refill() {
        let elapsed = Date().timeIntervalSince(started)
        let center = UNUserNotificationCenter.current()
        while scheduled < times.count && scheduled - sent < window {
            let content = UNMutableNotificationContent()
            let sale = settings.sale(order: order)
            order += 1
            let text = settings.text
            content.title = fill(text.title, sale: sale, store: settings.store, product: settings.product)
            content.body = fill(text.body, sale: sale, store: settings.store, product: settings.product)
            if let file = settings.sound.file {
                content.sound = UNNotificationSound(named: UNNotificationSoundName(file))
            } else {
                content.sound = .default
            }
            content.interruptionLevel = .active
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(0.05, times[scheduled] - elapsed), repeats: false)
            center.add(UNNotificationRequest(identifier: "sale-\(scheduled)-\(started.timeIntervalSince1970)", content: content, trigger: trigger))
            scheduled += 1
        }
    }

    private func stayAwake() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            let player = try AVAudioPlayer(data: Sounds.silence)
            player.numberOfLoops = -1
            player.volume = 0
            player.play()
            keepAwake = player
        } catch {
            problem = "Couldn't keep running in the background; keep the app open."
        }
    }
}
