import Foundation

enum APIError: Error, Equatable {
    case network(URLError)
    case server(status: Int)
    case decoding(String)        // String, not DecodingError, so Equatable holds
    case notFound

    static func == (lhs: APIError, rhs: APIError) -> Bool {
        switch (lhs, rhs) {
        case (.notFound, .notFound): true
        case let (.server(a), .server(b)): a == b
        case let (.decoding(a), .decoding(b)): a == b
        case let (.network(a), .network(b)): a.code == b.code
        default: false
        }
    }
}
