import SwiftUI

/// Brand-blue full-screen view shown over the root tab view while the app
/// is doing its initial setup (the parallel `/dataset` fetches in
/// `AppState.loadReleases()` plus the keyboard pre-warm). Fades out once
/// the launch task completes, or after a short cap if the network is slow.
struct SplashView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.09, green: 0.51, blue: 0.69),  // #1782b0 — CoL brand blue
                    Color(red: 0.03, green: 0.36, blue: 0.50),  // darker
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                Image("CoLLogoWhite")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 280)
                    .padding(.horizontal, 32)
                ProgressView()
                    .tint(.white)
                    .scaleEffect(0.9)
            }
        }
    }
}
