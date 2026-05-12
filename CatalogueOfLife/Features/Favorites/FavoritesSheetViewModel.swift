import Foundation
import Observation

@MainActor
@Observable
final class FavoritesSheetViewModel {
    enum Segment: String, CaseIterable, Sendable { case favorites = "Favorites", recents = "Recents" }
    var segment: Segment = .favorites

    private(set) var datasetFavoritesCount: Int = 0
    private(set) var otherDatasetFavoritesCount: Int = 0

    /// Splits favorites into current-dataset and other-dataset buckets.
    func update(favorites: [Favorite], currentDatasetKey: Int?) {
        guard let key = currentDatasetKey else {
            datasetFavoritesCount = 0
            otherDatasetFavoritesCount = favorites.count
            return
        }
        datasetFavoritesCount = favorites.filter { $0.datasetKey == key }.count
        otherDatasetFavoritesCount = favorites.count - datasetFavoritesCount
    }
}
