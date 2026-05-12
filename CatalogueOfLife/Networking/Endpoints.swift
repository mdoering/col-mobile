import Foundation

enum Endpoints {
    static let baseURL = URL(string: "https://api.checklistbank.org")!

    static func dataset(_ keyOrAlias: String) -> URL {
        baseURL.appending(path: "dataset").appending(path: keyOrAlias)
    }

    static func datasetList(limit: Int = 100, offset: Int = 0) -> URL {
        var c = URLComponents(url: baseURL.appending(path: "dataset"), resolvingAgainstBaseURL: false)!
        c.queryItems = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset)),
            URLQueryItem(name: "origin", value: "released")
        ]
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
        baseURL.appending(path: "dataset/\(datasetKey)/taxon/\(taxonId)/info")
    }
}
