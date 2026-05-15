import Foundation

protocol APIClient: Sendable {
    func getDataset(_ keyOrAlias: String) async throws -> DatasetRef
    func listReleases() async throws -> [DatasetRef]
    func searchNames(datasetKey: Int, q: String, rank: Rank?, status: TaxonStatus?, group: String?, taxonId: String?, content: SearchContent, facets: [String]) async throws -> SearchResult

    /// Returns the classification path of a taxon — root at index 0, the taxon
    /// itself at the end. Wraps `GET /dataset/{key}/tree/{id}`.
    func getTreeClassification(datasetKey: Int, taxonId: String) async throws -> [TreeNode]
    func getTaxonInfo(datasetKey: Int, taxonId: String) async throws -> TaxonInfo

    /// Resolve a name by id and return its human-readable label
    /// (`scientificName + authorship` if available, falling back to the bare
    /// scientific name). Used to label name-relation rows.
    func getNameLabel(datasetKey: Int, nameId: String) async throws -> String?

    func getTreeChildren(datasetKey: Int, parentId: String?) async throws -> [TreeNode]
    func suggest(datasetKey: Int, q: String) async throws -> [TaxonSuggestion]
    func getClassification(datasetKey: Int, taxonId: String) async throws -> [ClassificationItem]
    func listSources(datasetKey: Int) async throws -> [Source]
    func getSource(datasetKey: Int, sourceKey: Int) async throws -> Source
    func getDatasetBreakdown(datasetKey: Int) async throws -> BreakdownNode
    func getImportMetrics(datasetKey: Int) async throws -> ImportMetrics?

    func getTaxonBreakdown(datasetKey: Int, taxonId: String) async throws -> [SunburstNode]
    func getTaxonMetrics(datasetKey: Int, taxonId: String) async throws -> TaxonMetrics

    func getGroupMetrics(datasetKey: Int, group: String) async throws -> GroupBreakdownMetrics

    /// Submits user feedback for a taxon. Returns the URL of the created GitHub issue.
    func submitFeedback(datasetKey: Int, taxonId: String, message: String, email: String) async throws -> URL

    /// Fetches the global `nomRelType` controlled vocabulary so wire values
    /// can be rendered as canonical human-readable labels.
    func getNomRelTypeVocab() async throws -> [NomRelTypeVocabEntry]
}

struct NomRelTypeVocabEntry: Decodable, Sendable {
    let name: String
    let label: String?
    let description: String?
}

