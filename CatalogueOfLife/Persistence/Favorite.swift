import Foundation
import SwiftData

@Model
final class Favorite {
    /// Unique composite identifier: "<datasetKey>:<taxonId>" — SwiftData doesn't support
    /// multi-attribute uniqueness, so we synthesize the key client-side.
    @Attribute(.unique) var compositeKey: String
    var datasetKey: Int
    var taxonId: String
    var name: String
    var authorship: String?
    var rank: String
    var group: String?
    var addedAt: Date

    init(datasetKey: Int, taxonId: String, name: String, authorship: String?, rank: String, group: String?) {
        self.compositeKey = Self.key(datasetKey: datasetKey, taxonId: taxonId)
        self.datasetKey = datasetKey
        self.taxonId = taxonId
        self.name = name
        self.authorship = authorship
        self.rank = rank
        self.group = group
        self.addedAt = Date()
    }

    static func key(datasetKey: Int, taxonId: String) -> String {
        "\(datasetKey):\(taxonId)"
    }
}
