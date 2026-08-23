import SwiftUI

/// Design system: Dark neon aesthetic.
/// Black backgrounds, hot pink card borders with neon glow,
/// yellow/gold accent text. Custom HobbsFont for headlines.
enum AztecTheme {
    // MARK: - Primary Colors

    /// Hot pink — borders, glows, primary accent (#FF00AE)
    static let hotPink = Color(red: 255/255, green: 0/255, blue: 174/255)

    /// Neon yellow — text, scores, highlights (#FFF200)
    static let neonYellow = Color(red: 255/255, green: 242/255, blue: 0/255)

    // MARK: - Backgrounds
    static let background = Color.black
    static let cardBg = Color.black
    static let sheetBg = Color.black

    // Section backgrounds — all black
    static let tourneyBg = Color.black
    static let squadsBg = Color.black
    static let ballersBg = Color.black
    static let statsBg = Color.black

    // MARK: - Semantic Color Aliases
    static let obsidian = Color.black
    static let darkStone = Color.black
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
        colors: [Color.black, Color.black],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Border gradient: yellow on the left, pink on the right
    static let borderGradient = LinearGradient(
        colors: [neonYellow, hotPink],
        startPoint: .leading,
        endPoint: .trailing
    )

    // MARK: - Fonts

    /// Custom HobbsFont — section headlines, team names, player names
    /// 15% bigger and 30% tighter kerning applied at call sites
    static func hobbsFont(size: CGFloat) -> Font {
        Font.custom("HobbsFont-Regular", size: size * 1.15)
    }

    /// Futura Bold — game info, player stats, body text
    /// (legacy name from an earlier SF Pro era; kept for call-site compat)
    static func sfProBold(size: CGFloat) -> Font {
        Font.custom("Futura-Bold", size: size)
    }

    /// Futura Medium — secondary body text
    /// (legacy name from an earlier SF Pro era; kept for call-site compat)
    static func sfProMedium(size: CGFloat) -> Font {
        Font.custom("Futura-Medium", size: size)
    }

    /// Futura Medium (lighter weight alias) — iOS Futura has no "Regular"
    /// weight, so this intentionally maps to Medium like sfProMedium.
    /// (legacy name from an earlier SF Pro era; kept for call-site compat)
    static func sfProRegular(size: CGFloat) -> Font {
        Font.custom("Futura-Medium", size: size)
    }

    // Font aliases — all now use Futura (legacy names kept)
    static func jazzFont(size: CGFloat) -> Font { sfProBold(size: size * 2) }
    static func jazzBody(size: CGFloat) -> Font { sfProMedium(size: size * 2) }
    static func jazzLight(size: CGFloat) -> Font { sfProRegular(size: size * 2) }
    static func impact(size: CGFloat) -> Font { sfProBold(size: size * 2) }
    static func typewriter(size: CGFloat) -> Font { sfProMedium(size: size * 2) }
    static func typewriterBold(size: CGFloat) -> Font { sfProBold(size: size * 2) }
    static func handwritten(size: CGFloat) -> Font { hobbsFont(size: size) }
    static func chunky(size: CGFloat) -> Font { hobbsFont(size: size) }

    /// Hobbs kerning — 30% tighter (negative tracking)
    static let hobbsKerning: CGFloat = -1.5

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

// MARK: - Neon Card Modifier

/// Dark card with neon border glow — the core visual building block.
/// Black background, 50% thicker outlines.
struct NeonCardModifier: ViewModifier {
    var borderColor: Color = AztecTheme.hotPink
    var cornerRadius: CGFloat = 12
    var glowIntensity: CGFloat = 1.0

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.black)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(AztecTheme.borderGradient, lineWidth: 2.25)
            )
            .shadow(color: AztecTheme.neonYellow.opacity(0.3 * glowIntensity), radius: 4, x: -2)
            .shadow(color: AztecTheme.hotPink.opacity(0.3 * glowIntensity), radius: 4, x: 2)
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

/// Primary action button — pink outline, black background, pink text
struct AztecButtonStyle: ButtonStyle {
    var color: Color = AztecTheme.hotPink

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AztecTheme.sfProBold(size: 16))
            .foregroundColor(color)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(color, lineWidth: 2.25)
            )
            .shadow(color: color.opacity(0.3), radius: configuration.isPressed ? 2 : 6)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct AztecSecondaryButtonStyle: ButtonStyle {
    var color: Color = AztecTheme.hotPink

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AztecTheme.sfProBold(size: 14))
            .foregroundColor(color)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(color, lineWidth: 2.25)
            )
            .shadow(color: color.opacity(0.3), radius: configuration.isPressed ? 1 : 4)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Dismiss Button Style (pink outline, black bg)

struct AztecDismissButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(AztecTheme.sfProBold(size: 14))
            .foregroundColor(AztecTheme.hotPink)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(AztecTheme.hotPink, lineWidth: 1.5)
            )
    }
}

extension View {
    func dismissButtonStyle() -> some View {
        modifier(AztecDismissButtonStyle())
    }
}

// MARK: - Text Field Style

struct AztecTextField: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(AztecTheme.sfProBold(size: 16))
            .foregroundColor(.white)
            .accentColor(AztecTheme.neonYellow)
            .padding(12)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AztecTheme.hotPink.opacity(0.6), lineWidth: 2.25)
            )
    }
}

extension View {
    func aztecTextField() -> some View {
        modifier(AztecTextField())
    }
}
