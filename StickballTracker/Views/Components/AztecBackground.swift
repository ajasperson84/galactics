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

/// Section header with jazzercise italic font and neon accent color.
struct AztecSectionHeader: View {
    let title: String
    var color: Color = AztecTheme.gold

    var body: some View {
        HStack(spacing: 0) {
            Text(" \(title.uppercased()) ")
                .font(AztecTheme.jazzFont(size: 16))
                .foregroundColor(color)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)

            VStack {
                Divider().background(color.opacity(0.3))
            }
        }
        .padding(.vertical, 4)
    }
}
