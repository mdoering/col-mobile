import Foundation
import Observation

@MainActor
@Observable
final class SearchViewModel {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded([SearchHit])
        case failed(APIError)
    }

    var query: String = ""             // no didSet — search fires on submit only
    var rank: Rank? = nil              // nil = Any
    var status: TaxonStatus? = nil     // nil = Any
    var group: String? = nil           // nil = Any. Lowercase vocab name.

    private(set) var state: LoadState = .idle

    private let client: APIClient
    private let getDatasetKey: @MainActor () -> Int?
    private var inFlight: Task<Void, Never>?

    var debounceMillis: Int = 300       // kept for test compatibility; no longer used

    init(client: APIClient, getDatasetKey: @escaping @MainActor () -> Int?) {
        self.client = client
        self.getDatasetKey = getDatasetKey
    }

    /// Called from the view when the user presses Search on the keyboard
    /// or taps a "Search" button.
    func submit() {
        Task { await run() }
    }

    /// Called when the user changes a filter — re-run if there's a query already.
    func reSearchIfQueryPresent() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Task { await run() }
    }

    private func run() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            state = .idle
            inFlight?.cancel()
            return
        }
        guard let key = getDatasetKey() else {
            state = .failed(.server(status: -1))
            return
        }
        inFlight?.cancel()
        state = .loading
        inFlight = Task {
            do {
                let hits = try await client.searchNames(
                    datasetKey: key,
                    q: trimmed,
                    rank: rank,
                    status: status,
                    group: group
                )
                guard !Task.isCancelled else { return }
                state = .loaded(hits)
            } catch let err as APIError {
                guard !Task.isCancelled else { return }
                state = .failed(err)
            } catch {
                state = .failed(.server(status: -1))
            }
        }
    }
}
