import SwiftUI

/// Splash screen with "Galactics IV" title in a futuristic Aztec style.
struct SplashView: View {
    @State private var glowOpacity: Double = 0.3
    @State private var titleScale: CGFloat = 0.85
    @State private var subtitleOffset: CGFloat = 20
    @State private var subtitleOpacity: Double = 0
    @State private var borderOpacity: Double = 0
    @State private var diamondRotation: Double = 0

    var body: some View {
        ZStack {
            // Base background
            AztecTheme.obsidian.ignoresSafeArea()

            // Geometric pattern layer
            GeometryReader { _ in
                Canvas { context, size in
                    let gridSize: CGFloat = 50
                    let cols = Int(size.width / gridSize) + 1
                    let rows = Int(size.height / gridSize) + 1

                    for row in 0..<rows {
                        for col in 0..<cols {
                            let x = CGFloat(col) * gridSize
                            let y = CGFloat(row) * gridSize

                            if (row + col) % 4 == 0 {
                                var diamond = Path()
                                let cx = x + gridSize / 2
                                let cy = y + gridSize / 2
                                let s = gridSize * 0.2
                                diamond.move(to: CGPoint(x: cx, y: cy - s))
                                diamond.addLine(to: CGPoint(x: cx + s, y: cy))
                                diamond.addLine(to: CGPoint(x: cx, y: cy + s))
                                diamond.addLine(to: CGPoint(x: cx - s, y: cy))
                                diamond.closeSubpath()
                                context.stroke(
                                    diamond,
                                    with: .color(AztecTheme.gold.opacity(0.06)),
                                    lineWidth: 0.5
                                )
                            }

                            if (row + col) % 7 == 0 {
                                let rect = CGRect(
                                    x: x + gridSize * 0.3,
                                    y: y + gridSize * 0.3,
                                    width: gridSize * 0.4,
                                    height: gridSize * 0.4
                                )
                                context.stroke(
                                    Path(rect),
                                    with: .color(AztecTheme.jade.opacity(0.04)),
                                    lineWidth: 0.5
                                )
                            }
                        }
                    }
                }
            }
            .ignoresSafeArea()

            // Central glow
            EllipticalGradient(
                colors: [
                    AztecTheme.gold.opacity(glowOpacity * 0.15),
                    AztecTheme.amber.opacity(glowOpacity * 0.05),
                    Color.clear
                ],
                center: .center,
                startRadiusFraction: 0,
                endRadiusFraction: 0.5
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Top Aztec border
                HStack(spacing: 3) {
                    ForEach(0..<40, id: \.self) { i in
                        Rectangle()
                            .fill(
                                i % 3 == 0
                                    ? AztecTheme.gold.opacity(0.6)
                                    : AztecTheme.gold.opacity(0.2)
                            )
                            .frame(height: 2)
                    }
                }
                .padding(.horizontal, 30)
                .opacity(borderOpacity)

                Spacer().frame(height: 32)

                // Decorative diamond
                ZStack {
                    // Outer glow ring
                    Circle()
                        .fill(AztecTheme.gold.opacity(0.04))
                        .frame(width: 140, height: 140)

                    // Rotating diamond
                    Diamond()
                        .stroke(AztecTheme.gold.opacity(0.4), lineWidth: 1.5)
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(diamondRotation))

                    // Inner diamond
                    Diamond()
                        .fill(AztecTheme.gold.opacity(0.08))
                        .frame(width: 30, height: 30)
                        .rotationEffect(.degrees(-diamondRotation * 0.5))

                    // Center dot
                    Circle()
                        .fill(AztecTheme.gold)
                        .frame(width: 4, height: 4)
                        .shadow(color: AztecTheme.gold.opacity(0.8), radius: 6)
                }

                Spacer().frame(height: 28)

                // Title: GALACTICS
                Text("GALACTICS")
                    .font(.system(size: 42, weight: .black))
                    .tracking(12)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                AztecTheme.gold,
                                AztecTheme.amber,
                                AztecTheme.gold
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: AztecTheme.gold.opacity(0.5), radius: 16)
                    .shadow(color: AztecTheme.gold.opacity(0.2), radius: 32)
                    .scaleEffect(titleScale)

                Spacer().frame(height: 6)

                // Subtitle: IV
                Text("IV")
                    .font(.system(size: 64, weight: .black))
                    .tracking(20)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                AztecTheme.jade,
                                AztecTheme.jade.opacity(0.6)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: AztecTheme.jade.opacity(0.4), radius: 12)
                    .opacity(subtitleOpacity)
                    .offset(y: subtitleOffset)

                Spacer().frame(height: 32)

                // Bottom Aztec border
                HStack(spacing: 3) {
                    ForEach(0..<40, id: \.self) { i in
                        Rectangle()
                            .fill(
                                i % 3 == 0
                                    ? AztecTheme.gold.opacity(0.6)
                                    : AztecTheme.gold.opacity(0.2)
                            )
                            .frame(height: 2)
                    }
                }
                .padding(.horizontal, 30)
                .opacity(borderOpacity)

                Spacer()

                // Tagline
                Text("STICKBALL TOURNAMENT")
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(6)
                    .foregroundColor(AztecTheme.stone)
                    .opacity(subtitleOpacity)

                Spacer().frame(height: 50)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) {
                titleScale = 1.0
                glowOpacity = 1.0
                borderOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                subtitleOpacity = 1.0
                subtitleOffset = 0
            }
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                diamondRotation = 360
            }
        }
    }
}

/// Diamond shape used as a decorative element.
struct Diamond: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}
