# Plan 4 — GBIF Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a GBIF data section to the taxon detail page (occurrence metrics, MapKit + GBIF tile overlay map, image carousel with full-screen viewer), gated by `AppState.gbifAvailable` so it only appears for the latest extended (3LXR) and base (3LR) releases.

**Architecture:** New `GBIFClient` actor (sibling of `APIClient`), parallel to the existing pattern. SwiftUI `UIViewRepresentable` wrapper around `MKMapView` + a `MKTileOverlay` subclass that builds GBIF tile URLs. Image carousel uses native `TabView(.page)`; full-screen viewer is a `.fullScreenCover`.

**Tech Stack:** Swift 6, SwiftUI, MapKit, Swift Testing, no third-party deps.

**Spec reference:** `docs/superpowers/specs/2026-05-12-col-mobile-design.md` — Plan 4 implements §5.2 (GBIF client), §5.3 (GBIF availability rule — already enforced via `AppState.gbifAvailable`), and §7 section 6 (the GBIF section on the taxon detail page).

**API findings (verified against live API on 2026-05-12 using Felis catus, COL id `3DXV3`):**
- `GET /v1/occurrence/search?checklistKey=<COL>&taxonKey=<COL-id>&limit=0` → `{count, results, facets, ...}`. Felis catus has 190,586 occurrences.
- Same endpoint with `facet=country&facet=datasetKey&facetLimit=300` → returns top counts (AU/US/NL on top for Felis catus). The number of distinct values is `facets[i].counts.count` (capped at facetLimit). We use this as the "distinct countries / distinct datasets" metric.
- Same endpoint with `mediaType=StillImage&limit=20` → returns 20 results, each containing a `media: [...]` array. Each media entry has: `type, format, identifier (image URL), references (source page URL), creator, publisher, license, rightsHolder, created`. Felis catus alone has ~69k records with images.
- `GET /v2/map/occurrence/density/{z}/{x}/{y}@1x.png?checklistKey=<COL>&taxonId=<COL-id>&style=classic.point` returns valid PNG map tiles (~73 KB at zoom 0). Used as a `MKTileOverlay`.

**Out of scope for Plan 4 (deferred):**
- "Open on catalogueoflife.org / checklistbank.org" toolbar action (mentioned in spec §7 but not yet implemented; can land alongside)
- Per-taxon 2-ring sunburst (Plan 3 documented this as deferred — no per-taxon `/breakdown` endpoint)

---

## File map

```
CatalogueOfLife/
├── Components/
│   ├── GBIFMapView.swift                              # new — MKMapView + MKTileOverlay wrapper
│   └── GBIFImageCarouselView.swift                    # new — TabView(.page) carousel + fullscreen viewer
├── Models/
│   ├── DTOs/
│   │   ├── OccurrenceSearchDTO.swift                  # new — wire shape for /v1/occurrence/search
│   │   └── OccurrenceMediaDTO.swift                   # new — wire shape for the `media[]` items inside results
│   └── Domain/
│       ├── GBIFMetrics.swift                          # new — count, distinctCountries, distinctDatasets, topCountries
│       └── GBIFMediaItem.swift                        # new — imageURL, sourceURL, creator, license, rightsHolder
├── Networking/
│   ├── GBIFEndpoints.swift                            # new — URL builders + COL_CHECKLIST_KEY constant
│   ├── GBIFClient.swift                               # new — protocol
│   └── GBIFClientLive.swift                           # new — URLSession actor
├── Features/
│   └── Taxon/
│       ├── GBIFSectionView.swift                      # new — metrics row + map + carousel
│       ├── GBIFSectionViewModel.swift                 # new
│       └── TaxonDetailView.swift                      # MODIFY: insert GBIFSectionView at the bottom when gbifAvailable
└── App/

CatalogueOfLifeTests/
├── Fixtures/
│   ├── gbif_occurrence_metrics.json                   # new — Felis catus, limit=0 with facets
│   └── gbif_occurrence_images.json                    # new — Felis catus, mediaType=StillImage
├── Helpers/
│   └── StubGBIFClient.swift                           # new — mirror of StubAPIClient
├── GBIFMetricsDecodingTests.swift                     # new
├── GBIFMediaDecodingTests.swift                       # new
└── GBIFSectionViewModelTests.swift                    # new
```

---

## Task 1: GBIFEndpoints + COL_CHECKLIST_KEY + GBIFClient protocol

**Files:**
- Create: `CatalogueOfLife/Networking/GBIFEndpoints.swift`
- Create: `CatalogueOfLife/Networking/GBIFClient.swift`

**Notes**
- `GBIFClient` is a sibling of `APIClient` — separate URL host, separate cache (a separate `URLSession` so the existing 50MB cache for CLB isn't displaced). For v1 we share `HTTPSession.shared` since URLCache works per-origin anyway; we don't need a second session.
- The COL checklist key is a constant: `"7ddf754f-d193-4cc9-b351-99906754a03b"`.

- [ ] **Step 1.1: `GBIFEndpoints.swift`**

```swift
import Foundation

enum GBIFEndpoints {
    static let baseURL = URL(string: "https://api.gbif.org")!

    /// GBIF's unique checklist UUID for the latest Catalogue of Life release.
    /// `checklistKey` on any GBIF endpoint routes the taxon lookups through CoL.
    static let colChecklistKey = "7ddf754f-d193-4cc9-b351-99906754a03b"

    /// Map tile style used by the density overlay. Other options exist (e.g. `classic-noborder.poly`).
    static let mapTileStyle = "classic.point"

    /// `GET /v1/occurrence/search` — used for metrics (limit=0 + facets) and image fetch (mediaType=StillImage).
    static func occurrenceSearch(
        taxonId: String,
        limit: Int,
        mediaType: String? = nil,
        facets: [String] = []
    ) -> URL {
        var c = URLComponents(
            url: baseURL.appending(path: "v1/occurrence/search"),
            resolvingAgainstBaseURL: false
        )!
        var items: [URLQueryItem] = [
            URLQueryItem(name: "checklistKey", value: colChecklistKey),
            URLQueryItem(name: "taxonKey", value: taxonId),
            URLQueryItem(name: "limit", value: String(limit)),
        ]
        if let mediaType {
            items.append(URLQueryItem(name: "mediaType", value: mediaType))
        }
        for f in facets {
            items.append(URLQueryItem(name: "facet", value: f))
        }
        if !facets.isEmpty {
            items.append(URLQueryItem(name: "facetLimit", value: "300"))
        }
        c.queryItems = items
        return c.url!
    }

    /// `GET /v2/map/occurrence/density/{z}/{x}/{y}@1x.png?...` — tile template for `MKTileOverlay`.
    /// `{z}/{x}/{y}` are placeholders `MKTileOverlay` substitutes at fetch time.
    static func mapTileURLTemplate(taxonId: String) -> String {
        "\(baseURL.absoluteString)/v2/map/occurrence/density/{z}/{x}/{y}@1x.png?checklistKey=\(colChecklistKey)&taxonId=\(taxonId)&style=\(mapTileStyle)"
    }
}
```

- [ ] **Step 1.2: `GBIFClient.swift`**

```swift
import Foundation

protocol GBIFClient: Sendable {
    /// Fetches occurrence count + facets (country, dataset). Result is `nil`
    /// if the request fails. (GBIF can drop slow requests; we treat that as no data.)
    func getOccurrenceMetrics(taxonId: String) async throws -> GBIFMetrics

    /// First N occurrences with media. Each occurrence may have multiple media items.
    func getOccurrenceImages(taxonId: String, limit: Int) async throws -> [GBIFMediaItem]
}
```

> The two domain types `GBIFMetrics` and `GBIFMediaItem` are introduced in Tasks 2 and 3 respectively. Until then `GBIFClient.swift` won't compile in isolation — exactly like the `APIClient` forward-ref pattern in Plan 1. Commit it together with Task 2 in one combined commit.

- [ ] **Step 1.3: Defer commit**

Do not commit yet — the protocol references types that don't exist. We commit together with Task 2.

---

## Task 2: Occurrence metrics — DTO + domain + GBIFClient impl + decoding test

**Files:**
- Create: `CatalogueOfLife/Models/DTOs/OccurrenceSearchDTO.swift`
- Create: `CatalogueOfLife/Models/Domain/GBIFMetrics.swift`
- Create: `CatalogueOfLife/Networking/GBIFClientLive.swift`
- Create: `CatalogueOfLifeTests/Fixtures/gbif_occurrence_metrics.json`
- Create: `CatalogueOfLifeTests/GBIFMetricsDecodingTests.swift`
- Create: `CatalogueOfLifeTests/Helpers/StubGBIFClient.swift`

- [ ] **Step 2.1: Capture fixture**

```bash
COL=7ddf754f-d193-4cc9-b351-99906754a03b
TID=$(curl -s 'https://api.checklistbank.org/dataset/3LXR/nameusage/search?q=Felis+catus&limit=1' | python3 -c "import json,sys; print(json.load(sys.stdin)['result'][0]['usage']['id'])")
curl -s "https://api.gbif.org/v1/occurrence/search?checklistKey=$COL&taxonKey=$TID&limit=0&facet=country&facet=datasetKey&facetLimit=300" \
  | python3 -m json.tool > CatalogueOfLifeTests/Fixtures/gbif_occurrence_metrics.json
python3 -c "
import json
d = json.load(open('CatalogueOfLifeTests/Fixtures/gbif_occurrence_metrics.json'))
print('count:', d['count'])
for f in d.get('facets', []):
    print('facet:', f['field'], 'distinct:', len(f['counts']), 'top1:', f['counts'][0] if f['counts'] else None)
"
```
Expected: `count` is a 6-digit number; two facets (`COUNTRY`, `DATASET_KEY`) each with > 1 entry.

- [ ] **Step 2.2: `OccurrenceSearchDTO.swift`**

```swift
import Foundation

/// Minimal wire shape for `GET /v1/occurrence/search`. We only decode the fields we use:
/// count + facets. (The `results` array is decoded for the image-fetch path via a separate DTO.)
struct OccurrenceSearchDTO: Decodable, Sendable {
    let count: Int
    let facets: [FacetDTO]?

    struct FacetDTO: Decodable, Sendable {
        let field: String
        let counts: [FacetCountDTO]
    }

    struct FacetCountDTO: Decodable, Sendable {
        let name: String
        let count: Int
    }
}
```

- [ ] **Step 2.3: `GBIFMetrics.swift`**

```swift
import Foundation

/// Summary of GBIF occurrence stats for one taxon. All counts are at the time of fetch.
struct GBIFMetrics: Equatable, Sendable {
    let occurrenceCount: Int
    /// Number of distinct countries that contributed occurrences (capped at facetLimit=300).
    let distinctCountries: Int
    /// Number of distinct GBIF datasets that contributed occurrences (capped at facetLimit=300).
    let distinctDatasets: Int
    /// Up to 3 top countries by occurrence count, formatted as (ISO 3166 alpha-2, count).
    let topCountries: [(code: String, count: Int)]

    static func == (lhs: GBIFMetrics, rhs: GBIFMetrics) -> Bool {
        lhs.occurrenceCount == rhs.occurrenceCount &&
        lhs.distinctCountries == rhs.distinctCountries &&
        lhs.distinctDatasets == rhs.distinctDatasets &&
        lhs.topCountries.count == rhs.topCountries.count &&
        zip(lhs.topCountries, rhs.topCountries).allSatisfy { $0.code == $1.code && $0.count == $1.count }
    }
}

extension GBIFMetrics {
    init(dto: OccurrenceSearchDTO) {
        let facets = dto.facets ?? []
        let countryFacet = facets.first { $0.field.uppercased() == "COUNTRY" }
        let datasetFacet = facets.first { $0.field.uppercased() == "DATASET_KEY" }
        self.init(
            occurrenceCount: dto.count,
            distinctCountries: countryFacet?.counts.count ?? 0,
            distinctDatasets: datasetFacet?.counts.count ?? 0,
            topCountries: (countryFacet?.counts.prefix(3) ?? [].prefix(3)).map { (code: $0.name, count: $0.count) }
        )
    }
}
```

- [ ] **Step 2.4: `GBIFClientLive.swift`**

```swift
import Foundation

actor GBIFClientLive: GBIFClient {
    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = HTTPSession.shared) {
        self.session = session
        self.decoder = JSONDecoder()
    }

    private func getJSON<T: Decodable>(_ url: URL, as type: T.Type) async throws -> T {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(from: url)
        } catch let urlError as URLError {
            throw APIError.network(urlError)
        }
        guard let http = response as? HTTPURLResponse else {
            throw APIError.server(status: -1)
        }
        switch http.statusCode {
        case 200..<300:
            do { return try decoder.decode(T.self, from: data) }
            catch { throw APIError.decoding(String(describing: error)) }
        case 404: throw APIError.notFound
        default: throw APIError.server(status: http.statusCode)
        }
    }

    func getOccurrenceMetrics(taxonId: String) async throws -> GBIFMetrics {
        let url = GBIFEndpoints.occurrenceSearch(
            taxonId: taxonId,
            limit: 0,
            facets: ["country", "datasetKey"]
        )
        let dto = try await getJSON(url, as: OccurrenceSearchDTO.self)
        return GBIFMetrics(dto: dto)
    }

    // Real implementation lands in Task 3:
    func getOccurrenceImages(taxonId: String, limit: Int) async throws -> [GBIFMediaItem] {
        fatalError("Task 3")
    }
}
```

- [ ] **Step 2.5: `StubGBIFClient.swift`**

```swift
import Foundation
@testable import CatalogueOfLife

final class StubGBIFClient: GBIFClient, @unchecked Sendable {
    var metrics: [String: GBIFMetrics] = [:]
    var images: [String: [GBIFMediaItem]] = [:]
    var error: APIError?

    func getOccurrenceMetrics(taxonId: String) async throws -> GBIFMetrics {
        if let error { throw error }
        guard let m = metrics[taxonId] else { throw APIError.notFound }
        return m
    }

    func getOccurrenceImages(taxonId: String, limit: Int) async throws -> [GBIFMediaItem] {
        if let error { throw error }
        return images[taxonId] ?? []
    }
}
```

- [ ] **Step 2.6: `GBIFMetricsDecodingTests.swift`**

```swift
import Testing
import Foundation
@testable import CatalogueOfLife

@Suite("GBIF metrics decoding")
struct GBIFMetricsDecodingTests {
    @Test("Decodes Felis catus occurrence metrics fixture")
    func decodes() throws {
        let data = try FixtureLoader.data("gbif_occurrence_metrics")
        let dto = try JSONDecoder().decode(OccurrenceSearchDTO.self, from: data)
        let metrics = GBIFMetrics(dto: dto)
        #expect(metrics.occurrenceCount > 0)
        #expect(metrics.distinctCountries > 0)
        #expect(metrics.distinctDatasets > 0)
        #expect(!metrics.topCountries.isEmpty)
        #expect(metrics.topCountries.count <= 3)
    }
}
```

- [ ] **Step 2.7: Run tests + commit (combined Task 1 + Task 2)**

```bash
xcodegen generate
xcodebuild -scheme CatalogueOfLife -destination 'platform=iOS Simulator,name=iPhone 16e,OS=latest' test -quiet
```
Expected: 55/55 (54 + 1 new).

```bash
git add CatalogueOfLife CatalogueOfLifeTests
git commit -m "Add GBIFClient protocol + occurrence metrics endpoint with decoding test"
```

---

## Task 3: Image carousel — DTO + domain + GBIFClient impl + decoding test

**Files:**
- Create: `CatalogueOfLife/Models/DTOs/OccurrenceMediaDTO.swift`
- Create: `CatalogueOfLife/Models/Domain/GBIFMediaItem.swift`
- Modify: `CatalogueOfLife/Networking/GBIFClientLive.swift` — implement `getOccurrenceImages`
- Create: `CatalogueOfLifeTests/Fixtures/gbif_occurrence_images.json`
- Create: `CatalogueOfLifeTests/GBIFMediaDecodingTests.swift`

The occurrence-with-images response embeds media inside each result. We flatten the (results × media) cross-product into a flat `[GBIFMediaItem]`.

- [ ] **Step 3.1: Capture fixture**

```bash
COL=7ddf754f-d193-4cc9-b351-99906754a03b
TID=$(curl -s 'https://api.checklistbank.org/dataset/3LXR/nameusage/search?q=Felis+catus&limit=1' | python3 -c "import json,sys; print(json.load(sys.stdin)['result'][0]['usage']['id'])")
curl -s "https://api.gbif.org/v1/occurrence/search?checklistKey=$COL&taxonKey=$TID&mediaType=StillImage&limit=10" \
  | python3 -m json.tool > CatalogueOfLifeTests/Fixtures/gbif_occurrence_images.json
python3 -c "
import json
d = json.load(open('CatalogueOfLifeTests/Fixtures/gbif_occurrence_images.json'))
print('returned occurrences:', len(d['results']))
total_media = sum(len(r.get('media', [])) for r in d['results'])
print('total media items:', total_media)
sample = next((m for r in d['results'] for m in r.get('media', []) if m.get('identifier')), None)
if sample: print('sample media keys:', sorted(sample.keys()))
"
```
Expected: > 5 results, > 5 total media items, fields include `identifier, references, creator, license, rightsHolder, publisher`.

- [ ] **Step 3.2: `OccurrenceMediaDTO.swift`**

```swift
import Foundation

/// Decode the `results[].media[]` portion of `/v1/occurrence/search`. The metrics path
/// uses a separate DTO that only reads `count + facets`. This path is "image-flavored".
struct OccurrenceWithMediaDTO: Decodable, Sendable {
    let results: [OccurrenceResultDTO]

    struct OccurrenceResultDTO: Decodable, Sendable {
        let gbifID: Int?
        let media: [MediaItemDTO]?
    }

    struct MediaItemDTO: Decodable, Sendable {
        let type: String?
        let format: String?
        let identifier: String?    // image URL
        let references: String?    // source page URL
        let creator: String?
        let publisher: String?
        let license: String?
        let rightsHolder: String?
    }
}
```

- [ ] **Step 3.3: `GBIFMediaItem.swift`**

```swift
import Foundation

struct GBIFMediaItem: Equatable, Hashable, Identifiable, Sendable {
    /// Stable id synthesized from the image URL (so SwiftUI ForEach works without duplicates).
    let id: String
    let imageURL: URL
    let sourceURL: URL?
    let creator: String?
    let publisher: String?
    let license: String?
    let rightsHolder: String?
}

extension GBIFMediaItem {
    /// Flatten an `OccurrenceWithMediaDTO` into a list of items, keeping only entries
    /// whose `type` is `"StillImage"` and which have a parseable image URL.
    static func from(dto: OccurrenceWithMediaDTO) -> [GBIFMediaItem] {
        var seen = Set<String>()
        var out: [GBIFMediaItem] = []
        for result in dto.results {
            for media in result.media ?? [] {
                guard (media.type ?? "").localizedCaseInsensitiveCompare("StillImage") == .orderedSame else { continue }
                guard let raw = media.identifier, let url = URL(string: raw) else { continue }
                let key = raw
                if seen.contains(key) { continue }
                seen.insert(key)
                out.append(GBIFMediaItem(
                    id: key,
                    imageURL: url,
                    sourceURL: media.references.flatMap(URL.init(string:)),
                    creator: media.creator,
                    publisher: media.publisher,
                    license: media.license,
                    rightsHolder: media.rightsHolder
                ))
            }
        }
        return out
    }
}
```

- [ ] **Step 3.4: Implement `getOccurrenceImages` in `GBIFClientLive`**

Replace the `fatalError` stub:

```swift
func getOccurrenceImages(taxonId: String, limit: Int) async throws -> [GBIFMediaItem] {
    let url = GBIFEndpoints.occurrenceSearch(
        taxonId: taxonId,
        limit: limit,
        mediaType: "StillImage"
    )
    let dto = try await getJSON(url, as: OccurrenceWithMediaDTO.self)
    return GBIFMediaItem.from(dto: dto)
}
```

- [ ] **Step 3.5: `GBIFMediaDecodingTests.swift`**

```swift
import Testing
import Foundation
@testable import CatalogueOfLife

@Suite("GBIF media decoding")
struct GBIFMediaDecodingTests {
    @Test("Decodes images fixture into GBIFMediaItem list")
    func decodes() throws {
        let data = try FixtureLoader.data("gbif_occurrence_images")
        let dto = try JSONDecoder().decode(OccurrenceWithMediaDTO.self, from: data)
        let items = GBIFMediaItem.from(dto: dto)
        #expect(!items.isEmpty)
        #expect(items.allSatisfy { $0.imageURL.scheme?.hasPrefix("http") == true })
    }

    @Test("Deduplicates by image URL")
    func dedupes() {
        let dto = OccurrenceWithMediaDTO(results: [
            .init(gbifID: 1, media: [
                .init(type: "StillImage", format: nil, identifier: "https://example.org/a.jpg",
                      references: nil, creator: nil, publisher: nil, license: nil, rightsHolder: nil)
            ]),
            .init(gbifID: 2, media: [
                .init(type: "StillImage", format: nil, identifier: "https://example.org/a.jpg",
                      references: nil, creator: nil, publisher: nil, license: nil, rightsHolder: nil),
                .init(type: "StillImage", format: nil, identifier: "https://example.org/b.jpg",
                      references: nil, creator: nil, publisher: nil, license: nil, rightsHolder: nil)
            ])
        ])
        let items = GBIFMediaItem.from(dto: dto)
        #expect(items.count == 2)
        #expect(items.map(\.id).sorted() == ["https://example.org/a.jpg", "https://example.org/b.jpg"])
    }

    @Test("Skips non-StillImage and items without identifier")
    func skipsNonImages() {
        let dto = OccurrenceWithMediaDTO(results: [
            .init(gbifID: 1, media: [
                .init(type: "Sound", format: nil, identifier: "https://example.org/audio.mp3",
                      references: nil, creator: nil, publisher: nil, license: nil, rightsHolder: nil),
                .init(type: "StillImage", format: nil, identifier: nil,
                      references: nil, creator: nil, publisher: nil, license: nil, rightsHolder: nil),
                .init(type: "StillImage", format: nil, identifier: "https://example.org/ok.jpg",
                      references: nil, creator: nil, publisher: nil, license: nil, rightsHolder: nil)
            ])
        ])
        let items = GBIFMediaItem.from(dto: dto)
        #expect(items.count == 1)
        #expect(items.first?.imageURL.absoluteString == "https://example.org/ok.jpg")
    }
}
```

- [ ] **Step 3.6: Run tests + commit**

```bash
xcodegen generate
xcodebuild -scheme CatalogueOfLife -destination 'platform=iOS Simulator,name=iPhone 16e,OS=latest' test -quiet
```
Expected: 58/58 (55 + 3 new).

```bash
git add CatalogueOfLife CatalogueOfLifeTests
git commit -m "Add GBIF occurrence images endpoint with StillImage flattening and dedup tests"
```

---

## Task 4: Map tile overlay — GBIFMapView + MKTileOverlay subclass

**Files:**
- Create: `CatalogueOfLife/Components/GBIFMapView.swift`

A SwiftUI `UIViewRepresentable` wrapping `MKMapView`. Sets the COL+taxon-id tile overlay. No tests — this is pure platform glue and would require UI testing.

- [ ] **Step 4.1: `GBIFMapView.swift`**

```swift
import SwiftUI
import MapKit

/// SwiftUI wrapper for an MKMapView that displays GBIF density tiles
/// for one COL taxon (gated upstream by `AppState.gbifAvailable`).
struct GBIFMapView: UIViewRepresentable {
    let taxonId: String

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.isZoomEnabled = true
        map.isScrollEnabled = true
        map.isRotateEnabled = false
        map.isPitchEnabled = false
        map.showsCompass = false
        map.pointOfInterestFilter = .excludingAll
        let overlay = GBIFTileOverlay(taxonId: taxonId)
        map.addOverlay(overlay, level: .aboveLabels)
        return map
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        // Replace overlay if taxonId changed (e.g. on push to a new taxon).
        let existing = uiView.overlays.compactMap { $0 as? GBIFTileOverlay }
        if existing.first?.taxonId != taxonId {
            uiView.removeOverlays(uiView.overlays)
            uiView.addOverlay(GBIFTileOverlay(taxonId: taxonId), level: .aboveLabels)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let tile = overlay as? MKTileOverlay else { return MKOverlayRenderer(overlay: overlay) }
            return MKTileOverlayRenderer(tileOverlay: tile)
        }
    }
}

/// MKTileOverlay subclass that requests GBIF density tiles for the COL checklist + given taxon.
final class GBIFTileOverlay: MKTileOverlay, @unchecked Sendable {
    let taxonId: String

    init(taxonId: String) {
        self.taxonId = taxonId
        super.init(urlTemplate: GBIFEndpoints.mapTileURLTemplate(taxonId: taxonId))
        self.canReplaceMapContent = false
        self.minimumZ = 0
        self.maximumZ = 12
    }
}
```

- [ ] **Step 4.2: Build to confirm no errors**

```bash
xcodegen generate
xcodebuild -scheme CatalogueOfLife -destination 'platform=iOS Simulator,name=iPhone 16e,OS=latest' build -quiet
```
Expected: clean build.

- [ ] **Step 4.3: Commit**

```bash
git add CatalogueOfLife/Components/GBIFMapView.swift
git commit -m "Add GBIFMapView (MKMapView + MKTileOverlay) for COL-taxon density tiles"
```

---

## Task 5: Image carousel component + full-screen viewer

**Files:**
- Create: `CatalogueOfLife/Components/GBIFImageCarouselView.swift`

The carousel is a `TabView(.page)` over a list of `GBIFMediaItem`. Tap → present a `.fullScreenCover` with the larger image + attribution + license.

- [ ] **Step 5.1: `GBIFImageCarouselView.swift`**

```swift
import SwiftUI

struct GBIFImageCarouselView: View {
    let items: [GBIFMediaItem]
    @State private var selectedFullScreen: GBIFMediaItem?

    var body: some View {
        if items.isEmpty {
            EmptyView()
        } else {
            TabView {
                ForEach(items) { item in
                    Button {
                        selectedFullScreen = item
                    } label: {
                        AsyncImage(url: item.imageURL) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill().clipped()
                            case .failure:
                                placeholder
                            case .empty:
                                ProgressView()
                            @unknown default:
                                placeholder
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .frame(height: 240)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
            .fullScreenCover(item: $selectedFullScreen) { item in
                FullScreenImageView(item: item) {
                    selectedFullScreen = nil
                }
            }
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(.secondary.opacity(0.15))
            .overlay(Image(systemName: "photo").foregroundStyle(.secondary).font(.title))
    }
}

private struct FullScreenImageView: View {
    let item: GBIFMediaItem
    let onDismiss: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                AsyncImage(url: item.imageURL) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFit()
                    case .failure: Image(systemName: "photo").foregroundStyle(.white)
                    case .empty: ProgressView().tint(.white)
                    @unknown default: Color.clear
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                attribution
                    .padding()
                    .background(.black.opacity(0.6))
            }
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(.white)
                    .padding()
            }
            .accessibilityLabel("Close")
        }
    }

    private var attribution: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let creator = item.creator {
                Text("© \(creator)").font(.caption).foregroundStyle(.white)
            }
            if let rights = item.rightsHolder, rights != item.creator {
                Text(rights).font(.caption2).foregroundStyle(.white.opacity(0.85))
            }
            if let publisher = item.publisher {
                Text(publisher).font(.caption2).foregroundStyle(.white.opacity(0.75))
            }
            HStack(spacing: 8) {
                if let license = item.license, let url = URL(string: license) {
                    Link(licenseLabel(license), destination: url).font(.caption2)
                } else if let license = item.license {
                    Text(license).font(.caption2).foregroundStyle(.white.opacity(0.85))
                }
                if let source = item.sourceURL {
                    Link("Source", destination: source).font(.caption2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Heuristic short label: "CC BY-NC 4.0" from a CC URL, otherwise the URL.
    private func licenseLabel(_ url: String) -> String {
        let lower = url.lowercased()
        if lower.contains("/by-nc-sa") { return "CC BY-NC-SA" }
        if lower.contains("/by-nc-nd") { return "CC BY-NC-ND" }
        if lower.contains("/by-nc")    { return "CC BY-NC" }
        if lower.contains("/by-sa")    { return "CC BY-SA" }
        if lower.contains("/by")       { return "CC BY" }
        if lower.contains("publicdomain") { return "Public Domain" }
        return "License"
    }
}
```

- [ ] **Step 5.2: Build**

```bash
xcodegen generate
xcodebuild -scheme CatalogueOfLife -destination 'platform=iOS Simulator,name=iPhone 16e,OS=latest' build -quiet
```
Expected: clean build.

- [ ] **Step 5.3: Commit**

```bash
git add CatalogueOfLife/Components/GBIFImageCarouselView.swift
git commit -m "Add GBIFImageCarouselView with paging + full-screen viewer with attribution"
```

---

## Task 6: GBIFSectionViewModel + GBIFSectionView

**Files:**
- Create: `CatalogueOfLife/Features/Taxon/GBIFSectionViewModel.swift`
- Create: `CatalogueOfLife/Features/Taxon/GBIFSectionView.swift`
- Create: `CatalogueOfLifeTests/GBIFSectionViewModelTests.swift`

The view-model fetches metrics + images in parallel (best-effort; either may fail). The view renders three independent sub-blocks; each can be empty / loaded independently.

- [ ] **Step 6.1: `GBIFSectionViewModel.swift`**

```swift
import Foundation
import Observation

@MainActor
@Observable
final class GBIFSectionViewModel {
    private(set) var metrics: GBIFMetrics?
    private(set) var images: [GBIFMediaItem] = []
    private(set) var didLoad = false
    private(set) var failed = false

    private let client: GBIFClient

    init(client: GBIFClient) {
        self.client = client
    }

    func load(taxonId: String) async {
        didLoad = false
        failed = false
        async let metricsResult = try? await client.getOccurrenceMetrics(taxonId: taxonId)
        async let imagesResult = try? await client.getOccurrenceImages(taxonId: taxonId, limit: 20)
        let m = await metricsResult
        let i = await imagesResult ?? []
        self.metrics = m
        self.images = i
        self.didLoad = true
        self.failed = (m == nil && i.isEmpty)
    }
}
```

- [ ] **Step 6.2: `GBIFSectionView.swift`**

```swift
import SwiftUI

struct GBIFSectionView: View {
    let taxonId: String
    @State private var vm: GBIFSectionViewModel?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Occurrences (GBIF)").font(.headline)
            if let vm, vm.didLoad {
                if vm.failed {
                    Text("Couldn't load GBIF data for this taxon.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    if let m = vm.metrics { metricsRow(m) }
                    GBIFMapView(taxonId: taxonId)
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    GBIFImageCarouselView(items: vm.images)
                }
            } else {
                ProgressView()
            }
        }
        .task(id: taxonId) {
            if vm == nil {
                vm = GBIFSectionViewModel(client: GBIFClientLive())
            }
            await vm?.load(taxonId: taxonId)
        }
    }

    @ViewBuilder
    private func metricsRow(_ m: GBIFMetrics) -> some View {
        HStack(spacing: 16) {
            metric("Occurrences", m.occurrenceCount)
            metric("Countries", m.distinctCountries)
            metric("Datasets", m.distinctDatasets)
        }
        if !m.topCountries.isEmpty {
            Text("Top countries: " + m.topCountries
                .map { "\($0.code) (\($0.count.formatted(.number)))" }
                .joined(separator: " · "))
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func metric(_ label: String, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value, format: .number)
                .font(.title3.monospacedDigit().bold())
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
```

- [ ] **Step 6.3: `GBIFSectionViewModelTests.swift`**

```swift
import Testing
import Foundation
@testable import CatalogueOfLife

@Suite("GBIFSectionViewModel")
@MainActor
struct GBIFSectionViewModelTests {

    @Test("Loads metrics + images successfully")
    func loadsBoth() async {
        let stub = StubGBIFClient()
        stub.metrics["T1"] = GBIFMetrics(occurrenceCount: 100, distinctCountries: 5, distinctDatasets: 3, topCountries: [("AU", 50)])
        stub.images["T1"] = [
            GBIFMediaItem(id: "u1", imageURL: URL(string: "https://example.org/1.jpg")!,
                          sourceURL: nil, creator: "A", publisher: nil, license: nil, rightsHolder: nil)
        ]
        let vm = GBIFSectionViewModel(client: stub)
        await vm.load(taxonId: "T1")
        #expect(vm.didLoad)
        #expect(vm.failed == false)
        #expect(vm.metrics?.occurrenceCount == 100)
        #expect(vm.images.count == 1)
    }

    @Test("Reports failed when both fetches fail")
    func failsBoth() async {
        let stub = StubGBIFClient()
        stub.error = .server(status: 503)
        let vm = GBIFSectionViewModel(client: stub)
        await vm.load(taxonId: "T1")
        #expect(vm.didLoad)
        #expect(vm.failed)
        #expect(vm.metrics == nil)
        #expect(vm.images.isEmpty)
    }

    @Test("Partial success: images load even if metrics fail (and vice versa)")
    func partialSuccess() async {
        let stub = StubGBIFClient()
        // Configure: no metrics entry → throws .notFound; images present.
        stub.images["T1"] = [
            GBIFMediaItem(id: "u1", imageURL: URL(string: "https://example.org/1.jpg")!,
                          sourceURL: nil, creator: nil, publisher: nil, license: nil, rightsHolder: nil)
        ]
        let vm = GBIFSectionViewModel(client: stub)
        await vm.load(taxonId: "T1")
        #expect(vm.didLoad)
        #expect(vm.failed == false)        // images present → not a total failure
        #expect(vm.metrics == nil)
        #expect(vm.images.count == 1)
    }
}
```

- [ ] **Step 6.4: Run tests + commit**

```bash
xcodegen generate
xcodebuild -scheme CatalogueOfLife -destination 'platform=iOS Simulator,name=iPhone 16e,OS=latest' test -quiet
```
Expected: 61/61 (58 + 3 new).

```bash
git add CatalogueOfLife CatalogueOfLifeTests
git commit -m "Add GBIFSectionView + view-model with metrics+images parallel fetch"
```

---

## Task 7: Wire GBIFSectionView into TaxonDetailView (gated by gbifAvailable)

**Files:**
- Modify: `CatalogueOfLife/Features/Taxon/TaxonDetailView.swift`

Insert the `GBIFSectionView` at the bottom of the `.loaded(let info)` arm, AFTER `VernacularNamesView`, and only when `appState.gbifAvailable` is true. The COL taxon id passed in is the same `info.taxonId`.

- [ ] **Step 7.1: Modify `TaxonDetailView.swift`**

Read the file. Find the `VernacularNamesView(names: info.vernacularNames, preferredLanguage: appState.effectiveVernacularLanguage)` call inside the `.loaded(let info)` arm. Append after it:

```swift
if appState.gbifAvailable {
    GBIFSectionView(taxonId: info.taxonId)
}
```

No other changes to the file.

- [ ] **Step 7.2: Build + run tests**

```bash
xcodegen generate
xcodebuild -scheme CatalogueOfLife -destination 'platform=iOS Simulator,name=iPhone 16e,OS=latest' build -quiet
xcodebuild -scheme CatalogueOfLife -destination 'platform=iOS Simulator,name=iPhone 16e,OS=latest' test -quiet
```
Expected: 61/61.

Manual smoke:
```bash
xcodebuild -scheme CatalogueOfLife -destination 'platform=iOS Simulator,name=iPhone 16e,OS=latest' -configuration Debug -derivedDataPath /tmp/col-mobile-dd build -quiet
APP_PATH=$(find /tmp/col-mobile-dd/Build/Products -name CatalogueOfLife.app -type d | head -1)
SIM_ID=$(xcrun simctl list devices booted -j | python3 -c "import json,sys; d=json.load(sys.stdin); [print(dev['udid']) for runtime in d['devices'] for dev in d['devices'][runtime] if dev.get('state')=='Booted'][0]")
xcrun simctl install "$SIM_ID" "$APP_PATH"
xcrun simctl launch "$SIM_ID" org.catalogueoflife.mobile
sleep 5
xcrun simctl io "$SIM_ID" screenshot /tmp/col-mobile-plan4-task7.png
```

- [ ] **Step 7.3: Commit**

```bash
git add CatalogueOfLife/Features/Taxon/TaxonDetailView.swift
git commit -m "Wire GBIFSectionView into TaxonDetailView, gated by gbifAvailable"
```

---

## Task 8: Plan 4 final checkpoint

- [ ] **Step 8.1: Full test suite**

```bash
xcodegen generate
xcodebuild -scheme CatalogueOfLife -destination 'platform=iOS Simulator,name=iPhone 16e,OS=latest' test -quiet
```
Expected: 61 tests pass.

- [ ] **Step 8.2: Push + watch CI**

```bash
git push
NEW_SHA=$(git rev-parse HEAD)
ATTEMPTS=0
while [ $ATTEMPTS -lt 24 ]; do
  ATTEMPTS=$((ATTEMPTS+1))
  STATUS=$(curl -s "https://api.github.com/repos/mdoering/col-mobile/actions/runs?per_page=10" \
    | python3 -c "
import json, sys
d = json.load(sys.stdin)
for r in d['workflow_runs']:
    if r['name'] != 'CI': continue
    if r['head_sha'].startswith('$NEW_SHA'[:7]) or '$NEW_SHA'.startswith(r['head_sha'][:7]):
        print(r['status'], r['conclusion'] or '-', r['html_url']); break
")
  echo "[$ATTEMPTS/24] $STATUS"
  case "$STATUS" in
    *completed*success*) echo "CI green"; break ;;
    *completed*failure*) echo "CI failed"; break ;;
  esac
  sleep 30
done
```

Total wait budget: 12 minutes.

- [ ] **Step 8.3: End-to-end manual smoke**

In the simulator:
1. Launch app — Tree tab default; release picker shows COL26.4 XR (which resolves to a gbifAvailable release)
2. Switch to Search tab; search "Felis catus"; tap result
3. Taxon detail page should now show, in order: header → classification chips → sunburst (Plan 3) → synonymy → vernacular names → **GBIF section** (occurrence count + map + image carousel)
4. Tap a carousel image → full-screen viewer with attribution
5. Switch release picker to an annual (e.g. COL24) — gbifAvailable becomes false; taxon detail GBIF section disappears
6. Switch back to COL26.4 XR — GBIF section reappears

---

## Self-review of this plan against the spec

- **§5.2 GBIFClient** — protocol + live actor + StubGBIFClient (Tasks 1-3). ✓
- **§5.2 multi-taxonomy API** — `GBIFEndpoints.colChecklistKey` constant + `checklistKey=…&taxonKey=<COL-id>` everywhere. ✓
- **§5.2 occurrence metrics** — `getOccurrenceMetrics` with country + datasetKey facets (Task 2). ✓
- **§5.2 images** — `getOccurrenceImages` with `mediaType=StillImage` (Task 3). ✓
- **§5.2 map tiles** — `MKTileOverlay` against `/v2/map/occurrence/density/…?checklistKey&taxonId` (Task 4). ✓
- **§5.3 GBIF availability rule** — already enforced via `AppState.gbifAvailable`; new GBIF section gated on it in Task 7. ✓
- **§7 section 6 (GBIF section on taxon detail)** — metrics row + map card + image carousel (Tasks 5-7); full-screen viewer with attribution + license (Task 5). ✓
- **§12 error handling** — each sub-fetch is independent (`try?`); section reports `.failed` only when both fail; partial-success path tested.
- **§13 testing** — fixtures + decoding tests for both endpoints, VM tests for the section, math tests covered earlier.

No placeholders. Every step has the exact code or command. The only Swift 6 strict-concurrency note: `GBIFTileOverlay` is marked `@unchecked Sendable` because `MKTileOverlay` (UIKit) is not natively `Sendable`; it's safe because its only mutable state (`urlTemplate`) is set once in init.
