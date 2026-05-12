import Foundation

struct PagedDTO<T: Decodable & Sendable>: Decodable, Sendable {
    let result: [T]
    let total: Int?
    let offset: Int?
    let limit: Int?
}
