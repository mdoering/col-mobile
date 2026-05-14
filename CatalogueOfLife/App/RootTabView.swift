import SwiftUI

struct RootTabView: View {
    @Environment(AppState.self) private var appState
    @State private var showingFavorites = false
    /// Owned at the tab level so the suggest-pick handler can append a whole
    /// classification path in one go, and so the path survives if a TreeView
    /// instance lower down re-mounts.
    @State private var treePath: [TreeRoute] = []

    var body: some View {
        TabView(selection: Binding(
            get: { appState.selectedTabIndex },
            set: { appState.selectedTabIndex = $0 }
        )) {
            NavigationStack(path: $treePath) {
                TreeView(path: $treePath)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Image("CoLLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 28, height: 28)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .accessibilityLabel("Catalogue of Life")
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                showingFavorites = true
                            } label: {
                                Image(systemName: "star.circle")
                            }
                            .accessibilityLabel("Open bookmarks")
                        }
                    }
                    .navigationDestination(for: TreeRoute.self) { route in
                        switch route {
                        case let .child(id, name):
                            TreeView(rootParentId: id, rootParentName: name, path: $treePath)
                        case let .taxon(id):
                            TaxonDetailView(taxonId: id)
                        }
                    }
            }
            .tabItem { Label("Tree", systemImage: "tree") }
            .tag(0)

            SearchView()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag(1)
            SourcesView()
                .tabItem { Label("Sources", systemImage: "books.vertical") }
                .tag(2)
            MetricsView()
                .tabItem { Label("Metrics", systemImage: "chart.pie") }
                .tag(3)
            AboutView()
                .tabItem { Label("About", systemImage: "info.circle") }
                .tag(4)
        }
        .sheet(isPresented: $showingFavorites) {
            FavoritesSheet()
        }
    }
}
