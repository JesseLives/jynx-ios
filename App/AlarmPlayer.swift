import AVFoundation
import JynxKit

@MainActor
enum AlarmPlayer {
    private static var player: AVAudioPlayer?
    private static var cache: [Alarm.Sound: Data] = [:]

    static var chosen: Alarm.Sound { Alarm.Sound(rawValue: UserDefaults.standard.string(forKey: "alarm") ?? "") ?? .alarm }

    static func play(_ sound: Alarm.Sound = chosen) {
        guard sound != .off else { return }
        let data = cache[sound] ?? Alarm.wav(sound)
        cache[sound] = data
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
        player = try? AVAudioPlayer(data: data)
        player?.play()
    }
}
