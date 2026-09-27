import Foundation

public enum Format {
    public static func money(_ s: String) -> String {
        guard let v = Double(s) else { return s }
        return v.formatted(.number.locale(Locale(identifier: "en_US")).precision(.fractionLength(2...5)))
    }

    public static func pips(_ n: Double) -> String {
        let v = n.formatted(.number.locale(Locale(identifier: "en_US")).grouping(.never).precision(.fractionLength(0...1)))
        return "\(n > 0 ? "+" : "")\(v) pips"
    }

    public static func chatTime(_ d: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        var style = Date.FormatStyle(locale: Locale(identifier: "en_GB"), calendar: calendar, timeZone: calendar.timeZone)
        if calendar.isDate(d, inSameDayAs: now) { style = style.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits) }
        else if let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: d), to: calendar.startOfDay(for: now)).day,
                days < 7 { style = style.weekday(.abbreviated) }
        else { style = style.day().month(.abbreviated) }
        return d.formatted(style)
    }

    public static func day(_ d: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: d), to: calendar.startOfDay(for: now)).day ?? 0
        if days == 0 { return "Today" }
        if days == 1 { return "Yesterday" }
        return d.formatted(Date.FormatStyle(locale: Locale(identifier: "en_GB"), calendar: calendar, timeZone: calendar.timeZone)
            .day().month(.abbreviated).year())
    }

    public static func clock(_ d: Date, calendar: Calendar = .current) -> String {
        d.formatted(Date.FormatStyle(locale: Locale(identifier: "en_GB"), calendar: calendar, timeZone: calendar.timeZone)
            .hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
    }
}
