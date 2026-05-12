import SwiftUI
import SwiftData

@main
struct CatalogueOfLifeApp: App {
    @State private var state: AppState = AppState(client: APIClientLive())
    @State private var vocab: TaxGroupVocab = TaxGroupVocab.loadBundled()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(state)
                .environment(vocab)
                .modelContainer(PersistenceStore.shared)
                .task(id: "launch") { await state.loadReleases() }
        }
    }
}
