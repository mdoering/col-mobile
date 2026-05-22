import Foundation
import Observation

@MainActor
@Observable
final class TreeViewModel {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded([TreeNode])
        case failed(APIError)
    }

    let parentId: String?
    let parentName: String?
    private(set) var state: LoadState = .idle
    /// True while a `loadMore()` page request is in flight. Drives the
    /// footer spinner so users see progress without blocking the list.
    private(set) var isLoadingMore = false
    /// Server-reported "more pages exist past the last fetch". Sourced from
    /// the `/tree/{id}/children` response's `last` flag — see TreeChildrenPage.
    private(set) var hasMore: Bool = false

    private let client: APIClient
    private let getDatasetKey: @MainActor () -> Int?

    init(parentId: String?,
         parentName: String?,
         client: APIClient,
         getDatasetKey: @escaping @MainActor () -> Int?) {
        self.parentId = parentId
        self.parentName = parentName
        self.client = client
        self.getDatasetKey = getDatasetKey
    }

    func load() async {
        // If the dataset isn't resolved yet (cold launch — AppState.loadReleases() still in flight),
        // show a loading spinner and wait for the view to re-fire when the key arrives.
        guard let key = getDatasetKey() else {
            state = .loading
            return
        }
        state = .loading
        do {
            let page = try await client.getTreeChildren(datasetKey: key, parentId: parentId, offset: 0)
            state = .loaded(page.nodes)
            hasMore = page.hasMore
        } catch let err as APIError {
            state = .failed(err)
        } catch {
            state = .failed(.server(status: -1))
        }
    }

    /// Fetch the next page and append it to the already-loaded children.
    /// Quiet no-op if we're not in a `.loaded` state, already fetching, or
    /// already at the end. Errors are swallowed so a failed page-load just
    /// stops the infinite scroll rather than wiping the visible list.
    func loadMore() async {
        guard !isLoadingMore, hasMore else { return }
        guard let key = getDatasetKey() else { return }
        guard case let .loaded(existing) = state else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        // The server appends synthesised "Not assigned" (--incertae-sedis--)
        // placeholders to every non-empty page. Naively concatenating would
        // weave them into the middle of the list; instead, keep real children
        // and placeholders separate and always render placeholders last.
        // `offset` is the real-children count so we don't re-fetch a page we
        // already have just because the previous page added a placeholder.
        let existingReal = existing.filter { !$0.isPlaceholder }
        let existingPlaceholders = existing.filter { $0.isPlaceholder }
        do {
            let page = try await client.getTreeChildren(datasetKey: key, parentId: parentId, offset: existingReal.count)
            // Dedupe by id within each bucket: defensive against duplicate
            // fires (e.g. List's .onAppear can briefly re-fire the last row
            // during a layout pass) and against the placeholder repeating
            // across pages.
            let realIds = Set(existingReal.map(\.id))
            let newReal = page.nodes.filter { !$0.isPlaceholder && !realIds.contains($0.id) }
            let placeholderIds = Set(existingPlaceholders.map(\.id))
            let newPlaceholders = page.nodes.filter { $0.isPlaceholder && !placeholderIds.contains($0.id) }
            let combined = existingReal + newReal + existingPlaceholders + newPlaceholders
            state = .loaded(combined)
            hasMore = page.hasMore
        } catch {
            // Leave the visible list intact and stop the spinner.
        }
    }
}
