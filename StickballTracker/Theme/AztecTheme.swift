import SwiftUI

/// Design system: Urban street-style with vibrant neon accents.
/// Deep dark backgrounds, electric neon colors, handwritten-style headers,
/// and a bold, energetic visual language.
enum AztecTheme {
    // MARK: - Colors

    /// Deep dark background
    static let obsidian = Color(red: 0.04, green: 0.04, blue: 0.08)

    /// Dark card backgrounds
    static let darkStone = Color(red: 0.08, green: 0.08, blue: 0.12)

    /// Medium stone - secondary surfaces
    static let stone = Color(red: 0.35, green: 0.35, blue: 0.40)

    /// Neon yellow - primary accent
    static let gold = Color(red: 1.0, green: 0.92, blue: 0.0)

    /// Hot pink/magenta - secondary accent
    static let amber = Color(red: 1.0, green: 0.18, blue: 0.55)

    /// Turquoise - vibrant teal accent
    static let jade = Color(red: 0.0, green: 0.92, blue: 0.82)

    /// Blood red - alerts/destructive
    static let bloodRed = Color(red: 0.90, green: 0.12, blue: 0.15)

    /// Electric blue - accent
    static let cosmic = Color(red: 0.20, green: 0.50, blue: 1.0)

    /// Tennis ball neon green
    static let tennisGreen = Color(red: 0.78, green: 1.0, blue: 0.0)

    /// Light text
    static let lightText = Color(red: 0.95, green: 0.95, blue: 0.95)

    /// Dimmed text
    static let dimText = Color(red: 0.50, green: 0.50, blue: 0.55)

    // MARK: - Gradients

    static let goldGradient = LinearGradient(
        colors: [gold, tennisGreen],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let jadeGradient = LinearGradient(
        colors: [jade, cosmic],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cosmicGradient = LinearGradient(
        colors: [cosmic, Color(red: 0.10, green: 0.25, blue: 0.70)],
        startPoint: .top,
        endPoint: .bottom
    )

    static let pinkGradient = LinearGradient(
        colors: [amber, Color(red: 0.80, green: 0.10, blue: 0.40)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardGradient = LinearGradient(
        colors: [darkStone, obsidian],
        startPoint: .top,
        endPoint: .bottom
    )

    // MARK: - Fonts

    /// Handwritten style font for headers
    static func handwritten(size: CGFloat) -> Font {
        Font.custom("MarkerFelt-Wide", size: size)
    }

    /// Chunky display font for main title
    static func chunky(size: CGFloat) -> Font {
        Font.system(size: size, weight: .black, design: .rounded)
    }

    // MARK: - Decorative Elements

    static var glowingLine: some View {
        Rectangle()
            .fill(goldGradient)
            .shadow(color: gold.opacity(0.6), radius: 4, x: 0, y: 0)
    }

    static var borderLine: some View {
        Rectangle()
            .fill(gold.opacity(0.3))
            .frame(height: 1)
    }

    static var jadeBorderLine: some View {
        Rectangle()
            .fill(jade.opacity(0.3))
            .frame(height: 1)
    }

    // MARK: - Modifiers

    static func glowShadow(color: Color = gold, radius: CGFloat = 8) -> some View {
        Color.clear.shadow(color: color.opacity(0.4), radius: radius)
    }
}

// MARK: - Aztec Card Style

struct AztecCard: ViewModifier {
    var highlight: Color = AztecTheme.gold

    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(AztecTheme.darkStone)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(highlight.opacity(0.25), lineWidth: 1)
            )
    }
}

extension View {
    func aztecCard(highlight: Color = AztecTheme.gold) -> some View {
        modifier(AztecCard(highlight: highlight))
    }
}

// MARK: - Aztec Button Style

struct AztecButtonStyle: ButtonStyle {
    var color: Color = AztecTheme.gold

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .heavy))
            .tracking(2)
            .foregroundColor(AztecTheme.obsidian)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(color)
                    .shadow(color: color.opacity(0.4), radius: configuration.isPressed ? 2 : 6)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct AztecSecondaryButtonStyle: ButtonStyle {
    var color: Color = AztecTheme.gold

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .bold))
            .tracking(1)
            .foregroundColor(color)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(color.opacity(0.5), lineWidth: 1)
                    .background(color.opacity(0.08))
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Aztec Text Field Style

struct AztecTextField: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(AztecTheme.lightText)
            .padding(12)
            .background(AztecTheme.obsidian)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(AztecTheme.gold.opacity(0.3), lineWidth: 1)
            )
    }
}

extension View {
    func aztecTextField() -> some View {
        modifier(AztecTextField())
    }
}
