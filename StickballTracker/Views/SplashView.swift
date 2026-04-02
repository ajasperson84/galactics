import SwiftUI

/// Splash screen: YFS_MED_GOLD logo slowly expands over 5 seconds.
struct SplashView: View {
    @State private var logoScale: CGFloat = 0.5

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Image("YFS_MED_GOLD")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 280)
                .scaleEffect(logoScale)
                .shadow(color: AztecTheme.hotPink.opacity(0.6), radius: 20)
                .shadow(color: AztecTheme.hotPink.opacity(0.3), radius: 40)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 5.0)) {
                logoScale = 1.0
            }
        }
    }
}
