import SwiftUI

/// Design system: 80s Jazzercise aesthetic.
/// Rich neon backgrounds per section, thick italic sans-serif type,
/// contrasting neon accents. Bold, energetic, retro fitness vibes.
enum AztecTheme {
    // MARK: - Section Backgrounds (each tab gets its own neon)
    static let tourneyBg = Color(red: 0.70, green: 0.0, blue: 0.36)   // Hot magenta
    static let squadsBg = Color(red: 0.0, green: 0.85, blue: 0.78)    // Cyan
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
    /// Neon orange
    static let neonOrange = Color(red: 1.0, green: 0.55, blue: 0.0)
    /// Neon pink (for nav highlight)
    static let neonPink = Color(red: 1.0, green: 0.0, blue: 0.6)

    // MARK: - 80s card palette (cycled per-item for variety)
    static let cardColors: [Color] = [
        Color(red: 1.0, green: 0.08, blue: 0.58).opacity(0.18),  // hot pink
        Color(red: 0.0, green: 1.0, blue: 0.85).opacity(0.15),   // cyan
        Color(red: 1.0, green: 0.95, blue: 0.0).opacity(0.12),   // yellow
        Color(red: 0.35, green: 0.55, blue: 1.0).opacity(0.18),  // blue
        Color(red: 0.22, green: 1.0, blue: 0.08).opacity(0.12),  // lime
        Color(red: 1.0, green: 0.55, blue: 0.0).opacity(0.15),   // orange
        Color(red: 0.70, green: 0.0, blue: 1.0).opacity(0.18),   // purple
        Color(red: 1.0, green: 0.15, blue: 0.15).opacity(0.14),  // red
    ]

    static func cardColor(for index: Int) -> Color {
        cardColors[index % cardColors.count]
    }

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
        Font.custom("Avenir-BlackOblique", size: size * 2)
    }

    /// Medium-heavy italic — body text
    static func jazzBody(size: CGFloat) -> Font {
        Font.custom("Avenir-HeavyOblique", size: size * 2)
    }

    /// Lighter italic — secondary body
    static func jazzLight(size: CGFloat) -> Font {
        Font.custom("Avenir-MediumOblique", size: size * 2)
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

// MARK: - Irregular/Organic Shape

/// A wobbly, hand-cut shape — very pronounced organic 80s collage feel.
struct WobblyShape: Shape {
    var wobble: CGFloat = 0.06
    var seed: Int = 0

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let d = wobble

        let s = CGFloat(seed % 7 + 1) * 0.4

        path.move(to: CGPoint(x: w * d * s * 0.5, y: h * d * 0.8))
        // Top edge — big wave
        path.addCurve(
            to: CGPoint(x: w * (1 - d * 0.6), y: h * d * (0.5 + s * 0.15)),
            control1: CGPoint(x: w * 0.3, y: -h * d * 1.2),
            control2: CGPoint(x: w * 0.7, y: h * d * 2.0)
        )
        // Right edge — inward bulge
        path.addCurve(
            to: CGPoint(x: w * (1 - d * s * 0.3), y: h * (1 - d * 0.7)),
            control1: CGPoint(x: w * (1 + d * 1.0), y: h * 0.35),
            control2: CGPoint(x: w * (1 - d * 0.8), y: h * 0.65)
        )
        // Bottom edge — wave
        path.addCurve(
            to: CGPoint(x: w * d * 0.7, y: h * (1 - d * (0.6 + s * 0.2))),
            control1: CGPoint(x: w * 0.7, y: h * (1 + d * 1.0)),
            control2: CGPoint(x: w * 0.3, y: h * (1 - d * 1.5))
        )
        // Left edge — outward bulge
        path.addCurve(
            to: CGPoint(x: w * d * s * 0.5, y: h * d * 0.8),
            control1: CGPoint(x: -w * d * 0.8, y: h * 0.65),
            control2: CGPoint(x: w * d * 1.0, y: h * 0.35)
        )
        path.closeSubpath()
        return path
    }
}

// MARK: - Geometric Section Header Shapes

/// Trapezoid shape — wider at bottom
struct TrapezoidShape: Shape {
    var skew: CGFloat = 0.15
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * skew, y: 0))
        path.addLine(to: CGPoint(x: rect.width * (1 - skew * 0.5), y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        return path
    }
}

/// Parallelogram shape — slanted right
struct ParallelogramShape: Shape {
    var slant: CGFloat = 0.18
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * slant, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: 0))
        path.addLine(to: CGPoint(x: rect.width * (1 - slant), y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        return path
    }
}

/// Arrow/chevron shape — points right
struct ArrowShape: Shape {
    var indent: CGFloat = 0.12
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: rect.width * (1 - indent), y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height * 0.5))
        path.addLine(to: CGPoint(x: rect.width * (1 - indent), y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.addLine(to: CGPoint(x: rect.width * indent, y: rect.height * 0.5))
        path.closeSubpath()
        return path
    }
}

/// Pentagon shape
struct PentagonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.08, y: 0))
        path.addLine(to: CGPoint(x: rect.width * 0.92, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height * 0.6))
        path.addLine(to: CGPoint(x: rect.width * 0.5, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height * 0.6))
        path.closeSubpath()
        return path
    }
}

// MARK: - Card Style

struct AztecCard: ViewModifier {
    var highlight: Color = AztecTheme.gold
    var seed: Int = 0
    var bgColor: Color? = nil

    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(bgColor ?? Color.white.opacity(0.08))
            .clipShape(WobblyShape(seed: seed))
            .overlay(
                WobblyShape(seed: seed)
                    .stroke(highlight.opacity(0.3), lineWidth: 2)
            )
    }
}

extension View {
    func aztecCard(highlight: Color = AztecTheme.gold) -> some View {
        modifier(AztecCard(highlight: highlight))
    }

    func aztecCardColored(index: Int, highlight: Color = AztecTheme.gold) -> some View {
        modifier(AztecCard(highlight: highlight, seed: index, bgColor: AztecTheme.cardColor(for: index)))
    }
}

// MARK: - Button Styles

struct AztecButtonStyle: ButtonStyle {
    var color: Color = AztecTheme.gold

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AztecTheme.jazzFont(size: 10))
            .tracking(2)
            .foregroundColor(Color.black)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(color)
            .clipShape(WobblyShape(seed: 3))
            .overlay(
                WobblyShape(seed: 3)
                    .stroke(Color.black.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: color.opacity(0.4), radius: configuration.isPressed ? 2 : 10)
            .scaleEffect(configuration.isPressed ? 0.93 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct AztecSecondaryButtonStyle: ButtonStyle {
    var color: Color = AztecTheme.gold

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AztecTheme.jazzFont(size: 8))
            .tracking(1)
            .foregroundColor(color)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(
                WobblyShape(seed: 5)
                    .stroke(color, lineWidth: 2)
            )
            .scaleEffect(configuration.isPressed ? 0.93 : 1.0)
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
