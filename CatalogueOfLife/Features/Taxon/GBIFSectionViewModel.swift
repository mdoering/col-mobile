import Foundation
import Observation

@MainActor
@Observable
final class GBIFSectionViewModel {
    private(set) var metrics: GBIFMetrics?
    private(set) var images: [GBIFMediaItem] = []
    private(set) var didLoad = false
    private(set) var failed = false

    private let client: GBIFClient

    init(client: GBIFClient) {
        self.client = client
    }

    func load(taxonId: String) async {
        didLoad = false
        failed = false
        async let metricsResult = try? await client.getOccurrenceMetrics(taxonId: taxonId)
        async let imagesResult = try? await client.getOccurrenceImages(taxonId: taxonId, limit: 20)
        let m = await metricsResult
        let i = await imagesResult ?? []
        self.metrics = m
        self.images = i
        self.didLoad = true
        self.failed = (m == nil && i.isEmpty)
    }
}
