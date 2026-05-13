import Foundation

protocol GBIFClient: Sendable {
    func getOccurrenceMetrics(taxonId: String) async throws -> GBIFMetrics
    func getOccurrenceImages(taxonId: String, limit: Int) async throws -> [GBIFMediaItem]
    func getMapCapabilities(taxonId: String) async throws -> GBIFMapCapabilities?
}

