import Testing
@testable import CatalogueOfLife

@Suite("FavoritesSheetViewModel")
@MainActor
struct FavoritesSheetViewModelTests {

    private func fav(datasetKey: Int, taxonId: String) -> Favorite {
        Favorite(datasetKey: datasetKey, taxonId: taxonId, name: "X", authorship: nil, rank: "species", group: nil)
    }

    @Test("Splits favorites into current-dataset vs other buckets")
    func splitsByDataset() {
        let vm = FavoritesSheetViewModel()
        let favorites = [fav(datasetKey: 1, taxonId: "A"), fav(datasetKey: 1, taxonId: "B"), fav(datasetKey: 2, taxonId: "C")]
        vm.update(favorites: favorites, currentDatasetKey: 1)
        #expect(vm.datasetFavoritesCount == 2)
        #expect(vm.otherDatasetFavoritesCount == 1)
    }

    @Test("Counts all as 'other' when no current dataset")
    func noCurrentDataset() {
        let vm = FavoritesSheetViewModel()
        vm.update(favorites: [fav(datasetKey: 1, taxonId: "A")], currentDatasetKey: nil)
        #expect(vm.datasetFavoritesCount == 0)
        #expect(vm.otherDatasetFavoritesCount == 1)
    }
}
