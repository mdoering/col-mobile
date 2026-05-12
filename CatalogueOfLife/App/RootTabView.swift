import SwiftUI

struct RootTabView: View {
    @State private var showingFavorites = false

    var body: some View {
        TabView {
            NavigationStack {
                TreeView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                showingFavorites = true
                            } label: {
                                Image(systemName: "star.circle")
                            }
                            .accessibilityLabel("Open bookmarks")
                        }
                    }
            }
            .tabItem { Label("Tree", systemImage: "tree") }

            SearchView()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
            SourcesView()
                .tabItem { Label("Sources", systemImage: "books.vertical") }
            MetricsView()
                .tabItem { Label("Metrics", systemImage: "chart.pie") }
            TabPlaceholderView(title: "About", symbol: "info.circle")
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .sheet(isPresented: $showingFavorites) {
            FavoritesSheet()
        }
    }
}
