import Foundation
@testable import CatalogueOfLife

final class StubGBIFClient: GBIFClient, @unchecked Sendable {
    var metrics: [String: GBIFMetrics] = [:]
    var images: [String: [GBIFMediaItem]] = [:]
    var error: APIError?

    func getOccurrenceMetrics(taxonId: String) async throws -> GBIFMetrics {
        if let error { throw error }
        guard let m = metrics[taxonId] else { throw APIError.notFound }
        return m
    }

    func getOccurrenceImages(taxonId: String, limit: Int) async throws -> [GBIFMediaItem] {
        if let error { throw error }
        return images[taxonId] ?? []
    }
}
