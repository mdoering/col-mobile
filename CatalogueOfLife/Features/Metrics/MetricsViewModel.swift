import Foundation
import Observation

@MainActor
@Observable
final class MetricsViewModel {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded(breakdown: BreakdownNode, metrics: ImportMetrics?)
        case failed(APIError)
    }

    private(set) var state: LoadState = .idle

    private let client: APIClient
    private let getDatasetKey: @MainActor () -> Int?

    init(client: APIClient, getDatasetKey: @escaping @MainActor () -> Int?) {
        self.client = client
        self.getDatasetKey = getDatasetKey
    }

    func load() async {
        guard let key = getDatasetKey() else {
            state = .failed(.server(status: -1))
            return
        }
        state = .loading
        do {
            async let breakdown = try await client.getDatasetBreakdown(datasetKey: key)
            async let metrics = try? await client.getImportMetrics(datasetKey: key)
            let bd = try await breakdown
            let m = await metrics ?? nil
            state = .loaded(breakdown: bd, metrics: m)
        } catch let err as APIError {
            state = .failed(err)
        } catch {
            state = .failed(.server(status: -1))
        }
    }
}
