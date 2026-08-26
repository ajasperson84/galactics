import SwiftUI

/// App header — uses G4_header_YellowandPink image.
struct AztecHeader: View {
    var body: some View {
        VStack(spacing: 0) {
            Image("G4_header_YellowandPink")
                .resizable()
                .scaledToFit()
                .frame(height: 86)
                .padding(.horizontal, 16)

            Rectangle()
                .fill(AztecTheme.hotPink)
                .frame(height: 2)
                .shadow(color: AztecTheme.hotPink.opacity(0.6), radius: 4)
        }
        .background(AztecTheme.hotPink)
    }
}

/// Section header — simple text over black, no shapes.
/// Yellow by default, uses HobbsFont with tight kerning.
struct AztecSectionHeader: View {
    let title: String
    var color: Color = AztecTheme.neonYellow

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

/// Banner shown at the top of a view when CloudSyncService reports a Firestore
/// sync error (permission denied, network failure, decoding problem, etc.).
/// This is critical: without it, sync failures are completely invisible to
/// users because Firestore's offline cache makes failed writes still appear
/// to "succeed" locally.
struct SyncErrorBanner: View {
    let message: String
    var onDismiss: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AztecTheme.bloodRed)
                .shadow(color: AztecTheme.bloodRed.opacity(0.6), radius: 4)

            VStack(alignment: .leading, spacing: 4) {
                Text("CLOUD SYNC ERROR")
                    .font(AztecTheme.sfProBold(size: 12))
                    .tracking(1.5)
                    .foregroundColor(AztecTheme.bloodRed)

                Text(message)
                    .font(AztecTheme.sfProMedium(size: 13))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Changes may not be reaching other devices. Check Firestore security rules.")
                    .font(AztecTheme.sfProMedium(size: 11))
                    .foregroundColor(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 4)

            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(AztecTheme.bloodRed, lineWidth: 2)
                .shadow(color: AztecTheme.bloodRed.opacity(0.5), radius: 6)
        )
    }
}
