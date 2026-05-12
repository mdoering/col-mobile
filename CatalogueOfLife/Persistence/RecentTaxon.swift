import Foundation
import SwiftData

@Model
final class RecentTaxon {
    @Attribute(.unique) var compositeKey: String
    var datasetKey: Int
    var taxonId: String
    var name: String
    var rank: String
    var group: String?
    var lastVisited: Date

    init(datasetKey: Int, taxonId: String, name: String, rank: String, group: String?) {
        self.compositeKey = Favorite.key(datasetKey: datasetKey, taxonId: taxonId)
        self.datasetKey = datasetKey
        self.taxonId = taxonId
        self.name = name
        self.rank = rank
        self.group = group
        self.lastVisited = Date()
    }
}
