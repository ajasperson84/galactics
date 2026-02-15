import SwiftUI

/// Full-screen background with Aztec geometric patterns and sci-fi glow effects.
struct AztecBackground: View {
    var body: some View {
        ZStack {
            // Base
            AztecTheme.obsidian.ignoresSafeArea()

            // Subtle geometric pattern
            GeometryReader { _ in
                Canvas { context, size in
                    let gridSize: CGFloat = 60
                    let cols = Int(size.width / gridSize) + 1
                    let rows = Int(size.height / gridSize) + 1

                    for row in 0..<rows {
                        for col in 0..<cols {
                            let x = CGFloat(col) * gridSize
                            let y = CGFloat(row) * gridSize

                            // Aztec step pattern
                            if (row + col) % 3 == 0 {
                                let rect = CGRect(
                                    x: x + gridSize * 0.35,
                                    y: y + gridSize * 0.35,
                                    width: gridSize * 0.3,
                                    height: gridSize * 0.3
                                )
                                let path = Path(rect)
                                context.stroke(
                                    path,
                                    with: .color(AztecTheme.gold.opacity(0.04)),
                                    lineWidth: 0.5
                                )
                            }

                            // Diamond pattern
                            if (row + col) % 5 == 0 {
                                var diamond = Path()
                                let cx = x + gridSize / 2
                                let cy = y + gridSize / 2
                                let s = gridSize * 0.15
                                diamond.move(to: CGPoint(x: cx, y: cy - s))
                                diamond.addLine(to: CGPoint(x: cx + s, y: cy))
                                diamond.addLine(to: CGPoint(x: cx, y: cy + s))
                                diamond.addLine(to: CGPoint(x: cx - s, y: cy))
                                diamond.closeSubpath()
                                context.stroke(
                                    diamond,
                                    with: .color(AztecTheme.jade.opacity(0.03)),
                                    lineWidth: 0.5
                                )
                            }
                        }
                    }
                }
            }
            .ignoresSafeArea()

            // Top glow
            VStack {
                EllipticalGradient(
                    colors: [
                        AztecTheme.gold.opacity(0.06),
                        Color.clear
                    ],
                    center: .center,
                    startRadiusFraction: 0,
                    endRadiusFraction: 0.7
                )
                .frame(height: 200)
                .offset(y: -60)

                Spacer()

                // Bottom glow
                EllipticalGradient(
                    colors: [
                        AztecTheme.jade.opacity(0.04),
                        Color.clear
                    ],
                    center: .center,
                    startRadiusFraction: 0,
                    endRadiusFraction: 0.7
                )
                .frame(height: 150)
                .offset(y: 40)
            }
            .ignoresSafeArea()
        }
    }
}

/// App header with Aztec-styled title and decorative borders.
struct AztecHeader: View {
    let title: String

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                // Left decorative element
                AztecCornerGlyph()

                Spacer()

                Text(title)
                    .font(.system(size: 18, weight: .black))
                    .tracking(4)
                    .foregroundStyle(AztecTheme.goldGradient)
                    .shadow(color: AztecTheme.gold.opacity(0.3), radius: 8)

                Spacer()

                AztecCornerGlyph()
                    .scaleEffect(x: -1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // Decorative border
            HStack(spacing: 4) {
                ForEach(0..<30, id: \.self) { i in
                    Rectangle()
                        .fill(
                            i % 3 == 0
                                ? AztecTheme.gold.opacity(0.5)
                                : AztecTheme.gold.opacity(0.15)
                        )
                        .frame(height: 2)
                }
            }
            .padding(.horizontal, 8)
        }
        .background(AztecTheme.obsidian.opacity(0.9))
    }
}

/// Small decorative Aztec corner glyph.
struct AztecCornerGlyph: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height

            // Step pattern
            var path = Path()
            path.move(to: CGPoint(x: 0, y: h))
            path.addLine(to: CGPoint(x: 0, y: h * 0.5))
            path.addLine(to: CGPoint(x: w * 0.25, y: h * 0.5))
            path.addLine(to: CGPoint(x: w * 0.25, y: h * 0.25))
            path.addLine(to: CGPoint(x: w * 0.5, y: h * 0.25))
            path.addLine(to: CGPoint(x: w * 0.5, y: 0))
            path.addLine(to: CGPoint(x: w, y: 0))

            context.stroke(
                path,
                with: .color(AztecTheme.gold.opacity(0.6)),
                lineWidth: 1.5
            )
        }
        .frame(width: 24, height: 18)
    }
}

/// Section header with Aztec styling.
struct AztecSectionHeader: View {
    let title: String
    var color: Color = AztecTheme.gold

    var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(color.opacity(0.4))
                .frame(width: 3, height: 16)

            Text(title.uppercased())
                .font(.system(size: 13, weight: .heavy))
                .tracking(3)
                .foregroundColor(color)

            VStack { Divider().background(color.opacity(0.2)) }
        }
        .padding(.vertical, 4)
    }
}
