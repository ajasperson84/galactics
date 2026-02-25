import SwiftUI

/// Neon background with subtle 80s grid lines.
struct AztecBackground: View {
    var color: Color = AztecTheme.tourneyBg

    var body: some View {
        ZStack {
            color.ignoresSafeArea()

            // Subtle horizontal speed lines
            GeometryReader { _ in
                Canvas { context, size in
                    let lineSpacing: CGFloat = 28
                    let lineCount = Int(size.height / lineSpacing) + 1
                    for i in 0..<lineCount {
                        let y = CGFloat(i) * lineSpacing
                        var path = Path()
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                        context.stroke(
                            path,
                            with: .color(.white.opacity(0.035)),
                            lineWidth: 0.5
                        )
                    }
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }
}

/// App header using the G4_header image asset on dark background.
struct AztecHeader: View {
    let title: String

    var body: some View {
        VStack(spacing: 0) {
            Image("G4_header")
                .resizable()
                .scaledToFit()
                .frame(height: 44)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

            Rectangle()
                .fill(AztecTheme.gold)
                .frame(height: 2)
        }
        .background(AztecTheme.obsidian)
    }
}

/// Section header with geometric 80s shapes (trapezoids, parallelograms, arrows, pentagons).
/// Each instance gets a different shape and color based on its position.
struct AztecSectionHeader: View {
    let title: String
    var color: Color = AztecTheme.gold
    var shapeIndex: Int = 0

    // 80s neon shape colors — cycled per header
    private static let shapeColors: [Color] = [
        Color(red: 1.0, green: 0.08, blue: 0.58),  // hot pink
        Color(red: 1.0, green: 0.15, blue: 0.15),  // red
        Color(red: 0.22, green: 1.0, blue: 0.08),   // lime
        Color(red: 1.0, green: 0.55, blue: 0.0),    // orange
        Color(red: 0.0, green: 1.0, blue: 0.85),    // cyan
        Color(red: 0.70, green: 0.0, blue: 1.0),    // purple
        Color(red: 1.0, green: 0.95, blue: 0.0),    // yellow
        Color(red: 0.35, green: 0.55, blue: 1.0),   // blue
    ]

    private var shapeColor: Color {
        Self.shapeColors[abs(shapeIndex) % Self.shapeColors.count]
    }

    var body: some View {
        HStack(spacing: 0) {
            Text(title.uppercased())
                .font(AztecTheme.jazzFont(size: 9))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(
                    GeometricHeaderShape(index: shapeIndex)
                        .fill(shapeColor.opacity(0.85))
                )

            Spacer()
        }
        .padding(.vertical, 2)
    }
}

/// Returns a different geometric shape based on index.
struct GeometricHeaderShape: Shape {
    let index: Int

    func path(in rect: CGRect) -> Path {
        switch abs(index) % 4 {
        case 0:
            return TrapezoidShape().path(in: rect)
        case 1:
            return ParallelogramShape().path(in: rect)
        case 2:
            return ArrowShape().path(in: rect)
        default:
            return PentagonShape().path(in: rect)
        }
    }
}
