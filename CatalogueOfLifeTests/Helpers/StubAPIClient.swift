import Foundation
@testable import CatalogueOfLife

final class StubAPIClient: APIClient, @unchecked Sendable {
    var releases: [DatasetRef] = []
    var datasetByKey: [String: DatasetRef] = [:]
    var searchResults: [String: [SearchHit]] = [:]
    var taxonInfo: [String: TaxonInfo] = [:]
    var error: APIError?

    func getDataset(_ keyOrAlias: String) async throws -> DatasetRef {
        if let error { throw error }
        guard let r = datasetByKey[keyOrAlias] else { throw APIError.notFound }
        return r
    }
    func listReleases() async throws -> [DatasetRef] {
        if let error { throw error }
        return releases
    }
    func searchNames(datasetKey: Int, q: String) async throws -> [SearchHit] {
        if let error { throw error }
        return searchResults[q] ?? []
    }
    func getTaxonInfo(datasetKey: Int, taxonId: String) async throws -> TaxonInfo {
        if let error { throw error }
        guard let info = taxonInfo[taxonId] else { throw APIError.notFound }
        return info
    }
}
