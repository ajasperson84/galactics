import SwiftUI

/// Full-screen paper-white background with subtle xerox noise texture.
struct AztecBackground: View {
    var body: some View {
        ZStack {
            // Clean paper white base
            AztecTheme.obsidian.ignoresSafeArea()

            // Subtle xerox grain / noise dots
            GeometryReader { _ in
                Canvas { context, size in
                    let gridSize: CGFloat = 40
                    let cols = Int(size.width / gridSize) + 1
                    let rows = Int(size.height / gridSize) + 1

                    for row in 0..<rows {
                        for col in 0..<cols {
                            let x = CGFloat(col) * gridSize
                            let y = CGFloat(row) * gridSize

                            // Scattered dots like xerox artifacts
                            if (row * 7 + col * 13) % 11 == 0 {
                                let dotSize: CGFloat = 1.5
                                let rect = CGRect(
                                    x: x + gridSize * 0.5,
                                    y: y + gridSize * 0.5,
                                    width: dotSize,
                                    height: dotSize
                                )
                                context.fill(
                                    Path(ellipseIn: rect),
                                    with: .color(AztecTheme.ink.opacity(0.04))
                                )
                            }
                        }
                    }
                }
            }
            .ignoresSafeArea()
        }
    }
}

/// App header using the G4_header image asset.
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

            // Black rule line
            Rectangle()
                .fill(AztecTheme.ink)
                .frame(height: 2)
        }
        .background(Color.white)
    }
}

/// Section header with Impact font and optional color highlight block.
struct AztecSectionHeader: View {
    let title: String
    var color: Color = AztecTheme.ink

    var body: some View {
        HStack(spacing: 0) {
            Text(" \(title.uppercased()) ")
                .font(AztecTheme.impact(size: 16))
                .foregroundColor(color == AztecTheme.ink ? AztecTheme.ink : AztecTheme.ink)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(
                    color == AztecTheme.ink
                        ? Color.clear
                        : color.opacity(0.35)
                )

            VStack {
                Divider().background(AztecTheme.ink.opacity(0.15))
            }
        }
        .padding(.vertical, 4)
    }
}
