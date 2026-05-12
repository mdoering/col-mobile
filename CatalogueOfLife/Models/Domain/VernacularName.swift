import Foundation

struct VernacularName: Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    let language: String?    // ISO 639-3 code
    let country: String?
    let area: String?
}
