import SwiftUI

/// 设计系统的基础 tokens — 珊瑚橙主色、玻璃 / 新拟态中性色、阴影与圆角。
/// 视觉语言源自 fly9i 设计系统，为 TravelTranslator 定制。
enum Theme {
    // MARK: - Accent (coral)
    enum Accent {
        static let base = Color(hex: 0xFF4D2E)
        static let soft = Color(hex: 0xFFE6DE)
        static let deep = Color(hex: 0xE0381C)
        static let glow = Color(hex: 0xFF4D2E).opacity(0.35)
        static let gradient = LinearGradient(
            colors: [base, deep],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Semantic colors
    enum Semantic {
        static let success = Color(hex: 0x22A06B)
        static let warning = Color(hex: 0xE8A13A)
        static let danger = Color(hex: 0xE03E3E)
        static let info = Color(hex: 0x3874E0)
    }

    // MARK: - Palette (标注圆点 6 色轮换)
    enum Palette {
        static let colors: [Color] = [
            Color(hex: 0xFF4D2E),
            Color(hex: 0x3874E0),
            Color(hex: 0x22A06B),
            Color(hex: 0xE8A13A),
            Color(hex: 0x7455C8),
            Color(hex: 0xE03E3E)
        ]

        static func color(at index: Int) -> Color {
            colors[((index % colors.count) + colors.count) % colors.count]
        }
    }

    // MARK: - Backgrounds (浅 / 深模式自适应)
    enum BG {
        /// 主背景 · 米白 / 夜色
        static var base: Color {
            Color(light: 0xF2F1EE, dark: 0x0E0F13)
        }
        /// 卡片 / Sheet 背景
        static var elevated: Color {
            Color(light: 0xFBFAF7, dark: 0x1A1B20)
        }
        /// 下沉区（输入区等）
        static var sunken: Color {
            Color(light: 0xEBEAE5, dark: 0x08090C)
        }
    }

    // MARK: - Foreground
    enum FG {
        static var primary: Color { Color(light: 0x111117, dark: 0xF2F1EE) }
        static var secondary: Color { Color(light: 0x464653, dark: 0xB4B4BE) }
        static var tertiary: Color { Color(light: 0x8A8A95, dark: 0x6E6E78) }
        static var quaternary: Color { Color(light: 0xB8B7BF, dark: 0x3E3E48) }
    }

    // MARK: - Chips (提示 / 标签 6 色)
    enum Chip {
        case mint, sky, lilac, peach, sage, vanilla
        var bg: Color {
            switch self {
            case .mint: return Color(light: 0xE7F6EC, dark: 0x153024)
            case .sky: return Color(light: 0xE4F0FB, dark: 0x13243C)
            case .lilac: return Color(light: 0xEFEAFB, dark: 0x241C3A)
            case .peach: return Color(light: 0xFCEBE2, dark: 0x3A1F14)
            case .sage: return Color(light: 0xEDF1E4, dark: 0x23281A)
            case .vanilla: return Color(light: 0xFBF2D9, dark: 0x2E260F)
            }
        }
        var fg: Color {
            switch self {
            case .mint: return Color(light: 0x1E6B45, dark: 0x8FE4B3)
            case .sky: return Color(light: 0x1A4E8C, dark: 0x9EC2F6)
            case .lilac: return Color(light: 0x543E9E, dark: 0xC5B3F0)
            case .peach: return Color(light: 0xA1441E, dark: 0xF4B594)
            case .sage: return Color(light: 0x4C6027, dark: 0xC5D1A0)
            case .vanilla: return Color(light: 0x80601D, dark: 0xE8CC8A)
            }
        }
    }

    // MARK: - Corner radius
    enum Radius {
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 28
    }

    // MARK: - Spacing (4px 基准)
    enum Space {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
    }

    // MARK: - Shadow
    struct ShadowSpec {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }
    enum Shadow {
        /// 新拟态柔阴影
        static let soft = ShadowSpec(color: Color.black.opacity(0.06), radius: 24, x: 0, y: 8)
        static let float = ShadowSpec(color: Color.black.opacity(0.12), radius: 48, x: 0, y: 16)
        static let accent = ShadowSpec(color: Accent.glow, radius: 28, x: 0, y: 8)
    }
}

// MARK: - Color helpers

extension Color {
    /// `Color(hex: 0xFF4D2E)` — 方便在 tokens 里写十六进制
    init(hex: UInt32, opacity: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }

    /// 浅 / 深模式自适应配色。
    init(light: UInt32, dark: UInt32) {
        self.init(UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            let r = CGFloat((hex >> 16) & 0xFF) / 255.0
            let g = CGFloat((hex >> 8) & 0xFF) / 255.0
            let b = CGFloat(hex & 0xFF) / 255.0
            return UIColor(red: r, green: g, blue: b, alpha: 1)
        })
    }
}

extension View {
    /// 应用设计系统的标准阴影。
    func designShadow(_ spec: Theme.ShadowSpec) -> some View {
        shadow(color: spec.color, radius: spec.radius, x: spec.x, y: spec.y)
    }
}
