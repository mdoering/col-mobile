import Foundation

actor GBIFClientLive: GBIFClient {
    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = HTTPSession.shared) {
        self.session = session
        self.decoder = JSONDecoder()
    }

    private func getJSON<T: Decodable>(_ url: URL, as type: T.Type) async throws -> T {
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
            do { return try decoder.decode(T.self, from: data) }
            catch { throw APIError.decoding(String(describing: error)) }
        case 404: throw APIError.notFound
        default: throw APIError.server(status: http.statusCode)
        }
    }

    func getOccurrenceMetrics(taxonId: String) async throws -> GBIFMetrics {
        let url = GBIFEndpoints.occurrenceSearch(
            taxonId: taxonId,
            limit: 0,
            facets: ["country", "datasetKey"]
        )
        let dto = try await getJSON(url, as: OccurrenceSearchDTO.self)
        return GBIFMetrics(dto: dto)
    }

    // Real implementation lands in Task 3:
    func getOccurrenceImages(taxonId: String, limit: Int) async throws -> [GBIFMediaItem] {
        fatalError("Task 3")
    }
}
