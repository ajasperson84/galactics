import SwiftUI
import AVKit

/// Splash screen: YFS_MED logo slowly expands, then transitions to G4_SPLASH video.
struct SplashView: View {
    @State private var logoScale: CGFloat = 0.5
    @State private var logoOpacity: Double = 1.0
    @State private var showVideo: Bool = false
    @State private var videoOpacity: Double = 0.0

    var body: some View {
        ZStack {
            // Base background
            AztecTheme.obsidian.ignoresSafeArea()

            // YFS Logo - slowly expands
            Image("YFS_MED")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 280)
                .scaleEffect(logoScale)
                .opacity(logoOpacity)

            // G4 Splash Video
            if showVideo {
                SplashVideoPlayer()
                    .opacity(videoOpacity)
                    .ignoresSafeArea()
            }
        }
        .onAppear {
            // Logo slowly expands over 2 seconds
            withAnimation(.easeOut(duration: 2.0)) {
                logoScale = 1.0
            }

            // After 1.8s, crossfade to video
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                showVideo = true

                withAnimation(.easeInOut(duration: 0.6)) {
                    logoOpacity = 0.0
                    videoOpacity = 1.0
                }
            }
        }
    }
}

/// AVPlayer wrapper that plays the G4_SPLASH video once from the app bundle.
struct SplashVideoPlayer: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.showsPlaybackControls = false
        controller.videoGravity = .resizeAspectFill

        if let url = Bundle.main.url(forResource: "G4_SPLASH", withExtension: "mp4") {
            let player = AVPlayer(url: url)
            controller.player = player
            player.play()
        }

        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}
}
