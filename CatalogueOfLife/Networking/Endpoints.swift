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

    static func nameSearch(datasetKey: Int, q: String, limit: Int = 25) -> URL {
        var c = URLComponents(
            url: baseURL.appending(path: "dataset/\(datasetKey)/nameusage/search"),
            resolvingAgainstBaseURL: false
        )!
        c.queryItems = [
            URLQueryItem(name: "q", value: q),
            URLQueryItem(name: "limit", value: String(limit))
        ]
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
        c.queryItems = [URLQueryItem(name: "limit", value: String(limit))]
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
}
