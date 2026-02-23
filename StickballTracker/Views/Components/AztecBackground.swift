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

/// App header with chunky "G FOUR" title.
struct AztecHeader: View {
    let title: String

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()

                Text(title)
                    .font(AztecTheme.chunky(size: 28))
                    .tracking(6)
                    .foregroundStyle(AztecTheme.goldGradient)
                    .shadow(color: AztecTheme.gold.opacity(0.5), radius: 10)
                    .shadow(color: AztecTheme.tennisGreen.opacity(0.2), radius: 20)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            // Neon underline
            Rectangle()
                .fill(AztecTheme.goldGradient)
                .frame(height: 2)
                .shadow(color: AztecTheme.gold.opacity(0.5), radius: 4)
                .padding(.horizontal, 16)
        }
        .background(AztecTheme.obsidian.opacity(0.95))
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

/// Section header with handwritten styling.
struct AztecSectionHeader: View {
    let title: String
    var color: Color = AztecTheme.gold

    var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(color.opacity(0.5))
                .frame(width: 3, height: 18)

            Text(title)
                .font(AztecTheme.handwritten(size: 18))
                .foregroundColor(color)
                .shadow(color: color.opacity(0.3), radius: 4)

            VStack { Divider().background(color.opacity(0.2)) }
        }
        .padding(.vertical, 4)
    }
}
