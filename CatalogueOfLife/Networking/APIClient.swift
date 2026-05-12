import Foundation

protocol APIClient: Sendable {
    func getDataset(_ keyOrAlias: String) async throws -> DatasetRef
    func listReleases() async throws -> [DatasetRef]
    func searchNames(datasetKey: Int, q: String) async throws -> [SearchHit]
    func getTaxonInfo(datasetKey: Int, taxonId: String) async throws -> TaxonInfo
}

// MARK: - Forward-ref placeholder (replaced in Task 12)

/// Placeholder. Real definition lands in Plan Task 12.
struct TaxonInfo: Sendable, Equatable {}
