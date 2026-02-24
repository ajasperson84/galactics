import SwiftUI

/// Design system: Punk rock xerox aesthetic.
/// White paper backgrounds, black type, highlighter color accents,
/// typewriter body font, Impact headers. Handmade, DIY, high contrast.
enum AztecTheme {
    // MARK: - Colors

    /// Paper white - primary background
    static let obsidian = Color(red: 0.97, green: 0.96, blue: 0.94)

    /// Light warm gray - card backgrounds
    static let darkStone = Color(red: 0.92, green: 0.91, blue: 0.89)

    /// Medium gray - borders, secondary
    static let stone = Color(red: 0.62, green: 0.60, blue: 0.58)

    /// Neon yellow highlighter - primary accent
    static let gold = Color(red: 1.0, green: 0.92, blue: 0.0)

    /// Hot pink highlighter - secondary accent
    static let amber = Color(red: 1.0, green: 0.18, blue: 0.55)

    /// Turquoise highlighter
    static let jade = Color(red: 0.0, green: 0.82, blue: 0.75)

    /// Red - alerts/destructive
    static let bloodRed = Color(red: 0.85, green: 0.10, blue: 0.10)

    /// Electric blue highlighter
    static let cosmic = Color(red: 0.20, green: 0.45, blue: 1.0)

    /// Tennis ball neon green highlighter
    static let tennisGreen = Color(red: 0.55, green: 0.85, blue: 0.0)

    /// Primary text - near black
    static let lightText = Color(red: 0.08, green: 0.08, blue: 0.08)

    /// Secondary text - dark gray
    static let dimText = Color(red: 0.35, green: 0.35, blue: 0.35)

    // MARK: - Ink (pure black for type)
    static let ink = Color.black

    // MARK: - Gradients

    static let goldGradient = LinearGradient(
        colors: [gold, tennisGreen],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let jadeGradient = LinearGradient(
        colors: [jade, cosmic],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let cosmicGradient = LinearGradient(
        colors: [cosmic, Color(red: 0.10, green: 0.25, blue: 0.70)],
        startPoint: .top,
        endPoint: .bottom
    )

    static let pinkGradient = LinearGradient(
        colors: [amber, Color(red: 0.80, green: 0.10, blue: 0.40)],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let cardGradient = LinearGradient(
        colors: [darkStone, obsidian],
        startPoint: .top,
        endPoint: .bottom
    )

    // MARK: - Fonts

    /// Impact font for buttons, menu items, section headers
    static func impact(size: CGFloat) -> Font {
        Font.custom("Impact", size: size)
    }

    /// Typewriter font for non-clickable body copy
    static func typewriter(size: CGFloat) -> Font {
        Font.custom("AmericanTypewriter", size: size)
    }

    /// Bold typewriter
    static func typewriterBold(size: CGFloat) -> Font {
        Font.custom("AmericanTypewriter-Bold", size: size)
    }

    // Keep these as aliases for backward compat
    static func handwritten(size: CGFloat) -> Font {
        impact(size: size)
    }

    static func chunky(size: CGFloat) -> Font {
        impact(size: size)
    }

    // MARK: - Decorative Elements

    static var glowingLine: some View {
        Rectangle()
            .fill(ink)
    }

    static var borderLine: some View {
        Rectangle()
            .fill(ink.opacity(0.2))
            .frame(height: 1)
    }

    static var jadeBorderLine: some View {
        Rectangle()
            .fill(ink.opacity(0.15))
            .frame(height: 1)
    }

    // MARK: - Modifiers

    static func glowShadow(color: Color = ink, radius: CGFloat = 8) -> some View {
        Color.clear.shadow(color: color.opacity(0.1), radius: radius)
    }
}

// MARK: - Card Style

struct AztecCard: ViewModifier {
    var highlight: Color = AztecTheme.gold

    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 2))
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(AztecTheme.ink.opacity(0.15), lineWidth: 1)
            )
    }
}

extension View {
    func aztecCard(highlight: Color = AztecTheme.gold) -> some View {
        modifier(AztecCard(highlight: highlight))
    }
}

// MARK: - Button Styles

struct AztecButtonStyle: ButtonStyle {
    var color: Color = AztecTheme.gold

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AztecTheme.impact(size: 14))
            .tracking(2)
            .foregroundColor(AztecTheme.ink)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Rectangle()
                    .fill(color)
            )
            .overlay(
                Rectangle()
                    .stroke(AztecTheme.ink, lineWidth: 1.5)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct AztecSecondaryButtonStyle: ButtonStyle {
    var color: Color = AztecTheme.ink

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AztecTheme.impact(size: 13))
            .tracking(1)
            .foregroundColor(AztecTheme.ink)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Rectangle()
                    .stroke(AztecTheme.ink, lineWidth: 1.5)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Text Field Style

struct AztecTextField: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(AztecTheme.typewriter(size: 16))
            .foregroundColor(AztecTheme.ink)
            .padding(12)
            .background(Color.white)
            .overlay(
                Rectangle()
                    .stroke(AztecTheme.ink.opacity(0.4), lineWidth: 1)
            )
    }
}

extension View {
    func aztecTextField() -> some View {
        modifier(AztecTextField())
    }
}
