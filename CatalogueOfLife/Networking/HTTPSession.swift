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
        cfg.httpAdditionalHeaders = [
            "Accept": "application/json",
            "User-Agent": userAgent,
        ]
        cfg.timeoutIntervalForRequest = 20
        return URLSession(configuration: cfg)
    }()

    /// Identifies our requests to ChecklistBank / GBIF logs.
    /// Format: `CatalogueOfLife/<short-version> (build <build>; iOS <version>)`.
    static let userAgent: String = {
        let info = Bundle.main.infoDictionary
        let version = (info?["CFBundleShortVersionString"] as? String) ?? "0"
        let build = (info?["CFBundleVersion"] as? String) ?? "0"
        let v = ProcessInfo.processInfo.operatingSystemVersion
        let os = "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
        return "CatalogueOfLife/\(version) (build \(build); iOS \(os))"
    }()
}
