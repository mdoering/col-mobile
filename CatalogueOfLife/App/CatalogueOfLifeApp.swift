import SwiftUI
import SwiftData

@main
struct CatalogueOfLifeApp: App {
    @State private var state: AppState = AppState(client: APIClientLive())
    @State private var vocab: TaxGroupVocab = TaxGroupVocab.loadBundled()
    @State private var splashHidden = false

    /// Hard cap on the splash duration. If the API is slow or unreachable we
    /// still let the user into the app instead of trapping them on the logo.
    private let splashTimeout: Duration = .seconds(4)

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootTabView()
                    .environment(state)
                    .environment(vocab)
                    .modelContainer(PersistenceStore.shared)

                if !splashHidden {
                    SplashView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .task(id: "launch") {
                await state.loadReleases()
                // Pay the ~1s "first keyboard load" cost during the splash so
                // Search and email fields focus instantly later.
                KeyboardWarmup.warm()
                hideSplash()
            }
            .task(id: "splash-timeout") {
                try? await Task.sleep(for: splashTimeout)
                hideSplash()
            }
        }
    }

    private func hideSplash() {
        guard !splashHidden else { return }
        withAnimation(.easeInOut(duration: 0.4)) {
            splashHidden = true
        }
    }
}
