import Foundation

struct DatasetDTO: Decodable, Sendable {
    let key: Int
    let alias: String?
    let title: String
    let version: String?
    let issued: String?
    let origin: String?
    let type: String?
    let attempt: Int?
    let citation: String?
    let contact: ContactDTO?

    struct ContactDTO: Decodable, Sendable {
        let name: String?
        let email: String?
    }
}
