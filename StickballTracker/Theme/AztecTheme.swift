import SwiftUI

/// Design system: Dark neon aesthetic.
/// Black backgrounds, hot pink card borders with neon glow,
/// yellow/gold accent text. Placeholder font until custom handwritten font is provided.
enum AztecTheme {
    // MARK: - Primary Colors

    /// Hot pink — borders, glows, primary accent (#f229c5)
    static let hotPink = Color(red: 242/255, green: 41/255, blue: 197/255)

    /// Neon yellow/gold — text, scores, highlights (#fefd9c)
    static let neonYellow = Color(red: 254/255, green: 253/255, blue: 156/255)

    // MARK: - Backgrounds
    static let background = Color.black
    static let cardBg = Color.white.opacity(0.05)
    static let sheetBg = Color(white: 0.04)

    // Section backgrounds — all black
    static let tourneyBg = Color.black
    static let squadsBg = Color.black
    static let ballersBg = Color.black
    static let statsBg = Color.black

    // MARK: - Semantic Color Aliases
    static let obsidian = sheetBg
    static let darkStone = Color.white.opacity(0.08)
    static let stone = Color.white.opacity(0.35)

    // Primary accents map to new palette
    static let gold = neonYellow
    static let amber = hotPink

    // Secondary neon accents
    static let jade = Color(red: 0.0, green: 1.0, blue: 0.85)
    static let bloodRed = Color(red: 1.0, green: 0.15, blue: 0.15)
    static let cosmic = Color(red: 0.35, green: 0.55, blue: 1.0)
    static let tennisGreen = Color(red: 0.22, green: 1.0, blue: 0.08)
    static let neonOrange = Color(red: 1.0, green: 0.55, blue: 0.0)
    static let neonPink = hotPink

    // MARK: - Text Colors
    static let lightText = Color.white
    static let dimText = Color.white.opacity(0.5)
    static let ink = neonYellow

    // MARK: - Card Palette (cycled per-item)
    static let cardColors: [Color] = [
        hotPink.opacity(0.12),
        jade.opacity(0.10),
        neonYellow.opacity(0.08),
        cosmic.opacity(0.12),
        tennisGreen.opacity(0.08),
        neonOrange.opacity(0.10),
        Color(red: 0.70, green: 0.0, blue: 1.0).opacity(0.12),
        bloodRed.opacity(0.10),
    ]

    static func cardColor(for index: Int) -> Color {
        cardColors[index % cardColors.count]
    }

    // MARK: - Gradients
    static let goldGradient = LinearGradient(
        colors: [neonYellow, neonYellow.opacity(0.7)],
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
        colors: [hotPink, hotPink.opacity(0.6)],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let cardGradient = LinearGradient(
        colors: [Color.white.opacity(0.08), Color.white.opacity(0.03)],
        startPoint: .top,
        endPoint: .bottom
    )

    // MARK: - Fonts

    /// Custom HobbsFont — section headlines, team names, player names
    static func hobbsFont(size: CGFloat) -> Font {
        Font.custom("HobbsFont-Regular", size: size)
    }

    /// Heavy — headers, buttons, labels
    static func jazzFont(size: CGFloat) -> Font {
        Font.custom("Avenir-BlackOblique", size: size * 2)
    }

    /// Medium-heavy — body text
    static func jazzBody(size: CGFloat) -> Font {
        Font.custom("Avenir-HeavyOblique", size: size * 2)
    }

    /// Lighter — secondary body
    static func jazzLight(size: CGFloat) -> Font {
        Font.custom("Avenir-MediumOblique", size: size * 2)
    }

    // Font aliases
    static func impact(size: CGFloat) -> Font { jazzFont(size: size) }
    static func typewriter(size: CGFloat) -> Font { jazzBody(size: size) }
    static func typewriterBold(size: CGFloat) -> Font { jazzFont(size: size) }
    static func handwritten(size: CGFloat) -> Font { hobbsFont(size: size) }
    static func chunky(size: CGFloat) -> Font { hobbsFont(size: size) }

    // MARK: - Decorative Elements
    static var glowingLine: some View {
        Rectangle().fill(neonYellow)
    }

    static var borderLine: some View {
        Rectangle().fill(neonYellow.opacity(0.3)).frame(height: 1)
    }

    static var jadeBorderLine: some View {
        Rectangle().fill(jade.opacity(0.3)).frame(height: 1)
    }

    static func glowShadow(color: Color = hotPink, radius: CGFloat = 8) -> some View {
        Color.clear.shadow(color: color.opacity(0.3), radius: radius)
    }
}

// MARK: - Geometric Shapes

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

// MARK: - Neon Card Modifier

/// Dark card with neon border glow — the core visual building block.
struct NeonCardModifier: ViewModifier {
    var borderColor: Color = AztecTheme.hotPink
    var cornerRadius: CGFloat = 12
    var glowIntensity: CGFloat = 1.0

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(AztecTheme.cardBg)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(borderColor, lineWidth: 1.5)
            )
            .shadow(color: borderColor.opacity(0.5 * glowIntensity), radius: 4)
            .shadow(color: borderColor.opacity(0.25 * glowIntensity), radius: 10)
            .shadow(color: borderColor.opacity(0.1 * glowIntensity), radius: 20)
    }
}

extension View {
    /// Apply dark neon-bordered card style with glow.
    func neonCard(border: Color = AztecTheme.hotPink, cornerRadius: CGFloat = 12, glow: CGFloat = 1.0) -> some View {
        modifier(NeonCardModifier(borderColor: border, cornerRadius: cornerRadius, glowIntensity: glow))
    }
}

// MARK: - Legacy Card Style (updated to neon)

struct AztecCard: ViewModifier {
    var highlight: Color = AztecTheme.hotPink

    func body(content: Content) -> some View {
        content
            .padding(16)
            .neonCard(border: highlight)
    }
}

extension View {
    func aztecCard(highlight: Color = AztecTheme.hotPink) -> some View {
        modifier(AztecCard(highlight: highlight))
    }

    func aztecCardColored(index: Int, highlight: Color = AztecTheme.hotPink) -> some View {
        modifier(AztecCard(highlight: highlight))
    }
}

// MARK: - Button Styles

struct AztecButtonStyle: ButtonStyle {
    var color: Color = AztecTheme.neonYellow

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AztecTheme.jazzFont(size: 10))
            .tracking(2)
            .foregroundColor(Color.black)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: color.opacity(0.5), radius: configuration.isPressed ? 2 : 8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct AztecSecondaryButtonStyle: ButtonStyle {
    var color: Color = AztecTheme.neonYellow

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AztecTheme.jazzFont(size: 8))
            .tracking(1)
            .foregroundColor(color)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(color, lineWidth: 1.5)
            )
            .shadow(color: color.opacity(0.3), radius: configuration.isPressed ? 1 : 4)
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
            .accentColor(AztecTheme.neonYellow)
            .padding(12)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AztecTheme.hotPink.opacity(0.4), lineWidth: 1)
            )
    }
}

extension View {
    func aztecTextField() -> some View {
        modifier(AztecTextField())
    }
}
