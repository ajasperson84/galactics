import SwiftUI

/// Design system: Aztec meets futuristic sci-fi.
/// Deep obsidian backgrounds, glowing gold/teal accents, geometric Aztec patterns,
/// holographic-style borders, and angular futuristic typography.
enum AztecTheme {
    // MARK: - Colors

    /// Deep obsidian black - primary background
    static let obsidian = Color(red: 0.06, green: 0.06, blue: 0.10)

    /// Dark charcoal - card backgrounds
    static let darkStone = Color(red: 0.10, green: 0.10, blue: 0.14)

    /// Medium stone - secondary surfaces
    static let stone = Color(red: 0.40, green: 0.38, blue: 0.35)

    /// Warm gold - primary accent, Aztec-inspired
    static let gold = Color(red: 0.91, green: 0.76, blue: 0.30)

    /// Deep amber - secondary gold accent
    static let amber = Color(red: 0.80, green: 0.55, blue: 0.15)

    /// Turquoise/teal - sci-fi accent, represents jade
    static let jade = Color(red: 0.15, green: 0.85, blue: 0.75)

    /// Blood red - Aztec ceremonial, used for alerts/losses
    static let bloodRed = Color(red: 0.80, green: 0.15, blue: 0.15)

    /// Deep purple - cosmic/mystical accent
    static let cosmic = Color(red: 0.45, green: 0.20, blue: 0.75)

    /// Light text
    static let lightText = Color(red: 0.92, green: 0.90, blue: 0.85)

    /// Dimmed text
    static let dimText = Color(red: 0.55, green: 0.52, blue: 0.48)

    // MARK: - Gradients

    static let goldGradient = LinearGradient(
        colors: [gold, amber],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let jadeGradient = LinearGradient(
        colors: [jade, Color(red: 0.10, green: 0.60, blue: 0.55)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cosmicGradient = LinearGradient(
        colors: [cosmic, Color(red: 0.25, green: 0.10, blue: 0.55)],
        startPoint: .top,
        endPoint: .bottom
    )

    static let cardGradient = LinearGradient(
        colors: [darkStone, obsidian],
        startPoint: .top,
        endPoint: .bottom
    )

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
