import SwiftUI
import SwiftData

struct FavoritesSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Favorite.addedAt, order: .reverse) private var favorites: [Favorite]
    @Query(sort: \RecentTaxon.lastVisited, order: .reverse) private var recents: [RecentTaxon]

    @State private var vm = FavoritesSheetViewModel()
    @State private var navigateTo: String?

    private var currentKey: Int? { appState.selectedDataset?.key }
    private var datasetFavorites: [Favorite] { favorites.filter { $0.datasetKey == currentKey } }
    private var datasetRecents: [RecentTaxon] { recents.filter { $0.datasetKey == currentKey } }

    var body: some View {
        @Bindable var vm = vm
        NavigationStack {
            VStack(spacing: 0) {
                Picker("View", selection: $vm.segment) {
                    ForEach(FavoritesSheetViewModel.Segment.allCases, id: \.self) { seg in
                        Text(seg.rawValue).tag(seg)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                Group {
                    switch vm.segment {
                    case .favorites: favoritesList
                    case .recents: recentsList
                    }
                }
            }
            .navigationTitle("Bookmarks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .navigationDestination(item: $navigateTo) { id in
                TaxonDetailView(taxonId: id)
            }
        }
        .task { vm.update(favorites: favorites, currentDatasetKey: currentKey) }
        .onChange(of: favorites) { _, new in vm.update(favorites: new, currentDatasetKey: currentKey) }
        .onChange(of: currentKey) { _, _ in vm.update(favorites: favorites, currentDatasetKey: currentKey) }
    }

    @ViewBuilder
    private var favoritesList: some View {
        if datasetFavorites.isEmpty {
            ContentUnavailableView(
                "No favorites yet",
                systemImage: "star",
                description: Text("Tap the ★ on any taxon page to save it here.")
            )
        } else {
            List(datasetFavorites) { fav in
                Button { navigateTo = fav.taxonId } label: {
                    favRow(fav)
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
            .safeAreaInset(edge: .bottom) {
                if vm.otherDatasetFavoritesCount > 0 {
                    Text("Favorites in other releases (\(vm.otherDatasetFavoritesCount))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .background(.thinMaterial)
                }
            }
        }
    }

    @ViewBuilder
    private var recentsList: some View {
        if datasetRecents.isEmpty {
            ContentUnavailableView(
                "No recents yet",
                systemImage: "clock",
                description: Text("Open a taxon to see it here.")
            )
        } else {
            List(datasetRecents) { row in
                Button { navigateTo = row.taxonId } label: {
                    recentRow(row)
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
        }
    }

    private func favRow(_ fav: Favorite) -> some View {
        HStack(alignment: .top, spacing: 8) {
            GroupIcon(code: fav.group, size: 22).padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(fav.name).italic()
                Text(fav.rank.capitalized).font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private func recentRow(_ row: RecentTaxon) -> some View {
        HStack(alignment: .top, spacing: 8) {
            GroupIcon(code: row.group, size: 22).padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.name).italic()
                Text(row.rank.capitalized).font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}
