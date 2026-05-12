import Foundation

enum HTTPSession {
    static let shared: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.urlCache = URLCache(
            memoryCapacity: 8 * 1024 * 1024,     // 8 MB
            diskCapacity: 50 * 1024 * 1024,      // 50 MB
            directory: nil
        )
        cfg.requestCachePolicy = .useProtocolCachePolicy
        cfg.httpAdditionalHeaders = ["Accept": "application/json"]
        cfg.timeoutIntervalForRequest = 20
        return URLSession(configuration: cfg)
    }()
}
