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

    var query: String = "" {
        didSet { scheduleSearch() }
    }

    private(set) var state: LoadState = .idle

    private let client: APIClient
    private let getDatasetKey: @MainActor () -> Int?
    private var debounceTask: Task<Void, Never>?
    private var inFlight: Task<Void, Never>?

    /// Debounce duration in milliseconds. Overridable for tests.
    var debounceMillis: Int = 300

    init(client: APIClient, getDatasetKey: @escaping @MainActor () -> Int?) {
        self.client = client
        self.getDatasetKey = getDatasetKey
    }

    private func scheduleSearch() {
        debounceTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            state = .idle
            inFlight?.cancel()
            return
        }
        let delay = debounceMillis
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000)
            guard !Task.isCancelled, let self else { return }
            await self.run(query: trimmed)
        }
    }

    private func run(query: String) async {
        guard let key = getDatasetKey() else {
            state = .failed(.server(status: -1))
            return
        }
        inFlight?.cancel()
        state = .loading
        inFlight = Task {
            do {
                let hits = try await client.searchNames(datasetKey: key, q: query)
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
