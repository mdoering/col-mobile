import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            TabPlaceholderView(title: "Tree", symbol: "tree")
                .tabItem { Label("Tree", systemImage: "tree") }
            TabPlaceholderView(title: "Search", symbol: "magnifyingglass")
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
            TabPlaceholderView(title: "Sources", symbol: "books.vertical")
                .tabItem { Label("Sources", systemImage: "books.vertical") }
            TabPlaceholderView(title: "Metrics", symbol: "chart.pie")
                .tabItem { Label("Metrics", systemImage: "chart.pie") }
            TabPlaceholderView(title: "About", symbol: "info.circle")
                .tabItem { Label("About", systemImage: "info.circle") }
        }
    }
}
