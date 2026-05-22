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
    func searchNames(datasetKey: Int, q: String, rank: Rank?, status: TaxonStatus?, group: String?, taxonId: String?, content: SearchContent, facets: [String]) async throws -> SearchResult {
        if let error { throw error }
        let hits = searchResults[q] ?? []   // filters ignored in tests
        return SearchResult(total: hits.count, hits: hits, facets: searchFacets[q] ?? [:])
    }
    var searchFacets: [String: [String: [String: Int]]] = [:]

    func getNameLabel(datasetKey: Int, nameId: String) async throws -> String? {
        if let error { throw error }
        return nameLabels[nameId]
    }
    var nameLabels: [String: String] = [:]

    func getTreeClassification(datasetKey: Int, taxonId: String) async throws -> [TreeNode] {
        if let error { throw error }
        return treeClassifications[taxonId] ?? []
    }
    var treeClassifications: [String: [TreeNode]] = [:]
    func getTaxonInfo(datasetKey: Int, taxonId: String) async throws -> TaxonInfo {
        if let error { throw error }
        guard let info = taxonInfo[taxonId] else { throw APIError.notFound }
        return info
    }

    /// If set, the stub appends this placeholder to every non-empty page for
    /// the given parentId — mirrors the server's `insertPlaceholder=true`
    /// behavior which adds a synthesised "Not assigned" node to each page.
    var treeChildrenPlaceholder: [String: TreeNode] = [:]

    func getTreeChildren(datasetKey: Int, parentId: String?, offset: Int) async throws -> TreeChildrenPage {
        if let error { throw error }
        let key = parentId ?? "root"
        let all = treeChildren[key] ?? []
        // Mirror the live client's 100-per-page slicing so paging tests can
        // exercise the offset path with realistic fixtures.
        let pageSize = 100
        var slice = Array(all.dropFirst(offset).prefix(pageSize))
        let hasMore = (offset + slice.count) < all.count
        if !slice.isEmpty, let placeholder = treeChildrenPlaceholder[key] {
            slice.append(placeholder)
        }
        return TreeChildrenPage(nodes: slice, hasMore: hasMore, offset: offset)
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

    var groupMetrics: [String: GroupBreakdownMetrics] = [:]

    func getGroupMetrics(datasetKey: Int, group: String) async throws -> GroupBreakdownMetrics {
        if let error { throw error }
        guard let m = groupMetrics[group] else { throw APIError.notFound }
        return m
    }

    var feedbackResult: URL? = URL(string: "https://github.com/CatalogueOfLife/data/issues/0")

    func submitFeedback(datasetKey: Int, taxonId: String, message: String, email: String) async throws -> URL {
        if let error { throw error }
        guard let url = feedbackResult else { throw APIError.notFound }
        return url
    }

    var nomRelTypeVocab: [NomRelTypeVocabEntry] = []

    func getNomRelTypeVocab() async throws -> [NomRelTypeVocabEntry] {
        if let error { throw error }
        return nomRelTypeVocab
    }
}
