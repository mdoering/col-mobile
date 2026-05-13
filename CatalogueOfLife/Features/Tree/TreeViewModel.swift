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
            let nodes = try await client.getTreeChildren(datasetKey: key, parentId: parentId)
            state = .loaded(nodes)
        } catch let err as APIError {
            state = .failed(err)
        } catch {
            state = .failed(.server(status: -1))
        }
    }
}
