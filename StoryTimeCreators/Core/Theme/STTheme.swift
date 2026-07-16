import SwiftUI

enum STColor {
    static let background = Color(red: 0.0, green: 0.0, blue: 0.0)
    static let surface = Color(red: 0.055, green: 0.055, blue: 0.055)
    static let surfaceElevated = Color(red: 0.09, green: 0.09, blue: 0.09)
    static let border = Color.white.opacity(0.12)
    static let primary = Color(red: 0.976, green: 0.451, blue: 0.122) // #F97316
    static let accent = Color(red: 1.0, green: 0.796, blue: 0.404) // #FFCB67
    static let brandDeep = Color(red: 1.0, green: 0.478, blue: 0.0) // #FF7A00
    static let textPrimary = Color(red: 0.96, green: 0.96, blue: 0.97)
    static let textSecondary = Color(red: 0.62, green: 0.64, blue: 0.68)
    static let textMuted = Color(red: 0.45, green: 0.47, blue: 0.51)
    static let danger = Color(red: 0.94, green: 0.33, blue: 0.31)
    static let success = Color(red: 0.30, green: 0.78, blue: 0.47)

    static var brandGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 1.0, green: 0.796, blue: 0.404),
                Color(red: 1.0, green: 0.624, blue: 0.110),
                Color(red: 1.0, green: 0.478, blue: 0.0),
                Color(red: 1.0, green: 0.702, blue: 0.278),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static var orangeGlow: RadialGradient {
        RadialGradient(
            colors: [
                Color(red: 1.0, green: 0.55, blue: 0.15).opacity(0.55),
                Color(red: 0.98, green: 0.45, blue: 0.12).opacity(0.25),
                Color.clear,
            ],
            center: .center,
            startRadius: 20,
            endRadius: 280
        )
    }
}

enum STFont {
    static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static func mono(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

struct GlassPanel: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(STColor.surface.opacity(0.98))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(STColor.border, lineWidth: 1)
                    )
            )
    }
}

extension View {
    func glassPanel() -> some View {
        modifier(GlassPanel())
    }

    func stCardPadding() -> some View {
        padding(16)
    }
}
