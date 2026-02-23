import SwiftUI

/// Splash screen: YFS logo slowly expands, then crossfades to the GFOUR door image rotated 90°.
struct SplashView: View {
    @State private var logoScale: CGFloat = 0.5
    @State private var logoOpacity: Double = 1.0
    @State private var showDoor: Bool = false
    @State private var doorOpacity: Double = 0.0

    var body: some View {
        ZStack {
            // Base background
            AztecTheme.obsidian.ignoresSafeArea()

            // YFS Logo - slowly expands
            Image("YFS_Logo3_MEDIUM")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 280)
                .scaleEffect(logoScale)
                .opacity(logoOpacity)

            // GFOUR Door - rotated 90 degrees
            if showDoor {
                Image("GFOUR_Door")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 300)
                    .rotationEffect(.degrees(90))
                    .opacity(doorOpacity)
            }
        }
        .onAppear {
            // Logo slowly expands over 2 seconds
            withAnimation(.easeOut(duration: 2.0)) {
                logoScale = 1.0
            }

            // After 1.8s, start crossfade to door image
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                showDoor = true

                withAnimation(.easeInOut(duration: 0.6)) {
                    logoOpacity = 0.0
                    doorOpacity = 1.0
                }
            }
        }
    }
}
