import Foundation
@testable import CatalogueOfLife

final class StubAPIClient: APIClient, @unchecked Sendable {
    var releases: [DatasetRef] = []
    var datasetByKey: [String: DatasetRef] = [:]
    var searchResults: [String: [SearchHit]] = [:]
    var taxonInfo: [String: TaxonInfo] = [:]
    var treeChildren: [String: [TreeNode]] = [:]              // key: parentId ?? "root"
    var suggestions: [String: [TaxonSuggestion]] = [:]
    var classifications: [String: [ClassificationItem]] = [:]
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
    func searchNames(datasetKey: Int, q: String, rank: Rank?, status: TaxonStatus?, group: String?) async throws -> [SearchHit] {
        if let error { throw error }
        return searchResults[q] ?? []   // filters ignored in tests
    }
    func getTaxonInfo(datasetKey: Int, taxonId: String) async throws -> TaxonInfo {
        if let error { throw error }
        guard let info = taxonInfo[taxonId] else { throw APIError.notFound }
        return info
    }

    func getTreeChildren(datasetKey: Int, parentId: String?) async throws -> [TreeNode] {
        if let error { throw error }
        return treeChildren[parentId ?? "root"] ?? []
    }
    func suggest(datasetKey: Int, q: String) async throws -> [TaxonSuggestion] {
        if let error { throw error }
        return suggestions[q] ?? []
    }
    func getClassification(datasetKey: Int, taxonId: String) async throws -> [ClassificationItem] {
        if let error { throw error }
        return classifications[taxonId] ?? []
    }

    var sources: [Int: [Source]] = [:]
    var sourceDetail: [Int: Source] = [:]

    func listSources(datasetKey: Int) async throws -> [Source] {
        if let error { throw error }
        return sources[datasetKey] ?? []
    }

    func getSource(datasetKey: Int, sourceKey: Int) async throws -> Source {
        if let error { throw error }
        guard let src = sourceDetail[sourceKey] else { throw APIError.notFound }
        return src
    }

    var datasetBreakdown: [Int: BreakdownNode] = [:]
    var importMetrics: [Int: ImportMetrics] = [:]

    func getDatasetBreakdown(datasetKey: Int) async throws -> BreakdownNode {
        if let error { throw error }
        guard let bd = datasetBreakdown[datasetKey] else { throw APIError.notFound }
        return bd
    }

    func getImportMetrics(datasetKey: Int) async throws -> ImportMetrics? {
        if let error { throw error }
        return importMetrics[datasetKey]
    }

    var taxonBreakdown: [String: [SunburstNode]] = [:]
    var taxonMetrics: [String: TaxonMetrics] = [:]

    func getTaxonBreakdown(datasetKey: Int, taxonId: String) async throws -> [SunburstNode] {
        if let error { throw error }
        return taxonBreakdown[taxonId] ?? []
    }

    func getTaxonMetrics(datasetKey: Int, taxonId: String) async throws -> TaxonMetrics {
        if let error { throw error }
        guard let m = taxonMetrics[taxonId] else { throw APIError.notFound }
        return m
    }

    var feedbackResult: URL? = URL(string: "https://github.com/CatalogueOfLife/data/issues/0")

    func submitFeedback(datasetKey: Int, taxonId: String, message: String, email: String) async throws -> URL {
        if let error { throw error }
        guard let url = feedbackResult else { throw APIError.notFound }
        return url
    }
}
