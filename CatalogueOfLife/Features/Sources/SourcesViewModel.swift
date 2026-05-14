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

    /// Which subset of sources to show on extended releases. Plain releases
    /// don't have any merged sources, so the filter is hidden in that case
    /// and `.all` (the default) is the effective behavior.
    enum MergedFilter: String, CaseIterable, Sendable {
        case all
        case base
        case extended
    }

    private(set) var state: LoadState = .idle
    var query: String = ""
    var mergedFilter: MergedFilter = .all

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
        return sources.filter { source in
            guard mergedFilterMatches(source) else { return false }
            guard !q.isEmpty else { return true }
            return source.title.lowercased().contains(q)
                || (source.alias?.lowercased().contains(q) ?? false)
        }
    }

    private func mergedFilterMatches(_ source: Source) -> Bool {
        switch mergedFilter {
        case .all: true
        case .base: !source.merged
        case .extended: source.merged
        }
    }
}
