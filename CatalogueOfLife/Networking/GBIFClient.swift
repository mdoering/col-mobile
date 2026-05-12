import Foundation

protocol GBIFClient: Sendable {
    func getOccurrenceMetrics(taxonId: String) async throws -> GBIFMetrics
    func getOccurrenceImages(taxonId: String, limit: Int) async throws -> [GBIFMediaItem]
}

// MARK: - Forward-ref placeholder (replaced in Task 3)

/// Placeholder. Real definition lands in Plan 4 Task 3.
struct GBIFMediaItem: Sendable, Equatable, Hashable, Identifiable {
    let id: String
}
