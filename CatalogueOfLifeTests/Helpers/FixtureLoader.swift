import Foundation

enum FixtureLoader {
    static func data(_ name: String) throws -> Data {
        let bundle = Bundle(for: BundleToken.self)
        guard let url = bundle.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")
                 ?? bundle.url(forResource: name, withExtension: "json")
        else { throw NSError(domain: "FixtureLoader", code: 1, userInfo: [NSLocalizedDescriptionKey: "Fixture \(name).json not found"]) }
        return try Data(contentsOf: url)
    }
    private final class BundleToken {}
}
