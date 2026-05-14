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
    /// Scope the search to descendants of this taxon id. nil = whole dataset.
    /// Set when the user follows a "search descendants" link from a taxon detail.
    var taxonId: String? = nil
    /// Optional scope label shown in the UI (e.g. the scoped taxon's scientific name).
    var taxonScopeLabel: String? = nil

    private(set) var state: LoadState = .idle

    private let client: APIClient
    private let getDatasetKey: @MainActor () -> Int?
    /// Read the current search content mode at submit time. The mode itself
    /// lives on AppState so it persists across launches; the VM doesn't own it.
    private let getContent: @MainActor () -> SearchContent
    private var inFlight: Task<Void, Never>?

    var debounceMillis: Int = 300       // kept for test compatibility; no longer used

    init(client: APIClient,
         getDatasetKey: @escaping @MainActor () -> Int?,
         getContent: @escaping @MainActor () -> SearchContent = { .scientific }) {
        self.client = client
        self.getDatasetKey = getDatasetKey
        self.getContent = getContent
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
        // A query is the usual trigger, but a taxon-id scope (set when arriving
        // from a "search descendants" link) is enough on its own — there's
        // always a finite descendant list to enumerate.
        let hasScope = (taxonId?.isEmpty == false) || (group?.isEmpty == false)
        guard !trimmed.isEmpty || hasScope else {
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
                    group: group,
                    taxonId: taxonId,
                    content: getContent()
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
