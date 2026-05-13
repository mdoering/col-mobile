import SwiftUI

struct RootTabView: View {
    @Environment(AppState.self) private var appState
    @State private var showingFavorites = false

    var body: some View {
        let _ = print("[ROOT-TAB] body eval, selectedTabIndex=\(appState.selectedTabIndex)")
        // Use an explicit Binding rather than @Bindable's projected value —
        // programmatic writes to selectedTabIndex from deeply pushed views
        // weren't reliably committing through the @Bindable path on iOS 26.
        TabView(selection: Binding(
            get: {
                print("[ROOT-TAB] binding.get → \(appState.selectedTabIndex)")
                return appState.selectedTabIndex
            },
            set: { newVal in
                print("[ROOT-TAB] binding.set ← \(newVal)")
                appState.selectedTabIndex = newVal
            }
        )) {
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
