import SwiftUI

/// App header — placeholder for custom header image.
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
                .fill(AztecTheme.hotPink)
                .frame(height: 2)
                .shadow(color: AztecTheme.hotPink.opacity(0.6), radius: 4)
        }
        .background(Color.black)
    }
}

/// Section header with geometric shapes and neon colors.
struct AztecSectionHeader: View {
    let title: String
    var color: Color = AztecTheme.neonYellow
    var shapeIndex: Int = 0

    private static let shapeColors: [Color] = [
        AztecTheme.hotPink,
        AztecTheme.neonYellow,
        AztecTheme.jade,
        AztecTheme.cosmic,
        AztecTheme.tennisGreen,
        AztecTheme.neonOrange,
        Color(red: 0.70, green: 0.0, blue: 1.0),
        AztecTheme.bloodRed,
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
                .shadow(color: shapeColor.opacity(0.3), radius: 4)

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
