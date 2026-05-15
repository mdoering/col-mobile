import Foundation

/// Process-wide cache for ChecklistBank controlled vocabularies. The vocab
/// payloads are tiny and change rarely, so we fetch each one at most once per
/// app launch and serve subsequent lookups from memory.
actor VocabStore {
    static let shared = VocabStore()

    private var nomRelTypeLabels: [String: String]?

    /// Returns the canonical human-readable label for a `nomRelType` wire
    /// value (e.g. `"basionym"` → `"Has basionym"`, `"spelling_correction"` →
    /// `"Spelling correction of"`). Returns `nil` if the vocab couldn't be
    /// loaded or the value isn't known — callers should fall back to the raw
    /// wire value.
    func nomRelTypeLabel(for wireValue: String, client: APIClient) async -> String? {
        await ensureNomRelTypeLoaded(client: client)
        return nomRelTypeLabels?[Self.normalize(wireValue)]
    }

    private func ensureNomRelTypeLoaded(client: APIClient) async {
        guard nomRelTypeLabels == nil else { return }
        do {
            let entries = try await client.getNomRelTypeVocab()
            // Map normalized wire form → vocab `label` (already properly
            // cased and phrased for display). Fall back to `name` for any
            // entry that doesn't ship a label.
            nomRelTypeLabels = Dictionary(
                entries.map { (Self.normalize($0.name), $0.label ?? $0.name) },
                uniquingKeysWith: { first, _ in first }
            )
        } catch {
            // Negative cache: avoid re-hitting the network on every relation.
            nomRelTypeLabels = [:]
        }
    }

    /// Lowercase, swap underscores for spaces, trim whitespace — handles the
    /// fact that wire values vary (`basionym`, `spelling_correction`, …) but
    /// the vocab `name` field is always lowercase-with-spaces.
    private static func normalize(_ s: String) -> String {
        s.replacingOccurrences(of: "_", with: " ")
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
