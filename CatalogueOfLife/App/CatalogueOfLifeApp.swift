import SwiftUI

@main
struct CatalogueOfLifeApp: App {
    @State private var state: AppState = AppState(client: APIClientLive())

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(state)
                .task { await state.loadReleases() }
        }
    }
}
