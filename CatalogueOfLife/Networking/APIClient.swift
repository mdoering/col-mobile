import Foundation

protocol APIClient: Sendable {
    func getDataset(_ keyOrAlias: String) async throws -> DatasetRef
    func listReleases() async throws -> [DatasetRef]
    func searchNames(datasetKey: Int, q: String) async throws -> [SearchHit]
    func getTaxonInfo(datasetKey: Int, taxonId: String) async throws -> TaxonInfo

    func getTreeChildren(datasetKey: Int, parentId: String?) async throws -> [TreeNode]
    func suggest(datasetKey: Int, q: String) async throws -> [TaxonSuggestion]
    func getClassification(datasetKey: Int, taxonId: String) async throws -> [ClassificationItem]
    func listSources(datasetKey: Int) async throws -> [Source]
    func getSource(datasetKey: Int, sourceKey: Int) async throws -> Source
    func getDatasetBreakdown(datasetKey: Int) async throws -> BreakdownNode
    func getImportMetrics(datasetKey: Int) async throws -> ImportMetrics?

    /// Submits user feedback for a taxon. Returns the URL of the created GitHub issue.
    func submitFeedback(datasetKey: Int, taxonId: String, message: String, email: String) async throws -> URL
}

