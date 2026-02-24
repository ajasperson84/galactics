import SwiftUI

/// Design system: 80s Jazzercise aesthetic.
/// Rich neon backgrounds per section, thick italic sans-serif type,
/// contrasting neon accents. Bold, energetic, retro fitness vibes.
enum AztecTheme {
    // MARK: - Section Backgrounds (each tab gets its own neon)
    static let tourneyBg = Color(red: 0.70, green: 0.0, blue: 0.36)   // Hot magenta
    static let squadsBg = Color(red: 0.05, green: 0.08, blue: 0.58)   // Deep electric indigo
    static let ballersBg = Color(red: 0.36, green: 0.03, blue: 0.60)  // Vivid purple
    static let statsBg = Color(red: 0.0, green: 0.38, blue: 0.36)     // Deep teal
    static let sheetBg = Color(red: 0.06, green: 0.03, blue: 0.14)    // Near-black purple

    // MARK: - Base Colors
    /// Very dark purple-black — sheet/modal backgrounds
    static let obsidian = Color(red: 0.06, green: 0.03, blue: 0.14)
    /// Translucent white — card & element backgrounds (shows section color through)
    static let darkStone = Color.white.opacity(0.10)
    /// Medium translucent — secondary elements, borders
    static let stone = Color.white.opacity(0.35)

    // MARK: - Neon Accent Colors
    /// Neon yellow — primary accent
    static let gold = Color(red: 1.0, green: 0.95, blue: 0.0)
    /// Neon hot pink — secondary accent
    static let amber = Color(red: 1.0, green: 0.08, blue: 0.58)
    /// Neon cyan — tertiary accent
    static let jade = Color(red: 0.0, green: 1.0, blue: 0.85)
    /// Bright red — alerts/destructive
    static let bloodRed = Color(red: 1.0, green: 0.15, blue: 0.15)
    /// Electric blue
    static let cosmic = Color(red: 0.35, green: 0.55, blue: 1.0)
    /// Neon lime green
    static let tennisGreen = Color(red: 0.22, green: 1.0, blue: 0.08)

    // MARK: - Text Colors
    static let lightText = Color.white
    static let dimText = Color.white.opacity(0.6)
    static let ink = Color.white

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
        colors: [cosmic, Color(red: 0.15, green: 0.30, blue: 0.85)],
        startPoint: .top,
        endPoint: .bottom
    )

    static let pinkGradient = LinearGradient(
        colors: [amber, Color(red: 0.80, green: 0.0, blue: 0.40)],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let cardGradient = LinearGradient(
        colors: [Color.white.opacity(0.12), Color.white.opacity(0.06)],
        startPoint: .top,
        endPoint: .bottom
    )

    // MARK: - Fonts (80s Jazzercise: thick italic sans-serif)

    /// Heavy italic — headers, buttons, labels
    static func jazzFont(size: CGFloat) -> Font {
        Font.custom("Avenir-BlackOblique", size: size)
    }

    /// Medium-heavy italic — body text
    static func jazzBody(size: CGFloat) -> Font {
        Font.custom("Avenir-HeavyOblique", size: size)
    }

    /// Lighter italic — secondary body
    static func jazzLight(size: CGFloat) -> Font {
        Font.custom("Avenir-MediumOblique", size: size)
    }

    // Aliases so all existing font references auto-update
    static func impact(size: CGFloat) -> Font { jazzFont(size: size) }
    static func typewriter(size: CGFloat) -> Font { jazzBody(size: size) }
    static func typewriterBold(size: CGFloat) -> Font { jazzFont(size: size) }
    static func handwritten(size: CGFloat) -> Font { jazzFont(size: size) }
    static func chunky(size: CGFloat) -> Font { jazzFont(size: size) }

    // MARK: - Decorative Elements
    static var glowingLine: some View {
        Rectangle().fill(gold)
    }

    static var borderLine: some View {
        Rectangle().fill(gold.opacity(0.3)).frame(height: 1)
    }

    static var jadeBorderLine: some View {
        Rectangle().fill(jade.opacity(0.3)).frame(height: 1)
    }

    static func glowShadow(color: Color = gold, radius: CGFloat = 8) -> some View {
        Color.clear.shadow(color: color.opacity(0.3), radius: radius)
    }
}

// MARK: - Card Style

struct AztecCard: ViewModifier {
    var highlight: Color = AztecTheme.gold

    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(Color.white.opacity(0.08))
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

// MARK: - Button Styles

struct AztecButtonStyle: ButtonStyle {
    var color: Color = AztecTheme.gold

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AztecTheme.jazzFont(size: 15))
            .tracking(2)
            .foregroundColor(Color.black)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .shadow(color: color.opacity(0.4), radius: configuration.isPressed ? 2 : 8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct AztecSecondaryButtonStyle: ButtonStyle {
    var color: Color = AztecTheme.gold

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AztecTheme.jazzFont(size: 13))
            .tracking(1)
            .foregroundColor(color)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(color, lineWidth: 1.5)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Text Field Style

struct AztecTextField: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(AztecTheme.jazzBody(size: 16))
            .foregroundColor(.white)
            .accentColor(AztecTheme.gold)
            .padding(12)
            .background(Color.white.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(AztecTheme.stone, lineWidth: 1)
                    .allowsHitTesting(false)
            )
    }
}

extension View {
    func aztecTextField() -> some View {
        modifier(AztecTextField())
    }
}
