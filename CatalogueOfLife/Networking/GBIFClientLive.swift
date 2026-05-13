import Foundation

actor GBIFClientLive: GBIFClient {
    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = HTTPSession.shared) {
        self.session = session
        self.decoder = JSONDecoder()
    }

    private func getJSON<T: Decodable>(_ url: URL, as type: T.Type) async throws -> T {
        #if DEBUG
        let start = Date()
        #endif
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(from: url)
        } catch let urlError as URLError {
            #if DEBUG
            NetworkLog.log(tag: "GBIF", method: "GET", url: url, status: nil, error: urlError, start: start)
            #endif
            throw APIError.network(urlError)
        }
        guard let http = response as? HTTPURLResponse else {
            #if DEBUG
            NetworkLog.log(tag: "GBIF", method: "GET", url: url, status: -1, error: nil, start: start)
            #endif
            throw APIError.server(status: -1)
        }
        #if DEBUG
        NetworkLog.log(tag: "GBIF", method: "GET", url: url, status: http.statusCode, error: nil, start: start)
        #endif
        switch http.statusCode {
        case 200..<300:
            do { return try decoder.decode(T.self, from: data) }
            catch {
                #if DEBUG
                NetworkLog.decodeFailed(tag: "GBIF", url: url, error: error, body: data)
                #endif
                throw APIError.decoding(String(describing: error))
            }
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

    func getOccurrenceImages(taxonId: String, limit: Int) async throws -> [GBIFMediaItem] {
        let url = GBIFEndpoints.occurrenceSearch(
            taxonId: taxonId,
            limit: limit,
            mediaType: "StillImage"
        )
        let dto = try await getJSON(url, as: OccurrenceWithMediaDTO.self)
        return GBIFMediaItem.from(dto: dto)
    }

    func getMapCapabilities(taxonId: String) async throws -> GBIFMapCapabilities? {
        let url = GBIFEndpoints.mapCapabilities(taxonId: taxonId)
        let dto = try await getJSON(url, as: GBIFMapCapabilitiesDTO.self)
        return GBIFMapCapabilities(dto: dto)
    }
}
