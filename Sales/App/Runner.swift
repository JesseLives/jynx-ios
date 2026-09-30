import AVFoundation
import SalesKit
import UIKit
import UserNotifications

@MainActor
final class Runner: ObservableObject {
    @Published private(set) var session: Session?
    @Published private(set) var today = Storage.today
    @Published var problem: String?
    @Published var notificationsOff = false

    private let window = 60
    private var scheduledUpTo = 0
    private var starting = false
    private var timer: Timer?
    private var keepAwake: AVAudioPlayer?
    private var lastSaved = Date.distantPast
    private let live = LiveTotal()
    private let center = UNUserNotificationCenter.current()

    init() {
        NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            let ended = (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt) == AVAudioSession.InterruptionType.ended.rawValue
            if ended { Task { @MainActor in self?.resumeAudio() } }
        }
        NotificationCenter.default.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.session != nil else { return }
                self.keepAwake = nil
                self.stayAwake()
            }
        }
    }

    var running: Bool { session != nil }

    // MARK: - Start, resume, stop

    func start(_ s: Settings) async {
        guard session == nil, !starting else { return }
        starting = true
        defer { starting = false }
        problem = nil
        guard await allowed() else { return }
        let now = Date()
        var at = now.addingTimeInterval(1)
        if s.startLater {
            guard s.startAt > now.addingTimeInterval(5) else {
                problem = "That start time has passed. Pick a time later today or turn off \"Start at a set time\"."
                return
            }
            at = s.startAt
        }
        var rng = SystemRandomNumberGenerator()
        let base = s.badge ? Storage.badge : 0
        let new = Session(settings: s, start: at, firstOrder: Storage.takeOrders(s.count), badgeBase: base, rng: &rng)
        center.removeAllPendingNotificationRequests()
        session = new
        scheduledUpTo = 0
        Storage.scheduledUpTo = 0
        save(force: true)
        if s.length != .now || s.startLater { stayAwake() }
        if s.liveActivity { live.start(store: s.store, state: liveState(new)) }
        refill()
        startTimer()
    }

    func resume() async {
        guard session == nil, var s = Storage.session else { return }
        let sentBefore = Storage.scheduledUpTo
        for f in s.advance(to: Date(), sentBelow: sentBefore) { today.add(f.sale, at: f.at) }
        Storage.today = today
        if s.finished {
            session = s
            finish()
            return
        }
        center.removeAllPendingNotificationRequests()
        session = s
        scheduledUpTo = s.counted
        Storage.scheduledUpTo = s.counted
        save(force: true)
        stayAwake()
        if s.settings.liveActivity {
            live.adopt()
            live.update(liveState(s))
        }
        refill()
        startTimer()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        center.removeAllPendingNotificationRequests()
        if var s = session {
            for f in s.advance(to: Date(), sentBelow: scheduledUpTo) { today.add(f.sale, at: f.at) }
            session = s
        }
        finish()
    }

    func clearShown() {
        center.removeAllDeliveredNotifications()
        center.setBadgeCount(0)
        Storage.badge = 0
        guard var s = session else { return }
        s.badgeBase = -s.counted
        session = s
        center.removeAllPendingNotificationRequests()
        scheduledUpTo = s.counted
        Storage.scheduledUpTo = s.counted
        save(force: true)
        refill()
    }

    func resetToday() {
        today = Today(day: Today.key(Date()))
        Storage.today = today
        if let s = session { live.update(liveState(s)) }
    }

    func appeared() {
        tick()
    }

    // MARK: - The loop

    private func startTimer() {
        timer?.invalidate()
        let t = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func tick() {
        guard var s = session else { return }
        let fired = s.advance(to: Date(), sentBelow: scheduledUpTo)
        if !fired.isEmpty {
            for f in fired { today.add(f.sale, at: f.at) }
            if s.settings.badge { Storage.badge = s.badge(s.counted - 1) }
            session = s
            save()
            if s.settings.liveActivity { live.update(liveState(s)) }
        }
        live.flush()
        if s.finished {
            finish()
        } else {
            refill()
        }
    }

    private func refill() {
        guard let s = session else { return }
        let now = Date()
        let upTo = min(s.total, s.counted + window)
        while scheduledUpTo < upTo {
            let i = scheduledUpTo
            let content = UNMutableNotificationContent()
            content.title = s.title(i)
            content.body = s.body(i)
            content.sound = s.settings.sound.file.map { UNNotificationSound(named: UNNotificationSoundName($0)) } ?? .default
            if s.settings.badge { content.badge = NSNumber(value: s.badge(i)) }
            content.threadIdentifier = "orders"
            content.interruptionLevel = .active
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(0.1, s.fireDate(i).timeIntervalSince(now)), repeats: false)
            center.add(UNNotificationRequest(identifier: "\(s.id.uuidString)-\(i)", content: content, trigger: trigger))
            scheduledUpTo += 1
        }
        Storage.scheduledUpTo = scheduledUpTo
    }

    private func finish() {
        timer?.invalidate()
        timer = nil
        if let s = session { live.end(liveState(s)) }
        keepAwake?.stop()
        keepAwake = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        session = nil
        Storage.session = nil
        Storage.scheduledUpTo = 0
        Storage.today = today
    }

    private func save(force: Bool = false) {
        guard force || Date().timeIntervalSince(lastSaved) >= 1 else { return }
        lastSaved = Date()
        Storage.session = session
        Storage.today = today
    }

    func saveNow() { save(force: true) }

    private func liveState(_ s: Session) -> SalesActivityAttributes.ContentState {
        let t = today.shown(at: Date())
        return .init(todayCents: t.cents, orders: t.orders, sent: s.delivered, total: s.total, startsAt: s.start, endsAt: s.end)
    }

    // MARK: - Permission and staying awake

    private func allowed() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            notificationsOff = false
            return true
        case .notDetermined:
            let ok = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            notificationsOff = !ok
            if !ok { problem = "Notifications are off for this app, so nothing would show." }
            return ok
        default:
            notificationsOff = true
            problem = "Notifications are off for this app, so nothing would show."
            return false
        }
    }

    private func stayAwake() {
        guard keepAwake == nil else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            let player = try AVAudioPlayer(data: Sounds.silence)
            player.numberOfLoops = -1
            player.volume = 0
            player.play()
            keepAwake = player
        } catch {
            problem = "Couldn't keep running in the background. Keep the app open until the session ends."
        }
    }

    private func resumeAudio() {
        guard session != nil else { return }
        try? AVAudioSession.sharedInstance().setActive(true)
        if keepAwake?.play() != true {
            keepAwake = nil
            stayAwake()
        }
    }
}
