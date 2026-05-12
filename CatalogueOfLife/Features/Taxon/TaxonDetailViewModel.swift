import Foundation
import Observation

@MainActor
@Observable
final class TaxonDetailViewModel {
    enum LoadState: Equatable {
        case loading
        case loaded(TaxonInfo)
        case failed(APIError)
    }

    private(set) var state: LoadState = .loading

    let taxonId: String
    private let client: APIClient
    private let getDatasetKey: @MainActor () -> Int?

    init(taxonId: String,
         client: APIClient,
         getDatasetKey: @escaping @MainActor () -> Int?) {
        self.taxonId = taxonId
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
            let info = try await client.getTaxonInfo(datasetKey: key, taxonId: taxonId)
            state = .loaded(info)
        } catch let err as APIError {
            state = .failed(err)
        } catch {
            state = .failed(.server(status: -1))
        }
    }
}
