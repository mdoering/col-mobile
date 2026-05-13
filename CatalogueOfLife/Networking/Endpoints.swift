import Foundation

enum Endpoints {
    static let baseURL = URL(string: "https://api.checklistbank.org")!

    static func dataset(_ keyOrAlias: String) -> URL {
        baseURL.appending(path: "dataset").appending(path: keyOrAlias)
    }

    static func datasetList(limit: Int = 200, offset: Int = 0, origins: [String] = ["release", "xrelease"]) -> URL {
        var c = URLComponents(url: baseURL.appending(path: "dataset"), resolvingAgainstBaseURL: false)!
        var items: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset)),
        ]
        items.append(contentsOf: origins.map { URLQueryItem(name: "origin", value: $0) })
        c.queryItems = items
        return c.url!
    }

    static func nameSearch(datasetKey: Int, q: String, rank: Rank? = nil, status: TaxonStatus? = nil, group: String? = nil, limit: Int = 25) -> URL {
        var c = URLComponents(
            url: baseURL.appending(path: "dataset/\(datasetKey)/nameusage/search"),
            resolvingAgainstBaseURL: false
        )!
        var items: [URLQueryItem] = [
            URLQueryItem(name: "q", value: q),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        if let rank { items.append(URLQueryItem(name: "rank", value: rank.rawValue)) }
        if let status {
            // The API accepts the rawValue from our enum directly (e.g. "accepted", "synonym").
            items.append(URLQueryItem(name: "status", value: status.rawValue))
        }
        if let group, !group.isEmpty { items.append(URLQueryItem(name: "group", value: group)) }
        c.queryItems = items
        return c.url!
    }

    static func taxonInfo(datasetKey: Int, taxonId: String) -> URL {
        baseURL
            .appending(path: "dataset")
            .appending(path: "\(datasetKey)")
            .appending(path: "taxon")
            .appending(path: taxonId)
            .appending(path: "info")
    }

    static func treeChildren(datasetKey: Int, parentId: String?, limit: Int = 100) -> URL {
        var path = "dataset/\(datasetKey)/tree"
        if let parentId { path += "/\(parentId)/children" }
        var c = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false)!
        // `insertPlaceholder=true` asks the server to synthesise "Not assigned"
        // pseudo-nodes (id ends in --incertae-sedis--RANK) so the tree always
        // shows children of a single rank under each parent. The placeholders
        // are navigable like real taxa but must not open as taxon details.
        c.queryItems = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "insertPlaceholder", value: "true"),
        ]
        return c.url!
    }

    static func suggest(datasetKey: Int, q: String, limit: Int = 15) -> URL {
        var c = URLComponents(
            url: baseURL.appending(path: "dataset/\(datasetKey)/nameusage/suggest"),
            resolvingAgainstBaseURL: false
        )!
        c.queryItems = [
            URLQueryItem(name: "q", value: q),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        return c.url!
    }

    static func classification(datasetKey: Int, taxonId: String) -> URL {
        baseURL
            .appending(path: "dataset")
            .appending(path: "\(datasetKey)")
            .appending(path: "taxon")
            .appending(path: taxonId)
            .appending(path: "classification")
    }

    static func sources(datasetKey: Int, limit: Int = 300) -> URL {
        var c = URLComponents(
            url: baseURL.appending(path: "dataset/\(datasetKey)/source"),
            resolvingAgainstBaseURL: false
        )!
        c.queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        return c.url!
    }

    static func source(datasetKey: Int, sourceKey: Int) -> URL {
        baseURL
            .appending(path: "dataset")
            .appending(path: "\(datasetKey)")
            .appending(path: "source")
            .appending(path: "\(sourceKey)")
    }

    static func datasetBreakdown(datasetKey: Int) -> URL {
        baseURL.appending(path: "dataset/\(datasetKey)/breakdown")
    }

    static func taxonBreakdown(datasetKey: Int, taxonId: String) -> URL {
        baseURL
            .appending(path: "dataset").appending(path: "\(datasetKey)")
            .appending(path: "taxon").appending(path: taxonId)
            .appending(path: "breakdown")
    }

    static func taxonMetrics(datasetKey: Int, taxonId: String) -> URL {
        baseURL
            .appending(path: "dataset").appending(path: "\(datasetKey)")
            .appending(path: "taxon").appending(path: taxonId)
            .appending(path: "metrics")
    }

    static func importMetrics(datasetKey: Int) -> URL {
        baseURL.appending(path: "dataset/\(datasetKey)/import")
    }

    static func feedback(datasetKey: Int, taxonId: String) -> URL {
        baseURL
            .appending(path: "dataset")
            .appending(path: "\(datasetKey)")
            .appending(path: "nameusage")
            .appending(path: taxonId)
            .appending(path: "feedback")
    }

    static func nameSearchFacets(datasetKey: Int, group: String) -> URL {
        var c = URLComponents(
            url: baseURL.appending(path: "dataset/\(datasetKey)/nameusage/search"),
            resolvingAgainstBaseURL: false
        )!
        c.queryItems = [
            URLQueryItem(name: "group", value: group),
            URLQueryItem(name: "limit", value: "0"),
            URLQueryItem(name: "facet", value: "rank"),
            URLQueryItem(name: "facet", value: "status"),
            URLQueryItem(name: "facetLimit", value: "50"),
        ]
        return c.url!
    }
}
