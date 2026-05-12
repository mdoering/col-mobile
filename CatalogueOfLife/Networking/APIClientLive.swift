import Foundation

actor APIClientLive: APIClient {
    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = HTTPSession.shared) {
        self.session = session
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        self.decoder = d
    }

    func getJSON<T: Decodable>(_ url: URL, as type: T.Type) async throws -> T {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(from: url)
        } catch let urlError as URLError {
            throw APIError.network(urlError)
        }
        guard let http = response as? HTTPURLResponse else {
            throw APIError.server(status: -1)
        }
        switch http.statusCode {
        case 200..<300:
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw APIError.decoding(String(describing: error))
            }
        case 404:
            throw APIError.notFound
        default:
            throw APIError.server(status: http.statusCode)
        }
    }

    // Real implementations land in Tasks 5–12.
    func getDataset(_ keyOrAlias: String) async throws -> DatasetRef {
        let dto = try await getJSON(Endpoints.dataset(keyOrAlias), as: DatasetDTO.self)
        return DatasetRef(dto: dto)
    }
    func listReleases() async throws -> [DatasetRef] {
        let paged = try await getJSON(Endpoints.datasetList(), as: PagedDTO<DatasetDTO>.self)
        return paged.result.map(DatasetRef.init(dto:))
    }
    func searchNames(datasetKey: Int, q: String) async throws -> [SearchHit] {
        let url = Endpoints.nameSearch(datasetKey: datasetKey, q: q)
        let paged = try await getJSON(url, as: PagedDTO<NameUsageSearchHitDTO>.self)
        return paged.result.map(SearchHit.init(dto:))
    }
    func getTaxonInfo(datasetKey: Int, taxonId: String) async throws -> TaxonInfo { fatalError("Task 12") }
}
