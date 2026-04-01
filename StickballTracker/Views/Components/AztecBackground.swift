import SwiftUI

/// App header — uses G4_header_PINK image.
struct AztecHeader: View {
    let title: String

    var body: some View {
        VStack(spacing: 0) {
            Image("G4_header_PINK")
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

/// Section header — simple text over black, no shapes.
/// Yellow by default, uses HobbsFont with tight kerning.
struct AztecSectionHeader: View {
    let title: String
    var color: Color = AztecTheme.neonYellow
    var shapeIndex: Int = 0

    var body: some View {
        HStack(spacing: 0) {
            Text(title.uppercased())
                .font(AztecTheme.hobbsFont(size: 22))
                .tracking(AztecTheme.hobbsKerning)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .foregroundColor(color)
                .shadow(color: color.opacity(0.4), radius: 4)

            Spacer()
        }
        .padding(.vertical, 2)
    }
}
