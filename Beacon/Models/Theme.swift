import SwiftUI

// MARK: - Design System

enum AppTheme {
    static let background = Color(hex: "F9F9F7") // Warm Paper
    static let ink = Color(hex: "1A1A1A")        // Deep Charcoal
    static let paper = Color(hex: "FFFFFF")      // Pure White (Elements on Background)
    static let accentRed = Color(hex: "C4443B")  // Satellite A: Terracotta Red
    static let accentBlue = Color(hex: "09737D") // Satellite B: Teal
    static let accentOchre = Color(hex: "DCA545") // Core: Yellow Ochre

    static let border: CGFloat = 1.0
    static let radius: CGFloat = 0.0 // Sharp corners for Mondrian look
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
