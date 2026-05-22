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
        #if DEBUG
        let start = Date()
        #endif
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(from: url)
        } catch let urlError as URLError {
            #if DEBUG
            NetworkLog.log(tag: "CoL", method: "GET", url: url, status: nil, error: urlError, start: start)
            #endif
            throw APIError.network(urlError)
        }
        guard let http = response as? HTTPURLResponse else {
            #if DEBUG
            NetworkLog.log(tag: "CoL", method: "GET", url: url, status: -1, error: nil, start: start)
            #endif
            throw APIError.server(status: -1)
        }
        #if DEBUG
        NetworkLog.log(tag: "CoL", method: "GET", url: url, status: http.statusCode, error: nil, start: start)
        #endif
        switch http.statusCode {
        case 200..<300:
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                #if DEBUG
                NetworkLog.decodeFailed(tag: "CoL", url: url, error: error, body: data)
                #endif
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
    func searchNames(datasetKey: Int, q: String, rank: Rank?, status: TaxonStatus?, group: String?, taxonId: String?, content: SearchContent, facets: [String]) async throws -> SearchResult {
        let url = Endpoints.nameSearch(datasetKey: datasetKey, q: q, rank: rank, status: status, group: group, taxonId: taxonId, content: content, facets: facets)
        let dto = try await getJSON(url, as: NameSearchResponseDTO.self)
        return SearchResult(dto: dto)
    }

    func getTreeClassification(datasetKey: Int, taxonId: String) async throws -> [TreeNode] {
        let url = Endpoints.tree(datasetKey: datasetKey, taxonId: taxonId)
        let dtos = try await getJSON(url, as: [TreeNodeDTO].self)
        return dtos.map(TreeNode.init(dto:))
    }
    func getTaxonInfo(datasetKey: Int, taxonId: String) async throws -> TaxonInfo {
        let url = Endpoints.taxonInfo(datasetKey: datasetKey, taxonId: taxonId)
        let dto = try await getJSON(url, as: TaxonInfoDTO.self)
        return TaxonInfo(dto: dto)
    }

    func getNomRelTypeVocab() async throws -> [NomRelTypeVocabEntry] {
        try await getJSON(Endpoints.nomRelTypeVocab, as: [NomRelTypeVocabEntry].self)
    }

    func getNameLabel(datasetKey: Int, nameId: String) async throws -> String? {
        let dto = try await getJSON(Endpoints.name(datasetKey: datasetKey, nameId: nameId), as: NameDTO.self)
        if let label = dto.label, !label.isEmpty { return label }
        guard let sci = dto.scientificName, !sci.isEmpty else { return nil }
        if let auth = dto.authorship, !auth.isEmpty { return "\(sci) \(auth)" }
        return sci
    }

    func getTreeChildren(datasetKey: Int, parentId: String?, offset: Int) async throws -> TreeChildrenPage {
        let url = Endpoints.treeChildren(datasetKey: datasetKey, parentId: parentId, offset: offset)
        let paged = try await getJSON(url, as: PagedDTO<TreeNodeDTO>.self)
        // `last` is the only reliable end-of-pages signal here — see PagedDTO.
        // If the server omits it for some reason, fall back to "empty page = end".
        let hasMore: Bool
        if let last = paged.last {
            hasMore = !last
        } else {
            hasMore = !paged.result.isEmpty
        }
        return TreeChildrenPage(
            nodes: paged.result.map(TreeNode.init(dto:)),
            hasMore: hasMore,
            offset: paged.offset ?? offset
        )
    }

    func suggest(datasetKey: Int, q: String) async throws -> [TaxonSuggestion] {
        let url = Endpoints.suggest(datasetKey: datasetKey, q: q)
        let dtos = try await getJSON(url, as: [SuggestEntryDTO].self)
        return dtos.map(TaxonSuggestion.init(dto:))
    }

    func getClassification(datasetKey: Int, taxonId: String) async throws -> [ClassificationItem] {
        let url = Endpoints.classification(datasetKey: datasetKey, taxonId: taxonId)
        let dtos = try await getJSON(url, as: [ClassificationEntryDTO].self)
        return dtos.map { ClassificationItem(id: $0.id, name: $0.name, rank: Rank(apiValue: $0.rank)) }
    }

    func listSources(datasetKey: Int) async throws -> [Source] {
        let url = Endpoints.sources(datasetKey: datasetKey)
        let dtos = try await getJSON(url, as: [SourceDTO].self)
        return dtos.map(Source.init(dto:))
    }

    func getSource(datasetKey: Int, sourceKey: Int) async throws -> Source {
        let url = Endpoints.source(datasetKey: datasetKey, sourceKey: sourceKey)
        let dto = try await getJSON(url, as: SourceDTO.self)
        return Source(dto: dto)
    }

    func getDatasetBreakdown(datasetKey: Int) async throws -> BreakdownNode {
        let url = Endpoints.datasetBreakdown(datasetKey: datasetKey)
        let dto = try await getJSON(url, as: BreakdownDTO.self)
        return BreakdownNode(
            id: "root",
            group: nil,
            count: dto.breakdown.reduce(0) { $0 + $1.count },
            children: dto.breakdown.map { BreakdownNode(dto: $0) }
        )
    }

    func getImportMetrics(datasetKey: Int) async throws -> ImportMetrics? {
        let url = Endpoints.importMetrics(datasetKey: datasetKey)
        let dtos = try await getJSON(url, as: [ImportMetricsDTO].self)
        return dtos.first.map(ImportMetrics.init(dto:))
    }

    func getTaxonBreakdown(datasetKey: Int, taxonId: String) async throws -> [SunburstNode] {
        let url = Endpoints.taxonBreakdown(datasetKey: datasetKey, taxonId: taxonId)
        let dtos = try await getJSON(url, as: [TaxonBreakdownEntryDTO].self)
        return dtos.map(SunburstNode.from(taxonBreakdown:))
    }

    func getTaxonMetrics(datasetKey: Int, taxonId: String) async throws -> TaxonMetrics {
        let url = Endpoints.taxonMetrics(datasetKey: datasetKey, taxonId: taxonId)
        let dto = try await getJSON(url, as: TaxonMetricsDTO.self)
        return TaxonMetrics(dto: dto)
    }

    func getGroupMetrics(datasetKey: Int, group: String) async throws -> GroupBreakdownMetrics {
        let url = Endpoints.nameSearchFacets(datasetKey: datasetKey, group: group)
        let dto = try await getJSON(url, as: NameSearchFacetsDTO.self)
        var ranks: [Rank: Int] = [:]
        for entry in dto.facets?["rank"] ?? [] {
            ranks[Rank(apiValue: entry.value)] = entry.count
        }
        var statuses: [String: Int] = [:]
        for entry in dto.facets?["status"] ?? [] {
            statuses[entry.value] = entry.count
        }
        return GroupBreakdownMetrics(
            total: dto.total ?? 0,
            taxaByRank: ranks,
            countsByStatus: statuses
        )
    }

    func submitFeedback(datasetKey: Int, taxonId: String, message: String, email: String) async throws -> URL {
        let url = Endpoints.feedback(datasetKey: datasetKey, taxonId: taxonId)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = ["message": message, "email": email]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        #if DEBUG
        let start = Date()
        #endif
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError {
            #if DEBUG
            NetworkLog.log(tag: "CoL", method: "POST", url: url, status: nil, error: urlError, start: start)
            #endif
            throw APIError.network(urlError)
        }
        guard let http = response as? HTTPURLResponse else {
            #if DEBUG
            NetworkLog.log(tag: "CoL", method: "POST", url: url, status: -1, error: nil, start: start)
            #endif
            throw APIError.server(status: -1)
        }
        #if DEBUG
        NetworkLog.log(tag: "CoL", method: "POST", url: url, status: http.statusCode, error: nil, start: start)
        #endif
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.server(status: http.statusCode)
        }
        // Response body is a JSON string (e.g. "https://github.com/.../issues/1575")
        let urlString: String
        if let decoded = try? JSONDecoder().decode(String.self, from: data) {
            urlString = decoded
        } else if let raw = String(data: data, encoding: .utf8) {
            // Fallback: maybe not JSON-quoted
            urlString = raw.trimmingCharacters(in: CharacterSet(charactersIn: "\"\n "))
        } else {
            throw APIError.decoding("empty feedback response")
        }
        guard let result = URL(string: urlString) else {
            throw APIError.decoding("invalid feedback response url: \(urlString)")
        }
        return result
    }
}
