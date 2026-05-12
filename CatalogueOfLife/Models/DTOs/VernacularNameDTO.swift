import Foundation

struct VernacularNameDTO: Decodable, Sendable {
    let id: Int
    let name: String
    let language: String?
}
