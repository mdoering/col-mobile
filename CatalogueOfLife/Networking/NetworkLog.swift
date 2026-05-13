import Foundation
import os

/// Debug-only request logger. Compiled to a no-op in release builds.
///
/// Output format: `[<tag>] <method> <url> → <status> (<ms>ms)`.
/// Errored requests log `<error>` in place of the status.
enum NetworkLog {
    #if DEBUG
    private static let logger = Logger(subsystem: "org.catalogueoflife.mobile", category: "net")

    static func log(tag: String, method: String, url: URL, status: Int?, error: Error?, start: Date) {
        let ms = Int(Date().timeIntervalSince(start) * 1000)
        let outcome: String
        if let error {
            outcome = "ERR \((error as? URLError)?.code.rawValue.description ?? String(describing: error))"
        } else if let status {
            outcome = String(status)
        } else {
            outcome = "?"
        }
        logger.debug("[\(tag, privacy: .public)] \(method, privacy: .public) \(url.absoluteString, privacy: .public) → \(outcome, privacy: .public) (\(ms)ms)")
    }
    #else
    static func log(tag: String, method: String, url: URL, status: Int?, error: Error?, start: Date) {}
    #endif
}
