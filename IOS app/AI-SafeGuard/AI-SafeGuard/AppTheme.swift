import SwiftUI // <--- 就是缺了這句最重要的魔法咒語！

// MARK: - Color Palette
extension Color {
    static let themeBg = Color(hex: "#0B0F19")
    static let themeCard = Color(hex: "#131B2C")
    static let themeBorder = Color(hex: "#1E293B")
    static let themeIndigo = Color(hex: "#6366F1")
    static let themeEmerald = Color(hex: "#10B981")
    static let themeRose = Color(hex: "#F43F5E")
}

// MARK: - Hex Color Initializer
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
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue:  Double(b) / 255, opacity: Double(a) / 255)
    }
}

// MARK: - iOS 26 級別的終極毛玻璃特效 (Glassmorphism)
struct GlassmorphicCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            // 1. 底層深色遮罩，確保文字閱讀性
            .background(Color.themeCard.opacity(0.4))
            // 2. Apple 原生最高級別模糊 (ultraThinMaterial)
            .background(.ultraThinMaterial)
            // 3. 玻璃反光質感 (左上角高光)
            .background(
                LinearGradient(
                    colors: [Color.white.opacity(0.1), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(24) // 更圓潤的科幻感
            // 4. 流光漸層邊框
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.themeIndigo.opacity(0.6),
                                Color.themeBorder.opacity(0.3),
                                Color.themeEmerald.opacity(0.4),
                                Color.themeBorder.opacity(0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            // 5. 加上一點外發光，更有浮空感
            .shadow(color: Color.black.opacity(0.3), radius: 15, x: 0, y: 10)
    }
}

extension View {
    func glassCardStyle() -> some View {
        self.modifier(GlassmorphicCard())
    }
}
