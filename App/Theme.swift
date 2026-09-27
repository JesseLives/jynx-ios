import SwiftUI

enum Appearance: String, CaseIterable, Identifiable {
    case light, dark, system
    var id: String { rawValue }
    var scheme: ColorScheme? { self == .light ? .light : self == .dark ? .dark : nil }
    var label: String { rawValue.capitalized }
}

enum Theme {
    static let fg = pair(0x0f1419, 0xe7e9ea), muted = pair(0x536471, 0x72767a)
    static let card = pair(0xf7f8f8, 0x17181c), raised = pair(0xf7f9fa, 0x22303c)
    static let border = pair(0xe1eaef, 0x242628), bg = pair(0xffffff, 0x000000)
    static let primary = pair(0x1e9df1, 0x1c9cf0), up = pair(0x00a36d, 0x00b87a)
    static let down = pair(0xe0245e, 0xf4212e), wait = pair(0xb7791f, 0xf7b928)

    static func pair(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? rgb(dark) : rgb(light) })
    }
    private static func rgb(_ v: UInt32) -> UIColor {
        UIColor(red: CGFloat(v >> 16 & 0xff) / 255, green: CGFloat(v >> 8 & 0xff) / 255, blue: CGFloat(v & 0xff) / 255, alpha: 1)
    }
}

extension Font {
    static func open(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom("Open Sans", size: size).weight(weight)
    }
}
