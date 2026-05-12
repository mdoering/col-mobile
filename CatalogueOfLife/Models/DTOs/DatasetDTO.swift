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
    let doi: String?
    let license: String?
    let publisher: PublisherDTO?

    struct ContactDTO: Decodable, Sendable {
        let name: String?
        let email: String?
    }

    struct PublisherDTO: Decodable, Sendable {
        let name: String?
        let organisation: String?
        let city: String?
        let country: String?
        let address: String?
    }
}
