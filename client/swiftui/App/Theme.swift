import SwiftUI

enum AmneziaTheme {
    static let bgBase = Color(hex: "101012")
    static let bgSurface = Color(hex: "18181B")
    static let bgSurfaceAlt = Color(hex: "1F1F23")
    static let bgSheet = Color(hex: "313136")
    static let textPrimary = Color(hex: "FAFAFA")
    static let textSecondary = Color(hex: "E4E4E7")
    static let textTertiary = Color(hex: "A1A1AA")
    static let accentLight = Color(hex: "FDBA74")
    static let accentDefault = Color(hex: "F59E0B")
    static let accentDark = Color(hex: "D97706")
    static let statusDestructive = Color(hex: "F87171")
    static let statusWarning = Color(hex: "EAB308")
    static let statusSuccess = Color(hex: "4ADE80")
    static let borderSoft = Color(hex: "3F3F46")
    static let borderEmphasis = Color(hex: "E4E4E7")

    enum Font {
        static let display = SwiftUI.Font.system(size: 36, weight: .medium)
        static let h1 = SwiftUI.Font.system(size: 30, weight: .bold)
        static let h2 = SwiftUI.Font.system(size: 24, weight: .medium)
        static let h3 = SwiftUI.Font.system(size: 18, weight: .regular)
        static let h3Semibold = SwiftUI.Font.system(size: 18, weight: .semibold)
        static let body = SwiftUI.Font.system(size: 16, weight: .regular)
        static let button = SwiftUI.Font.system(size: 16, weight: .semibold)
        static let small = SwiftUI.Font.system(size: 14, weight: .regular)
        static let caption = SwiftUI.Font.system(size: 12, weight: .regular)
        static let connectButton = SwiftUI.Font.system(size: 20, weight: .bold)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)
        let red = Double((value >> 16) & 0xFF) / 255.0
        let green = Double((value >> 8) & 0xFF) / 255.0
        let blue = Double(value & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue)
    }
}
