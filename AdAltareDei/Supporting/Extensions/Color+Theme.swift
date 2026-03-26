import SwiftUI

extension Color {
    // MARK: - Primary Palette
    static let parchment = Color(hex: "F5F0E8")
    static let ink = Color(hex: "1C1410")
    static let sanctuaryRed = Color(hex: "8B1A1A")
    static let goldLeaf = Color(hex: "B8960C")
    static let warmWhite = Color(hex: "FDFAF4")
    static let vellumDark = Color(hex: "2A2118")
    static let cream = Color(hex: "EDE8DC")

    // MARK: - Semantic Colors
    static let primaryBackground = Color("PrimaryBackground")
    static let primaryText = Color("PrimaryText")
    static let cardSurface = Color("CardSurface")
    static let accent = sanctuaryRed
    static let secondaryAccent = goldLeaf

    // MARK: - Comfort Level Colors
    static let comfortNotStarted = Color.gray.opacity(0.4)
    static let comfortLearning = sanctuaryRed.opacity(0.7)
    static let comfortFamiliar = goldLeaf
    static let comfortMastered = Color(hex: "2E7D32")

    // MARK: - Hex Initializer
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
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

// MARK: - Adaptive Colors (Light/Dark)
extension ShapeStyle where Self == Color {
    static var adaptiveBackground: Color {
        Color("PrimaryBackground")
    }

    static var adaptiveText: Color {
        Color("PrimaryText")
    }

    static var adaptiveCard: Color {
        Color("CardSurface")
    }
}
