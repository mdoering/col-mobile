import Foundation
import Observation

@MainActor
@Observable
final class SourcesViewModel {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded([Source])
        case failed(APIError)
    }

    private(set) var state: LoadState = .idle
    var query: String = ""

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
            let sources = try await client.listSources(datasetKey: key)
            state = .loaded(sources)
        } catch let err as APIError {
            state = .failed(err)
        } catch {
            state = .failed(.server(status: -1))
        }
    }

    func filtered() -> [Source] {
        guard case let .loaded(sources) = state else { return [] }
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty { return sources }
        return sources.filter { $0.title.lowercased().contains(q) || ($0.alias?.lowercased().contains(q) ?? false) }
    }
}
