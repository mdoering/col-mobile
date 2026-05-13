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
        // Cold-launch race: AppState.loadReleases() may not have resolved yet. Stay in
        // .loading and rely on the view's `.task(id: …key)` to re-fire when the key arrives.
        guard let key = getDatasetKey() else {
            state = .loading
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
