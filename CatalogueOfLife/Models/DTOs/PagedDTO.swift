import Foundation

/// Paged list wrapper from ChecklistBank.
///
/// The API omits the `result` key entirely when a query returns zero hits
/// (`{"total":0,"empty":true,"last":true}`), so `result` must be decoded as
/// optional. Use the `result` computed property to get a stable `[T]`.
struct PagedDTO<T: Decodable & Sendable>: Decodable, Sendable {
    private let _result: [T]?
    let total: Int?
    let offset: Int?
    let limit: Int?
    /// True iff this is the last page. ChecklistBank's `/tree/{id}/children`
    /// returns a `total` that's just `offset + result.count` (a running
    /// counter, not the true server-side total), so `last` is the reliable
    /// signal for whether another page exists.
    let last: Bool?

    var result: [T] { _result ?? [] }

    private enum CodingKeys: String, CodingKey {
        case _result = "result"
        case total, offset, limit, last
    }
}
