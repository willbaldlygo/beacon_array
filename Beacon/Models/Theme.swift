import SwiftUI

// MARK: - Design System

enum AppTheme {
    static let background = Color(hex: "fdf8f8")
    static let surface = Color(hex: "fdf8f8")
    static let surfaceDim = Color(hex: "ddd9d8")
    static let surfaceBright = Color(hex: "fdf8f8")
    static let surfaceContainerLowest = Color(hex: "ffffff")
    static let surfaceContainerLow = Color(hex: "f7f3f2")
    static let surfaceContainer = Color(hex: "f1edec")
    static let surfaceContainerHigh = Color(hex: "ebe7e6")
    static let surfaceContainerHighest = Color(hex: "e5e2e1")
    static let onSurface = Color(hex: "1c1b1b")
    static let onSurfaceVariant = Color(hex: "444748")
    
    // Brand Colors
    static let primary = Color(hex: "000000") // Ink Black
    static let onPrimary = Color(hex: "ffffff")
    
    static let secondary = Color(hex: "026a6a") // Teal
    static let onSecondary = Color(hex: "ffffff")
    static let secondaryContainer = Color(hex: "9eeded")
    static let onSecondaryContainer = Color(hex: "0e6e6e")
    
    static let tertiary = Color(hex: "000000")
    static let onTertiary = Color(hex: "ffffff")
    static let tertiaryContainer = Color(hex: "271900")
    static let onTertiaryContainer = Color(hex: "aa7c11")
    
    static let tertiaryFixed = Color(hex: "ffdea7") // Ochre bubble/card fill
    static let tertiaryFixedDim = Color(hex: "f5be53")
    static let onTertiaryFixed = Color(hex: "271900")
    
    static let error = Color(hex: "ba1a1a") // Red
    static let onError = Color(hex: "ffffff")
    static let errorContainer = Color(hex: "ffdad6")
    static let onErrorContainer = Color(hex: "93000a")
    
    static let outline = Color(hex: "747878")
    static let outlineVariant = Color(hex: "c4c7c7")
    
    // Ink Black borders
    static let ink = Color(hex: "000000")
    static let border: CGFloat = 1.0
    static let radius: CGFloat = 0.0 // Strict 0px radius (sharp corners)
}

struct MondrianFont {
    static func headlineLg(size: CGFloat = 24) -> Font {
        .system(size: size, weight: .black, design: .monospaced)
    }
    static func headlineMd(size: CGFloat = 18) -> Font {
        .system(size: size, weight: .bold, design: .monospaced)
    }
    static func bodyLg(size: CGFloat = 16) -> Font {
        .system(size: size, weight: .regular, design: .monospaced)
    }
    static func bodyMd(size: CGFloat = 14) -> Font {
        .system(size: size, weight: .regular, design: .monospaced)
    }
    static func labelCaps(size: CGFloat = 12) -> Font {
        .system(size: size, weight: .bold, design: .monospaced)
    }
    static func labelSmallCaps(size: CGFloat = 11) -> Font {
        .system(size: size, weight: .medium, design: .monospaced)
    }
    static func headlineLgMobile(size: CGFloat = 20) -> Font {
        .system(size: size, weight: .black, design: .monospaced)
    }
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
