# Plan 3 — Sunburst + Sources + Metrics + About Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the three remaining content tabs (Sources, Metrics, About) and add a taxonomic-breakdown sunburst to both the dataset-level Metrics tab and the per-taxon detail page.

**Architecture:** Same as Plan 1/2 — SwiftUI + `@Observable` view-models + `APIClient` actor + env-injected `AppState`. Sunburst rendered natively via `SwiftUI.Canvas` (no third-party deps).

**Tech Stack:** Swift 6, SwiftUI (Canvas for sunburst), Swift Testing, XcodeGen, GitHub Actions.

**Spec reference:** `docs/superpowers/specs/2026-05-12-col-mobile-design.md` — Plan 3 implements §6 tabs 3/4/5, §7 sunburst section, §8 (Sunburst), and §10's About-tab vernacular language picker UI.

**API findings (verified against live API on 2026-05-12):**
- `GET /dataset/{key}/source` — flat array of sources with fields: `key, title, alias, citation, logo, license, version, issued, taxonomicScope, geographicScope, type, origin, contact, creator, ...`
- `GET /dataset/{key}/source/{sourceKey}` — same shape plus `description, contributor, imported, versionDoi`
- `GET /dataset/{key}/breakdown` — `{datasetKey, breakdown: [{group, count, breakdown: [{group, count, breakdown: ...}]}]}`. For 3LXR there are 3 top-level groups (viruses, prokaryotes, eukaryotes) with nested subgroups. Naturally 2 levels deep for the dataset-level sunburst.
- `GET /dataset/{key}/taxon/{id}/breakdown` returns **404** — per-taxon breakdown does NOT exist. The taxon-detail sunburst instead uses `getTreeChildren(datasetKey:, parentId: taxonId)` and weights arcs by `TreeNode.count` (descendant count).
- `GET /dataset/{key}/import` — flat array (typically 1 entry) with ~40 metric fields (`nameCount, taxonCount, synonymCount, vernacularCount, distributionCount, taxaByRankCount, namesByRankCount, ...`). The latest attempt is index 0.

**Out of scope for Plan 3 (deferred):**
- GBIF integration (metrics, map tiles, image carousel) — Plan 4
- Per-taxon 2-ring sunburst (no API support); single-ring sunburst lands here

---

## File map

```
CatalogueOfLife/
├── Components/
│   └── SunburstView.swift                            # new — Canvas-based sunburst
├── Models/
│   ├── DTOs/
│   │   ├── SourceDTO.swift                           # new (covers list + detail)
│   │   ├── BreakdownDTO.swift                        # new (recursive)
│   │   └── ImportMetricsDTO.swift                    # new
│   └── Domain/
│       ├── Source.swift                              # new
│       ├── BreakdownNode.swift                       # new (recursive)
│       ├── ImportMetrics.swift                       # new
│       └── SunburstNode.swift                        # new (renderer input, shared by Metrics + taxon detail)
├── Networking/
│   ├── APIClient.swift                               # MODIFY: add 4 new methods
│   ├── APIClientLive.swift                           # MODIFY: implement 4 new methods
│   └── Endpoints.swift                               # MODIFY: 4 new builders
├── Features/
│   ├── Sources/
│   │   ├── SourcesView.swift                         # new
│   │   ├── SourcesViewModel.swift                    # new
│   │   ├── SourceRowView.swift                       # new
│   │   └── SourceDetailView.swift                    # new (+ embedded VM)
│   ├── Metrics/
│   │   ├── MetricsView.swift                         # new
│   │   ├── MetricsViewModel.swift                    # new
│   │   └── ImportMetricsList.swift                   # new
│   ├── About/
│   │   ├── AboutView.swift                           # new
│   │   └── PreferredLanguagePicker.swift             # new
│   └── Taxon/
│       └── TaxonDetailView.swift                     # MODIFY: insert single-ring sunburst between SynonymyView and VernacularNamesView
└── App/
    └── RootTabView.swift                             # MODIFY: replace 3 placeholders (Sources/Metrics/About)

CatalogueOfLifeTests/
├── Fixtures/
│   ├── sources_list.json                             # new
│   ├── source_detail.json                            # new
│   ├── dataset_breakdown.json                        # new
│   └── import_metrics.json                           # new
├── SourceDecodingTests.swift                         # new
├── BreakdownDecodingTests.swift                      # new
├── ImportMetricsDecodingTests.swift                  # new
├── SunburstMathTests.swift                           # new
└── SourcesViewModelTests.swift                       # new
```

---

## Task 1: Sources endpoint (list + detail) + DTO + domain + tests

**Files:**
- Create: `CatalogueOfLife/Models/DTOs/SourceDTO.swift`
- Create: `CatalogueOfLife/Models/Domain/Source.swift`
- Create: `CatalogueOfLifeTests/Fixtures/sources_list.json`
- Create: `CatalogueOfLifeTests/Fixtures/source_detail.json`
- Create: `CatalogueOfLifeTests/SourceDecodingTests.swift`
- Modify: `CatalogueOfLife/Networking/Endpoints.swift`
- Modify: `CatalogueOfLife/Networking/APIClient.swift`
- Modify: `CatalogueOfLife/Networking/APIClientLive.swift`
- Modify: `CatalogueOfLifeTests/Helpers/StubAPIClient.swift`

- [ ] **Step 1.1: Capture fixtures**

```bash
curl -s 'https://api.checklistbank.org/dataset/3LXR/source?limit=5' | python3 -m json.tool > CatalogueOfLifeTests/Fixtures/sources_list.json
python3 -c "
import json
d = json.load(open('CatalogueOfLifeTests/Fixtures/sources_list.json'))
print('shape:', 'array' if isinstance(d, list) else 'dict', 'len:', len(d) if isinstance(d, list) else len(d.get('result', [])))
sample = d[0] if isinstance(d, list) else d['result'][0]
print('first source keys:', sorted(sample.keys()))
print('first key:', sample.get('key'))
"
```

Note the first source's `key` field (will be used for the detail fixture).

```bash
SOURCE_KEY=$(curl -s 'https://api.checklistbank.org/dataset/3LXR/source?limit=1' | python3 -c "import json,sys; d=json.load(sys.stdin); r=d if isinstance(d, list) else d['result']; print(r[0]['key'])")
curl -s "https://api.checklistbank.org/dataset/3LXR/source/$SOURCE_KEY" | python3 -m json.tool > CatalogueOfLifeTests/Fixtures/source_detail.json
python3 -c "
import json
d = json.load(open('CatalogueOfLifeTests/Fixtures/source_detail.json'))
print('detail keys:', sorted(d.keys()))
"
```

Both responses should have shared fields: `key, title, alias?, citation?, logo?, license?, version?, issued?, type?, origin?, taxonomicScope?, geographicScope?`. Source detail has extra: `description?, contributor?, imported?, versionDoi?`. **The list endpoint returns a flat array (not a paged dict)** — verify from `sources_list.json`'s shape.

If the list endpoint returns a paged dict instead, adjust Step 1.5 accordingly.

- [ ] **Step 1.2: Write `SourceDTO.swift`**

```swift
import Foundation

/// Wire shape for both `GET /dataset/{key}/source[?...]` and `GET /dataset/{key}/source/{sourceKey}`.
/// The list endpoint returns a subset; the detail endpoint returns a superset. We decode both
/// through the same struct with optionals for the detail-only fields.
struct SourceDTO: Decodable, Sendable {
    let key: Int
    let title: String
    let alias: String?
    let citation: String?
    let logo: String?
    let license: String?
    let version: String?
    let issued: String?
    let type: String?
    let origin: String?
    let taxonomicScope: String?
    let geographicScope: String?
    let creator: [PersonDTO]?
    let contact: PersonDTO?
    // Detail-only:
    let description: String?
    let contributor: [PersonDTO]?
    let imported: String?
    let versionDoi: String?
    let url: String?
    let doi: String?

    struct PersonDTO: Decodable, Sendable {
        let given: String?
        let family: String?
        let organisation: String?
        let email: String?
    }
}
```

- [ ] **Step 1.3: Write `Source.swift`** (domain)

```swift
import Foundation

struct Source: Equatable, Hashable, Identifiable, Sendable {
    let key: Int
    let title: String
    let alias: String?
    let citation: String?
    let logoURL: URL?           // parsed from the `logo` string
    let license: String?
    let version: String?
    let issued: String?         // ISO date string
    let taxonomicScope: String?
    let geographicScope: String?
    // Detail-only (nil on list endpoint hits):
    let description: String?
    let websiteURL: URL?
    let doi: String?

    var id: Int { key }
}

extension Source {
    init(dto: SourceDTO) {
        self.init(
            key: dto.key,
            title: dto.title,
            alias: dto.alias,
            citation: dto.citation,
            logoURL: dto.logo.flatMap(URL.init(string:)),
            license: dto.license,
            version: dto.version,
            issued: dto.issued,
            taxonomicScope: dto.taxonomicScope,
            geographicScope: dto.geographicScope,
            description: dto.description,
            websiteURL: dto.url.flatMap(URL.init(string:)),
            doi: dto.doi
        )
    }
}
```

- [ ] **Step 1.4: Add Endpoints**

In `CatalogueOfLife/Networking/Endpoints.swift`, append:

```swift
static func sources(datasetKey: Int, limit: Int = 300) -> URL {
    var c = URLComponents(
        url: baseURL.appending(path: "dataset/\(datasetKey)/source"),
        resolvingAgainstBaseURL: false
    )!
    c.queryItems = [URLQueryItem(name: "limit", value: String(limit))]
    return c.url!
}

static func source(datasetKey: Int, sourceKey: Int) -> URL {
    baseURL
        .appending(path: "dataset")
        .appending(path: "\(datasetKey)")
        .appending(path: "source")
        .appending(path: "\(sourceKey)")
}
```

- [ ] **Step 1.5: Extend `APIClient` protocol**

Add two methods:

```swift
func listSources(datasetKey: Int) async throws -> [Source]
func getSource(datasetKey: Int, sourceKey: Int) async throws -> Source
```

Implementations in `APIClientLive.swift`:

```swift
func listSources(datasetKey: Int) async throws -> [Source] {
    let url = Endpoints.sources(datasetKey: datasetKey)
    let dtos = try await getJSON(url, as: [SourceDTO].self)
    return dtos.map(Source.init(dto:))
}

func getSource(datasetKey: Int, sourceKey: Int) async throws -> Source {
    let url = Endpoints.source(datasetKey: datasetKey, sourceKey: sourceKey)
    let dto = try await getJSON(url, as: SourceDTO.self)
    return Source(dto: dto)
}
```

> If Step 1.1 reveals the sources list is a paged dict (`{result: [...], total, ...}`), change `[SourceDTO].self` to `PagedDTO<SourceDTO>.self` and `dtos.map(...)` to `paged.result.map(...)`. Note the change in your report.

Also extend `StubAPIClient`:

```swift
var sources: [Int: [Source]] = [:]   // key: datasetKey
var sourceDetail: [Int: Source] = [:]  // key: sourceKey

func listSources(datasetKey: Int) async throws -> [Source] {
    if let error { throw error }
    return sources[datasetKey] ?? []
}

func getSource(datasetKey: Int, sourceKey: Int) async throws -> Source {
    if let error { throw error }
    guard let src = sourceDetail[sourceKey] else { throw APIError.notFound }
    return src
}
```

- [ ] **Step 1.6: Decoding tests**

`CatalogueOfLifeTests/SourceDecodingTests.swift`:

```swift
import Testing
import Foundation
@testable import CatalogueOfLife

@Suite("Source decoding")
struct SourceDecodingTests {
    @Test("Decodes the sources list fixture")
    func decodesList() throws {
        let data = try FixtureLoader.data("sources_list")
        let dtos = try JSONDecoder().decode([SourceDTO].self, from: data)
        let sources = dtos.map(Source.init(dto:))
        #expect(!sources.isEmpty)
        #expect(sources.allSatisfy { !$0.title.isEmpty })
    }

    @Test("Decodes the source detail fixture (description present)")
    func decodesDetail() throws {
        let data = try FixtureLoader.data("source_detail")
        let dto = try JSONDecoder().decode(SourceDTO.self, from: data)
        let source = Source(dto: dto)
        #expect(!source.title.isEmpty)
        #expect(source.key > 0)
    }
}
```

- [ ] **Step 1.7: Run tests + commit**

```bash
xcodegen generate
xcodebuild -scheme CatalogueOfLife -destination 'platform=iOS Simulator,name=iPhone 16e,OS=latest' test -quiet
```
Expected: 44/44 (42 + 2 new). All previous tests still pass.

```bash
git add CatalogueOfLife CatalogueOfLifeTests
git commit -m "Add sources list + detail endpoints with DTO and decoding tests"
```

---

## Task 2: SourcesView + SourceDetailView + wire to tab 3

**Files:**
- Create: `CatalogueOfLife/Features/Sources/SourcesViewModel.swift`
- Create: `CatalogueOfLife/Features/Sources/SourcesView.swift`
- Create: `CatalogueOfLife/Features/Sources/SourceRowView.swift`
- Create: `CatalogueOfLife/Features/Sources/SourceDetailView.swift`
- Create: `CatalogueOfLifeTests/SourcesViewModelTests.swift`
- Modify: `CatalogueOfLife/App/RootTabView.swift` — replace `TabPlaceholderView(title: "Sources", ...)` with `SourcesView()`

- [ ] **Step 2.1: `SourcesViewModel.swift`**

```swift
import Foundation
import Observation

@MainActor
@Observable
final class SourcesViewModel {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded([Source])
        case failed(APIError)
    }

    private(set) var state: LoadState = .idle
    var query: String = ""

    private let client: APIClient
    private let getDatasetKey: @MainActor () -> Int?

    init(client: APIClient, getDatasetKey: @escaping @MainActor () -> Int?) {
        self.client = client
        self.getDatasetKey = getDatasetKey
    }

    func load() async {
        guard let key = getDatasetKey() else {
            state = .failed(.server(status: -1))
            return
        }
        state = .loading
        do {
            let sources = try await client.listSources(datasetKey: key)
            state = .loaded(sources)
        } catch let err as APIError {
            state = .failed(err)
        } catch {
            state = .failed(.server(status: -1))
        }
    }

    func filtered() -> [Source] {
        guard case let .loaded(sources) = state else { return [] }
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty { return sources }
        return sources.filter { $0.title.lowercased().contains(q) || ($0.alias?.lowercased().contains(q) ?? false) }
    }
}
```

- [ ] **Step 2.2: `SourceRowView.swift`**

```swift
import SwiftUI

struct SourceRowView: View {
    let source: Source

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            logo
                .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(source.title).font(.body).lineLimit(2)
                if let alias = source.alias {
                    Text(alias).font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var logo: some View {
        if let url = source.logoURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img): img.resizable().scaledToFit()
                default: placeholder
                }
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(.secondary.opacity(0.15))
            .overlay(Image(systemName: "books.vertical").foregroundStyle(.secondary))
    }
}
```

- [ ] **Step 2.3: `SourcesView.swift`**

```swift
import SwiftUI

struct SourcesView: View {
    @Environment(AppState.self) private var appState
    @State private var vm: SourcesViewModel?
    @State private var selectedSourceKey: Int?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Sources")
                .toolbar { ToolbarItem(placement: .principal) { ReleasePicker() } }
                .navigationDestination(item: $selectedSourceKey) { key in
                    SourceDetailView(sourceKey: key)
                }
        }
        .task {
            if vm == nil {
                vm = SourcesViewModel(client: APIClientLive(),
                                       getDatasetKey: { [appState] in appState.selectedDataset?.key })
            }
            await vm?.load()
        }
    }

    @ViewBuilder
    private var content: some View {
        if let vm {
            @Bindable var vm = vm
            switch vm.state {
            case .loaded:
                List(vm.filtered()) { source in
                    Button { selectedSourceKey = source.key } label: {
                        SourceRowView(source: source)
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
                .searchable(text: $vm.query, prompt: "Filter sources")
            case .failed(let err):
                ContentUnavailableView("Couldn't load sources",
                                        systemImage: "exclamationmark.triangle",
                                        description: Text(String(describing: err)))
            case .idle, .loading:
                ProgressView()
            }
        } else {
            ProgressView()
        }
    }
}
```

- [ ] **Step 2.4: `SourceDetailView.swift`**

```swift
import SwiftUI

struct SourceDetailView: View {
    @Environment(AppState.self) private var appState
    let sourceKey: Int
    @State private var state: LoadState = .loading

    enum LoadState: Equatable {
        case loading
        case loaded(Source)
        case failed(APIError)
    }

    var body: some View {
        content
            .navigationTitle("Source")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .principal) { ReleasePicker() } }
            .task { await load() }
    }

    private func load() async {
        guard let key = appState.selectedDataset?.key else {
            state = .failed(.server(status: -1))
            return
        }
        state = .loading
        do {
            let source = try await APIClientLive().getSource(datasetKey: key, sourceKey: sourceKey)
            state = .loaded(source)
        } catch let err as APIError {
            state = .failed(err)
        } catch {
            state = .failed(.server(status: -1))
        }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .loaded(let source):
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SourceRowView(source: source)
                    if let citation = source.citation {
                        section("Citation") { Text(citation).font(.callout) }
                    }
                    if let description = source.description {
                        section("Description") { Text(description).font(.callout) }
                    }
                    metadata(source)
                }
                .padding()
            }
        case .failed(let err):
            ContentUnavailableView("Couldn't load source",
                                    systemImage: "exclamationmark.triangle",
                                    description: Text(String(describing: err)))
        case .loading:
            ProgressView()
        }
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            content()
        }
    }

    @ViewBuilder
    private func metadata(_ source: Source) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            metaRow("Version", source.version)
            metaRow("Issued", source.issued)
            metaRow("License", source.license)
            metaRow("Taxonomic scope", source.taxonomicScope)
            metaRow("Geographic scope", source.geographicScope)
            metaRow("DOI", source.doi)
            if let url = source.websiteURL {
                Link(url.absoluteString, destination: url).font(.callout)
            }
        }
    }

    @ViewBuilder
    private func metaRow(_ label: String, _ value: String?) -> some View {
        if let value, !value.isEmpty {
            HStack(alignment: .firstTextBaseline) {
                Text(label).font(.caption).foregroundStyle(.secondary).frame(width: 130, alignment: .leading)
                Text(value).font(.callout)
            }
        }
    }
}
```

- [ ] **Step 2.5: `SourcesViewModelTests.swift`**

```swift
import Testing
@testable import CatalogueOfLife

@Suite("SourcesViewModel")
@MainActor
struct SourcesViewModelTests {
    private func sample() -> [Source] {
        [
            Source(key: 1, title: "World Plants", alias: "WP", citation: nil, logoURL: nil,
                   license: nil, version: nil, issued: nil, taxonomicScope: "Plants", geographicScope: nil,
                   description: nil, websiteURL: nil, doi: nil),
            Source(key: 2, title: "World Birds", alias: "WB", citation: nil, logoURL: nil,
                   license: nil, version: nil, issued: nil, taxonomicScope: "Birds", geographicScope: nil,
                   description: nil, websiteURL: nil, doi: nil),
        ]
    }

    @Test("Loads sources and reports loaded state")
    func loadsList() async {
        let stub = StubAPIClient()
        stub.sources[9837] = sample()
        let vm = SourcesViewModel(client: stub, getDatasetKey: { 9837 })
        await vm.load()
        if case let .loaded(s) = vm.state { #expect(s.count == 2) }
        else { Issue.record("Expected .loaded; got \(vm.state)") }
    }

    @Test("filtered() narrows by case-insensitive title substring")
    func filtersByTitle() async {
        let stub = StubAPIClient()
        stub.sources[9837] = sample()
        let vm = SourcesViewModel(client: stub, getDatasetKey: { 9837 })
        await vm.load()
        vm.query = "plant"
        #expect(vm.filtered().map(\.key) == [1])
    }

    @Test("filtered() narrows by alias substring")
    func filtersByAlias() async {
        let stub = StubAPIClient()
        stub.sources[9837] = sample()
        let vm = SourcesViewModel(client: stub, getDatasetKey: { 9837 })
        await vm.load()
        vm.query = "WB"
        #expect(vm.filtered().map(\.key) == [2])
    }
}
```

- [ ] **Step 2.6: Wire into `RootTabView.swift`**

Read the current file. Find the `TabPlaceholderView(title: "Sources", ...)` row. Replace it with:

```swift
SourcesView()
    .tabItem { Label("Sources", systemImage: "books.vertical") }
```

- [ ] **Step 2.7: Run tests + commit**

```bash
xcodegen generate
xcodebuild -scheme CatalogueOfLife -destination 'platform=iOS Simulator,name=iPhone 16e,OS=latest' test -quiet
```
Expected: 47/47 (44 + 3 new VM tests).

```bash
git add CatalogueOfLife CatalogueOfLifeTests
git commit -m "Add SourcesView + SourceDetailView; wire into tab 3"
```

---

## Task 3: Breakdown + ImportMetrics endpoints + DTOs + decoding tests

**Files:**
- Create: `CatalogueOfLife/Models/DTOs/BreakdownDTO.swift`
- Create: `CatalogueOfLife/Models/DTOs/ImportMetricsDTO.swift`
- Create: `CatalogueOfLife/Models/Domain/BreakdownNode.swift`
- Create: `CatalogueOfLife/Models/Domain/ImportMetrics.swift`
- Create: `CatalogueOfLifeTests/Fixtures/dataset_breakdown.json`
- Create: `CatalogueOfLifeTests/Fixtures/import_metrics.json`
- Create: `CatalogueOfLifeTests/BreakdownDecodingTests.swift`
- Create: `CatalogueOfLifeTests/ImportMetricsDecodingTests.swift`
- Modify: `CatalogueOfLife/Networking/Endpoints.swift` — `datasetBreakdown(datasetKey:)`, `importMetrics(datasetKey:)`
- Modify: `CatalogueOfLife/Networking/APIClient.swift` — 2 new methods
- Modify: `CatalogueOfLife/Networking/APIClientLive.swift` — 2 new methods
- Modify: `CatalogueOfLifeTests/Helpers/StubAPIClient.swift` — 2 new stub stores

- [ ] **Step 3.1: Capture fixtures**

```bash
curl -s 'https://api.checklistbank.org/dataset/3LXR/breakdown' | python3 -m json.tool > CatalogueOfLifeTests/Fixtures/dataset_breakdown.json
curl -s 'https://api.checklistbank.org/dataset/3LXR/import' | python3 -m json.tool > CatalogueOfLifeTests/Fixtures/import_metrics.json
python3 -c "
import json
b = json.load(open('CatalogueOfLifeTests/Fixtures/dataset_breakdown.json'))
print('breakdown top keys:', sorted(b.keys()))
print('top groups:', len(b['breakdown']))
i = json.load(open('CatalogueOfLifeTests/Fixtures/import_metrics.json'))
print('import is list:', isinstance(i, list), 'len:', len(i) if isinstance(i, list) else '-')
print('import entry keys count:', len(i[0].keys()) if isinstance(i, list) and i else '-')
"
```
Expected: breakdown has 3 top-level entries (viruses, prokaryotes, eukaryotes); import is a list of 1 with ~40 fields.

- [ ] **Step 3.2: `BreakdownDTO.swift`**

```swift
import Foundation

/// Recursive group-based count tree, returned by `GET /dataset/{key}/breakdown`.
/// Wrapper: `{ datasetKey, breakdown: [BreakdownEntryDTO] }`.
struct BreakdownDTO: Decodable, Sendable {
    let datasetKey: Int
    let breakdown: [BreakdownEntryDTO]
}

struct BreakdownEntryDTO: Decodable, Sendable {
    let group: String?
    let count: Int
    let breakdown: [BreakdownEntryDTO]?
}
```

- [ ] **Step 3.3: `BreakdownNode.swift`** (domain)

```swift
import Foundation

/// Recursive group-based breakdown of a dataset.
struct BreakdownNode: Equatable, Identifiable, Hashable, Sendable {
    let id: String              // group name, or synthesized if nil
    let group: String?
    let count: Int
    let children: [BreakdownNode]
}

extension BreakdownNode {
    init(dto: BreakdownEntryDTO, path: String = "") {
        let label = dto.group ?? "_"
        let id = path.isEmpty ? label : "\(path)/\(label)"
        self.init(
            id: id,
            group: dto.group,
            count: dto.count,
            children: (dto.breakdown ?? []).map { BreakdownNode(dto: $0, path: id) }
        )
    }
}
```

- [ ] **Step 3.4: `ImportMetricsDTO.swift`**

The import endpoint exposes ~40 fields. Only decode the ones we'll display.

```swift
import Foundation

struct ImportMetricsDTO: Decodable, Sendable {
    let attempt: Int
    let datasetKey: Int
    let started: String?
    let finished: String?
    let state: String?
    let nameCount: Int?
    let taxonCount: Int?
    let synonymCount: Int?
    let vernacularCount: Int?
    let referenceCount: Int?
    let distributionCount: Int?
    let mediaCount: Int?
    let estimateCount: Int?
    let treatmentCount: Int?
    let typeMaterialCount: Int?
    let verbatimCount: Int?
    /// Rank → count maps:
    let taxaByRankCount: [String: Int]?
    let synonymsByRankCount: [String: Int]?
    let namesByRankCount: [String: Int]?
    let namesByStatusCount: [String: Int]?
    let vernacularsByLanguageCount: [String: Int]?
}
```

- [ ] **Step 3.5: `ImportMetrics.swift`** (domain)

```swift
import Foundation

/// A single metric line (label + value) for display.
struct MetricRow: Equatable, Identifiable, Sendable {
    let id: String
    let label: String
    let value: Int
}

struct ImportMetrics: Equatable, Sendable {
    let attempt: Int
    let finished: String?
    let state: String?
    /// Summary section: simple count rows ordered for display.
    let summary: [MetricRow]
    /// Grouped sections: section title -> [MetricRow], ordered.
    let sections: [(title: String, rows: [MetricRow])]

    static func == (lhs: ImportMetrics, rhs: ImportMetrics) -> Bool {
        lhs.attempt == rhs.attempt &&
        lhs.finished == rhs.finished &&
        lhs.state == rhs.state &&
        lhs.summary == rhs.summary &&
        lhs.sections.count == rhs.sections.count &&
        zip(lhs.sections, rhs.sections).allSatisfy { $0.title == $1.title && $0.rows == $1.rows }
    }
}

extension ImportMetrics {
    init(dto: ImportMetricsDTO) {
        func row(_ id: String, _ label: String, _ value: Int?) -> MetricRow? {
            guard let value, value > 0 else { return nil }
            return MetricRow(id: id, label: label, value: value)
        }
        let summary: [MetricRow] = [
            row("nameCount", "Names", dto.nameCount),
            row("taxonCount", "Accepted taxa", dto.taxonCount),
            row("synonymCount", "Synonyms", dto.synonymCount),
            row("vernacularCount", "Vernacular names", dto.vernacularCount),
            row("referenceCount", "References", dto.referenceCount),
            row("distributionCount", "Distributions", dto.distributionCount),
            row("mediaCount", "Media", dto.mediaCount),
            row("estimateCount", "Estimates", dto.estimateCount),
            row("treatmentCount", "Treatments", dto.treatmentCount),
            row("typeMaterialCount", "Type material", dto.typeMaterialCount),
            row("verbatimCount", "Verbatim records", dto.verbatimCount),
        ].compactMap { $0 }

        func mapRows(_ id: String, _ map: [String: Int]?) -> [MetricRow] {
            (map ?? [:])
                .filter { $0.value > 0 }
                .sorted { $0.value > $1.value }
                .map { MetricRow(id: "\(id)/\($0.key)", label: $0.key.capitalized, value: $0.value) }
        }

        let sections: [(String, [MetricRow])] = [
            ("Taxa by rank", mapRows("taxaByRank", dto.taxaByRankCount)),
            ("Names by rank", mapRows("namesByRank", dto.namesByRankCount)),
            ("Names by status", mapRows("namesByStatus", dto.namesByStatusCount)),
            ("Synonyms by rank", mapRows("synonymsByRank", dto.synonymsByRankCount)),
            ("Vernaculars by language", mapRows("vernByLang", dto.vernacularsByLanguageCount)),
        ].filter { !$0.1.isEmpty }

        self.init(
            attempt: dto.attempt,
            finished: dto.finished,
            state: dto.state,
            summary: summary,
            sections: sections
        )
    }
}
```

- [ ] **Step 3.6: Endpoints + APIClient methods**

In `Endpoints.swift`:

```swift
static func datasetBreakdown(datasetKey: Int) -> URL {
    baseURL.appending(path: "dataset/\(datasetKey)/breakdown")
}

static func importMetrics(datasetKey: Int) -> URL {
    baseURL.appending(path: "dataset/\(datasetKey)/import")
}
```

In `APIClient.swift` (add to protocol):

```swift
func getDatasetBreakdown(datasetKey: Int) async throws -> BreakdownNode
func getImportMetrics(datasetKey: Int) async throws -> ImportMetrics?
```

In `APIClientLive.swift`:

```swift
func getDatasetBreakdown(datasetKey: Int) async throws -> BreakdownNode {
    let url = Endpoints.datasetBreakdown(datasetKey: datasetKey)
    let dto = try await getJSON(url, as: BreakdownDTO.self)
    return BreakdownNode(
        id: "root",
        group: nil,
        count: dto.breakdown.reduce(0) { $0 + $1.count },
        children: dto.breakdown.map { BreakdownNode(dto: $0) }
    )
}

func getImportMetrics(datasetKey: Int) async throws -> ImportMetrics? {
    let url = Endpoints.importMetrics(datasetKey: datasetKey)
    let dtos = try await getJSON(url, as: [ImportMetricsDTO].self)
    return dtos.first.map(ImportMetrics.init(dto:))
}
```

In `StubAPIClient.swift`:

```swift
var datasetBreakdown: [Int: BreakdownNode] = [:]
var importMetrics: [Int: ImportMetrics] = [:]

func getDatasetBreakdown(datasetKey: Int) async throws -> BreakdownNode {
    if let error { throw error }
    guard let bd = datasetBreakdown[datasetKey] else { throw APIError.notFound }
    return bd
}

func getImportMetrics(datasetKey: Int) async throws -> ImportMetrics? {
    if let error { throw error }
    return importMetrics[datasetKey]
}
```

- [ ] **Step 3.7: Decoding tests**

`BreakdownDecodingTests.swift`:

```swift
import Testing
import Foundation
@testable import CatalogueOfLife

@Suite("Breakdown decoding")
struct BreakdownDecodingTests {
    @Test("Decodes dataset breakdown into a 2-level tree")
    func decodes() throws {
        let data = try FixtureLoader.data("dataset_breakdown")
        let dto = try JSONDecoder().decode(BreakdownDTO.self, from: data)
        let root = BreakdownNode(
            id: "root", group: nil,
            count: dto.breakdown.reduce(0) { $0 + $1.count },
            children: dto.breakdown.map { BreakdownNode(dto: $0) }
        )
        #expect(root.children.count >= 2)
        let groups = Set(root.children.compactMap(\.group))
        #expect(groups.contains("eukaryotes"))
        // At least one top-level group should have child groups
        #expect(root.children.contains { !$0.children.isEmpty })
        // Total count is positive
        #expect(root.count > 0)
    }
}
```

`ImportMetricsDecodingTests.swift`:

```swift
import Testing
import Foundation
@testable import CatalogueOfLife

@Suite("Import metrics decoding")
struct ImportMetricsDecodingTests {
    @Test("Decodes import metrics fixture into summary + sections")
    func decodes() throws {
        let data = try FixtureLoader.data("import_metrics")
        let dtos = try JSONDecoder().decode([ImportMetricsDTO].self, from: data)
        #expect(dtos.count >= 1)
        let metrics = ImportMetrics(dto: dtos[0])
        #expect(metrics.attempt > 0)
        #expect(!metrics.summary.isEmpty)
        #expect(metrics.summary.contains { $0.id == "nameCount" })
        // Rank-bucketed sections should exist
        #expect(metrics.sections.contains { $0.title == "Taxa by rank" })
    }
}
```

- [ ] **Step 3.8: Run tests + commit**

```bash
xcodegen generate
xcodebuild -scheme CatalogueOfLife -destination 'platform=iOS Simulator,name=iPhone 16e,OS=latest' test -quiet
```
Expected: 49/49 (47 + 2 new).

```bash
git add CatalogueOfLife CatalogueOfLifeTests
git commit -m "Add dataset breakdown + import metrics endpoints with DTOs and tests"
```

---

## Task 4: SunburstView component + math tests

A reusable SwiftUI Canvas-based sunburst. Renders any tree of `SunburstNode` (label + count + children) up to a configurable depth (default 2 rings). Tap → callback with that node's id.

**Files:**
- Create: `CatalogueOfLife/Models/Domain/SunburstNode.swift`
- Create: `CatalogueOfLife/Components/SunburstView.swift`
- Create: `CatalogueOfLifeTests/SunburstMathTests.swift`

- [ ] **Step 4.1: `SunburstNode.swift`**

```swift
import Foundation

/// Generic input to `SunburstView`. Concrete sources (BreakdownNode, TreeNode children)
/// map into this shape.
struct SunburstNode: Equatable, Hashable, Identifiable, Sendable {
    let id: String
    let label: String
    let count: Int
    let children: [SunburstNode]
}

extension SunburstNode {
    /// Map a `BreakdownNode` tree into the renderer shape.
    static func from(breakdown: BreakdownNode) -> SunburstNode {
        SunburstNode(
            id: breakdown.id,
            label: breakdown.group ?? "—",
            count: breakdown.count,
            children: breakdown.children.map(SunburstNode.from(breakdown:))
        )
    }
}
```

- [ ] **Step 4.2: `SunburstView.swift`**

```swift
import SwiftUI

struct SunburstView: View {
    let root: SunburstNode
    /// Max number of rings beyond the center. Default 2.
    var maxDepth: Int = 2
    /// Tap handler: receives the tapped node's id (nil for center disk).
    var onSelect: (SunburstNode) -> Void = { _ in }

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let outerRadius = size / 2 * 0.95
            let innerRadius = outerRadius * 0.25
            let ringThickness = (outerRadius - innerRadius) / CGFloat(maxDepth)

            ZStack {
                Canvas { context, _ in
                    SunburstMath.draw(
                        root: root,
                        center: center,
                        innerRadius: innerRadius,
                        ringThickness: ringThickness,
                        maxDepth: maxDepth,
                        context: &context
                    )
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Sunburst diagram")
                .frame(width: size, height: size)
                .contentShape(Circle())
                .gesture(
                    SpatialTapGesture().onEnded { value in
                        if let hit = SunburstMath.hitTest(
                            point: value.location,
                            center: center,
                            innerRadius: innerRadius,
                            ringThickness: ringThickness,
                            root: root,
                            maxDepth: maxDepth
                        ) {
                            onSelect(hit)
                        }
                    }
                )
                Text(root.label)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: innerRadius * 1.6)
                    .multilineTextAlignment(.center)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
```

- [ ] **Step 4.3: Math + draw helpers in the same `SunburstView.swift` file**

Append:

```swift
enum SunburstMath {

    /// Computes the angular sweep (in radians) of a child within its parent's sweep,
    /// weighted by `count` against its siblings' total counts.
    static func childSweep(child: SunburstNode, siblingsTotal: Int, parentSweep: Double) -> Double {
        guard siblingsTotal > 0 else { return 0 }
        return parentSweep * Double(child.count) / Double(siblingsTotal)
    }

    /// Walks the tree and draws each arc. `depth` 1 is the first ring beyond center.
    static func draw(
        root: SunburstNode,
        center: CGPoint,
        innerRadius: CGFloat,
        ringThickness: CGFloat,
        maxDepth: Int,
        context: inout GraphicsContext
    ) {
        let total = max(root.children.reduce(0) { $0 + $1.count }, 1)
        drawChildren(
            parent: root,
            startAngle: -Double.pi / 2,
            sweep: 2 * .pi,
            siblingsTotal: total,
            depth: 1,
            center: center,
            innerRadius: innerRadius,
            ringThickness: ringThickness,
            maxDepth: maxDepth,
            context: &context
        )
    }

    private static func drawChildren(
        parent: SunburstNode,
        startAngle: Double,
        sweep: Double,
        siblingsTotal: Int,
        depth: Int,
        center: CGPoint,
        innerRadius: CGFloat,
        ringThickness: CGFloat,
        maxDepth: Int,
        context: inout GraphicsContext
    ) {
        guard depth <= maxDepth else { return }
        var cursor = startAngle
        for (idx, child) in parent.children.enumerated() {
            let childSweep = SunburstMath.childSweep(child: child, siblingsTotal: siblingsTotal, parentSweep: sweep)
            drawArc(
                center: center,
                innerR: innerRadius + CGFloat(depth - 1) * ringThickness,
                outerR: innerRadius + CGFloat(depth) * ringThickness,
                startAngle: cursor,
                endAngle: cursor + childSweep,
                color: arcColor(depth: depth, index: idx, total: parent.children.count),
                context: &context
            )
            if !child.children.isEmpty {
                let grandTotal = max(child.children.reduce(0) { $0 + $1.count }, 1)
                drawChildren(
                    parent: child,
                    startAngle: cursor,
                    sweep: childSweep,
                    siblingsTotal: grandTotal,
                    depth: depth + 1,
                    center: center,
                    innerRadius: innerRadius,
                    ringThickness: ringThickness,
                    maxDepth: maxDepth,
                    context: &context
                )
            }
            cursor += childSweep
        }
    }

    private static func drawArc(
        center: CGPoint,
        innerR: CGFloat,
        outerR: CGFloat,
        startAngle: Double,
        endAngle: Double,
        color: Color,
        context: inout GraphicsContext
    ) {
        var path = Path()
        path.addArc(center: center, radius: outerR,
                    startAngle: Angle(radians: startAngle),
                    endAngle: Angle(radians: endAngle), clockwise: false)
        path.addArc(center: center, radius: innerR,
                    startAngle: Angle(radians: endAngle),
                    endAngle: Angle(radians: startAngle), clockwise: true)
        path.closeSubpath()
        context.fill(path, with: .color(color))
        context.stroke(path, with: .color(.white.opacity(0.6)), lineWidth: 0.5)
    }

    private static func arcColor(depth: Int, index: Int, total: Int) -> Color {
        let hue = Double(index) / Double(max(total, 1))
        let saturation = depth == 1 ? 0.55 : 0.40
        let brightness = depth == 1 ? 0.85 : 0.75
        return Color(hue: hue, saturation: saturation, brightness: brightness)
    }

    /// Returns the deepest hit node at `point`, or nil if outside the sunburst.
    static func hitTest(
        point: CGPoint,
        center: CGPoint,
        innerRadius: CGFloat,
        ringThickness: CGFloat,
        root: SunburstNode,
        maxDepth: Int
    ) -> SunburstNode? {
        let dx = point.x - center.x
        let dy = point.y - center.y
        let radius = (dx * dx + dy * dy).squareRoot()
        guard radius >= innerRadius else { return nil }    // center disk: no hit
        let outerR = innerRadius + CGFloat(maxDepth) * ringThickness
        guard radius <= outerR else { return nil }
        let depth = Int(((radius - innerRadius) / ringThickness)) + 1
        guard depth >= 1, depth <= maxDepth else { return nil }
        var angle = atan2(Double(dy), Double(dx))
        // Normalize so 0 is "up" (matches drawing's startAngle = -π/2).
        angle += .pi / 2
        if angle < 0 { angle += 2 * .pi }
        return descend(parent: root, parentSweepStart: 0, parentSweepEnd: 2 * .pi, depth: 1, targetDepth: depth, targetAngle: angle)
    }

    private static func descend(
        parent: SunburstNode,
        parentSweepStart: Double,
        parentSweepEnd: Double,
        depth: Int,
        targetDepth: Int,
        targetAngle: Double
    ) -> SunburstNode? {
        let totalChildren = max(parent.children.reduce(0) { $0 + $1.count }, 1)
        let parentSweep = parentSweepEnd - parentSweepStart
        var cursor = parentSweepStart
        for child in parent.children {
            let childSweep = SunburstMath.childSweep(child: child, siblingsTotal: totalChildren, parentSweep: parentSweep)
            let childEnd = cursor + childSweep
            if targetAngle >= cursor, targetAngle < childEnd {
                if depth == targetDepth {
                    return child
                }
                return descend(parent: child,
                                parentSweepStart: cursor,
                                parentSweepEnd: childEnd,
                                depth: depth + 1,
                                targetDepth: targetDepth,
                                targetAngle: targetAngle)
            }
            cursor = childEnd
        }
        return nil
    }
}
```

- [ ] **Step 4.4: `SunburstMathTests.swift`**

```swift
import Testing
import Foundation
@testable import CatalogueOfLife

@Suite("Sunburst math")
struct SunburstMathTests {
    private func node(_ id: String, count: Int, _ children: [SunburstNode] = []) -> SunburstNode {
        SunburstNode(id: id, label: id, count: count, children: children)
    }

    @Test("Equal-count children get equal sweeps")
    func equalCountSweeps() {
        let sweep1 = SunburstMath.childSweep(child: node("A", count: 10), siblingsTotal: 30, parentSweep: .pi)
        let sweep2 = SunburstMath.childSweep(child: node("B", count: 10), siblingsTotal: 30, parentSweep: .pi)
        let sweep3 = SunburstMath.childSweep(child: node("C", count: 10), siblingsTotal: 30, parentSweep: .pi)
        #expect((sweep1 + sweep2 + sweep3).isApproximately(.pi))
        #expect(sweep1.isApproximately(.pi / 3))
    }

    @Test("Weighted children get proportional sweeps")
    func weightedSweeps() {
        let total = 100
        let big = SunburstMath.childSweep(child: node("Big", count: 80), siblingsTotal: total, parentSweep: 2 * .pi)
        let small = SunburstMath.childSweep(child: node("Small", count: 20), siblingsTotal: total, parentSweep: 2 * .pi)
        #expect(big.isApproximately(2 * .pi * 0.8))
        #expect(small.isApproximately(2 * .pi * 0.2))
    }

    @Test("Hit-test inside inner radius returns nil")
    func hitTestCenter() {
        let root = node("R", count: 10, [node("A", count: 10)])
        let result = SunburstMath.hitTest(
            point: CGPoint(x: 100, y: 100),
            center: CGPoint(x: 100, y: 100),
            innerRadius: 30, ringThickness: 30, root: root, maxDepth: 2
        )
        #expect(result == nil)
    }

    @Test("Hit-test outside outer radius returns nil")
    func hitTestOutside() {
        let root = node("R", count: 10, [node("A", count: 10)])
        let result = SunburstMath.hitTest(
            point: CGPoint(x: 1000, y: 1000),
            center: CGPoint(x: 100, y: 100),
            innerRadius: 30, ringThickness: 30, root: root, maxDepth: 2
        )
        #expect(result == nil)
    }

    @Test("Hit-test on ring 1 returns a direct child")
    func hitTestRing1() {
        // Single full-circle child; point just above center should land on it.
        let onlyChild = node("Only", count: 10)
        let root = node("R", count: 10, [onlyChild])
        let result = SunburstMath.hitTest(
            point: CGPoint(x: 100, y: 50),     // straight up from center
            center: CGPoint(x: 100, y: 100),
            innerRadius: 30, ringThickness: 30, root: root, maxDepth: 2
        )
        #expect(result?.id == "Only")
    }
}

private extension Double {
    func isApproximately(_ other: Double, tolerance: Double = 1e-9) -> Bool {
        abs(self - other) < tolerance
    }
}
```

- [ ] **Step 4.5: Run tests + commit**

```bash
xcodegen generate
xcodebuild -scheme CatalogueOfLife -destination 'platform=iOS Simulator,name=iPhone 16e,OS=latest' test -quiet
```
Expected: 54/54 (49 + 5 new sunburst math tests).

```bash
git add CatalogueOfLife CatalogueOfLifeTests
git commit -m "Add SunburstView (Canvas-based) with sweep math + hit-test tests"
```

---

## Task 5: MetricsView + wire to tab 4

**Files:**
- Create: `CatalogueOfLife/Features/Metrics/MetricsViewModel.swift`
- Create: `CatalogueOfLife/Features/Metrics/MetricsView.swift`
- Create: `CatalogueOfLife/Features/Metrics/ImportMetricsList.swift`
- Modify: `CatalogueOfLife/App/RootTabView.swift` — swap Metrics placeholder for `MetricsView()`

- [ ] **Step 5.1: `MetricsViewModel.swift`**

```swift
import Foundation
import Observation

@MainActor
@Observable
final class MetricsViewModel {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded(breakdown: BreakdownNode, metrics: ImportMetrics?)
        case failed(APIError)
    }

    private(set) var state: LoadState = .idle

    private let client: APIClient
    private let getDatasetKey: @MainActor () -> Int?

    init(client: APIClient, getDatasetKey: @escaping @MainActor () -> Int?) {
        self.client = client
        self.getDatasetKey = getDatasetKey
    }

    func load() async {
        guard let key = getDatasetKey() else {
            state = .failed(.server(status: -1))
            return
        }
        state = .loading
        do {
            async let breakdown = try await client.getDatasetBreakdown(datasetKey: key)
            async let metrics = try? await client.getImportMetrics(datasetKey: key)
            let bd = try await breakdown
            let m = await metrics ?? nil
            state = .loaded(breakdown: bd, metrics: m)
        } catch let err as APIError {
            state = .failed(err)
        } catch {
            state = .failed(.server(status: -1))
        }
    }
}
```

- [ ] **Step 5.2: `ImportMetricsList.swift`**

```swift
import SwiftUI

struct ImportMetricsList: View {
    let metrics: ImportMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !metrics.summary.isEmpty {
                section(title: "Summary", rows: metrics.summary)
            }
            ForEach(metrics.sections, id: \.title) { section in
                self.section(title: section.title, rows: section.rows)
            }
        }
    }

    private func section(title: String, rows: [MetricRow]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            ForEach(rows) { row in
                HStack {
                    Text(row.label).font(.callout)
                    Spacer()
                    Text(row.value, format: .number).font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
```

- [ ] **Step 5.3: `MetricsView.swift`**

```swift
import SwiftUI

struct MetricsView: View {
    @Environment(AppState.self) private var appState
    @State private var vm: MetricsViewModel?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Metrics")
                .toolbar { ToolbarItem(placement: .principal) { ReleasePicker() } }
        }
        .task {
            if vm == nil {
                vm = MetricsViewModel(client: APIClientLive(),
                                       getDatasetKey: { [appState] in appState.selectedDataset?.key })
            }
            await vm?.load()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch vm?.state {
        case .loaded(let breakdown, let metrics):
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Taxonomic breakdown")
                        .font(.headline)
                    SunburstView(root: SunburstNode.from(breakdown: breakdown))
                        .frame(maxWidth: .infinity)
                        .frame(height: 320)
                    if let metrics {
                        ImportMetricsList(metrics: metrics)
                    }
                }
                .padding()
            }
        case .failed(let err):
            ContentUnavailableView("Couldn't load metrics",
                                    systemImage: "exclamationmark.triangle",
                                    description: Text(String(describing: err)))
        case .loading, .idle, .none:
            ProgressView()
        }
    }
}
```

- [ ] **Step 5.4: Wire in `RootTabView.swift`**

Replace the Metrics placeholder line with:

```swift
MetricsView()
    .tabItem { Label("Metrics", systemImage: "chart.pie") }
```

- [ ] **Step 5.5: Run tests + commit**

```bash
xcodegen generate
xcodebuild -scheme CatalogueOfLife -destination 'platform=iOS Simulator,name=iPhone 16e,OS=latest' test -quiet
```
Expected: 54/54 (no new tests this task — the components are tested via decoding + sunburst math).

```bash
git add CatalogueOfLife
git commit -m "Add MetricsView with dataset sunburst + import metrics list; wire to tab 4"
```

---

## Task 6: AboutView (content + vernacular language picker + release metadata) + wire to tab 5

**Files:**
- Create: `CatalogueOfLife/Features/About/AboutView.swift`
- Create: `CatalogueOfLife/Features/About/PreferredLanguagePicker.swift`
- Modify: `CatalogueOfLife/App/RootTabView.swift` — swap About placeholder for `AboutView()`

- [ ] **Step 6.1: `PreferredLanguagePicker.swift`**

```swift
import SwiftUI

struct PreferredLanguagePicker: View {
    @Environment(AppState.self) private var appState

    /// (storedCode, displayLabel). nil code = "None / system default" (system fallback handled by AppState).
    private static let languages: [(String?, String)] = [
        (nil, "System default"),
        ("eng", "English"),
        ("spa", "Español"),
        ("fra", "Français"),
        ("deu", "Deutsch"),
        ("por", "Português"),
        ("ita", "Italiano"),
        ("nld", "Nederlands"),
        ("zho", "中文"),
        ("jpn", "日本語"),
        ("rus", "Русский"),
        ("ara", "العربية"),
    ]

    var body: some View {
        @Bindable var state = appState
        Picker("Common-name language", selection: $state.preferredVernacularLang) {
            ForEach(Self.languages, id: \.0) { code, label in
                Text(label).tag(code)
            }
        }
        .pickerStyle(.menu)
    }
}
```

- [ ] **Step 6.2: `AboutView.swift`**

```swift
import SwiftUI

struct AboutView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    introSection
                    Divider()
                    identifiersSection
                    Divider()
                    preferencesSection
                    Divider()
                    releaseMetadataSection
                }
                .padding()
            }
            .navigationTitle("About")
            .toolbar { ToolbarItem(placement: .principal) { ReleasePicker() } }
        }
    }

    private var introSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Catalogue of Life").font(.title2).bold()
            Text("""
            The Catalogue of Life (CoL) is the most comprehensive and authoritative \
            global index of species. It combines hundreds of taxonomic sources into a \
            single, unified checklist of every named living and recently extinct organism.
            """)
                .font(.callout)
            Link("www.catalogueoflife.org", destination: URL(string: "https://www.catalogueoflife.org")!)
                .font(.callout)
        }
    }

    private var identifiersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Identifiers").font(.headline)
            Text("""
            Each taxon in CoL has a short alphanumeric identifier (e.g. COL:CS5HF). \
            Identifiers in the latest extended release (3LXR) and the base release (3LR) \
            are stable and tracked by GBIF. Identifiers in older annual releases differ \
            and may not resolve elsewhere.
            """)
                .font(.callout)
        }
    }

    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Preferences").font(.headline)
            HStack {
                Text("Common-name language").font(.callout)
                Spacer()
                PreferredLanguagePicker()
            }
        }
    }

    @ViewBuilder
    private var releaseMetadataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Selected release").font(.headline)
            if let dataset = appState.selectedDataset {
                meta("Title", dataset.title)
                meta("Alias", dataset.alias)
                meta("Version", dataset.version)
                meta("Issued", dataset.issued)
                meta("Origin", dataset.origin)
                meta("Key", "\(dataset.key)")
                if let citation = dataset.citation {
                    Text("Citation").font(.subheadline).bold()
                    Text(citation).font(.caption).foregroundStyle(.secondary)
                }
            } else {
                Text("Loading release information…").font(.callout).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func meta(_ label: String, _ value: String?) -> some View {
        if let value, !value.isEmpty {
            HStack(alignment: .firstTextBaseline) {
                Text(label).font(.caption).foregroundStyle(.secondary).frame(width: 90, alignment: .leading)
                Text(value).font(.callout)
            }
        }
    }
}
```

- [ ] **Step 6.3: Wire in `RootTabView.swift`**

Replace the About placeholder line with:

```swift
AboutView()
    .tabItem { Label("About", systemImage: "info.circle") }
```

- [ ] **Step 6.4: Build + commit**

```bash
xcodegen generate
xcodebuild -scheme CatalogueOfLife -destination 'platform=iOS Simulator,name=iPhone 16e,OS=latest' build -quiet
xcodebuild -scheme CatalogueOfLife -destination 'platform=iOS Simulator,name=iPhone 16e,OS=latest' test -quiet
```
Expected: 54/54.

```bash
git add CatalogueOfLife
git commit -m "Add AboutView with intro, preferences picker, and release metadata; wire to tab 5"
```

---

## Task 7: Sunburst on taxon detail page (single-ring from tree children)

The per-taxon `/breakdown` endpoint does not exist. Instead, we fetch immediate children via `getTreeChildren(datasetKey: parentId: taxonId)` and render a single-ring sunburst weighted by each child's `count` (descendant count). Skip rendering entirely if there are no children (leaf taxa). Tap on an arc → push that taxon's detail.

**Files:**
- Modify: `CatalogueOfLife/Features/Taxon/TaxonDetailView.swift` — fetch children after info loads; insert `SunburstView` after `ClassificationChipsView` and before `SynonymyView`

- [ ] **Step 7.1: Modify `TaxonDetailView.swift`**

Read the current file. Below `@State private var navigateTo: String?`, add:

```swift
    @State private var childNodes: [TreeNode] = []
```

In the `.task` block, after the recents bump, add a tree-children fetch:

```swift
    if case let .loaded(info) = vm?.state, let key = appState.selectedDataset?.key {
        // bumpRecent (existing)
        PersistenceStore.bumpRecent(modelContext,
                                     datasetKey: key,
                                     taxonId: info.taxonId,
                                     name: info.scientificName,
                                     rank: info.rank.rawValue,
                                     group: info.group)
        // Fetch children for the sunburst (best-effort; ignore errors)
        if let children = try? await APIClientLive().getTreeChildren(datasetKey: key, parentId: info.taxonId) {
            childNodes = children
        }
    }
```

Insert the sunburst block between `ClassificationChipsView(...)` and `SynonymyView(groups:)` in the `.loaded(let info)` case:

```swift
    if !childNodes.isEmpty {
        VStack(alignment: .leading, spacing: 6) {
            Text("Breakdown of \(info.scientificName)").font(.headline)
            SunburstView(
                root: sunburstRoot(for: info),
                maxDepth: 1
            ) { node in
                navigateTo = node.id
            }
            .frame(maxWidth: .infinity)
            .frame(height: 260)
        }
    }
```

Add a helper at the bottom of the struct (before the closing `}`):

```swift
    private func sunburstRoot(for info: TaxonInfo) -> SunburstNode {
        SunburstNode(
            id: info.taxonId,
            label: info.scientificName,
            count: childNodes.reduce(0) { $0 + $1.count },
            children: childNodes.map {
                SunburstNode(id: $0.id, label: $0.name, count: max($0.count, 1), children: [])
            }
        )
    }
```

`max($0.count, 1)` ensures children with `count == 0` (leaves) still get a visible arc.

- [ ] **Step 7.2: Build + manual smoke**

```bash
xcodegen generate
xcodebuild -scheme CatalogueOfLife -destination 'platform=iOS Simulator,name=iPhone 16e,OS=latest' build -quiet
xcodebuild -scheme CatalogueOfLife -destination 'platform=iOS Simulator,name=iPhone 16e,OS=latest' test -quiet
```
Expected: 54/54 pass.

```bash
xcodebuild -scheme CatalogueOfLife -destination 'platform=iOS Simulator,name=iPhone 16e,OS=latest' -configuration Debug -derivedDataPath /tmp/col-mobile-dd build -quiet
APP_PATH=$(find /tmp/col-mobile-dd/Build/Products -name CatalogueOfLife.app -type d | head -1)
SIM_ID=$(xcrun simctl list devices booted -j | python3 -c "import json,sys; d=json.load(sys.stdin); [print(dev['udid']) for runtime in d['devices'] for dev in d['devices'][runtime] if dev.get('state')=='Booted'][0]")
xcrun simctl install "$SIM_ID" "$APP_PATH"
xcrun simctl launch "$SIM_ID" org.catalogueoflife.mobile
sleep 4
xcrun simctl io "$SIM_ID" screenshot /tmp/col-mobile-plan3-task7.png
```

In the simulator, navigate Search → "Felis" → tap genus row → verify the breakdown sunburst renders below the classification, before synonymy.

- [ ] **Step 7.3: Commit**

```bash
git add CatalogueOfLife/Features/Taxon/TaxonDetailView.swift
git commit -m "Add single-ring sunburst to taxon detail using tree children counts"
```

---

## Task 8: Plan 3 final checkpoint

- [ ] **Step 8.1: Full test suite**

```bash
xcodegen generate
xcodebuild -scheme CatalogueOfLife -destination 'platform=iOS Simulator,name=iPhone 16e,OS=latest' test -quiet
```
Expected: 54 tests pass.

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

- [ ] **Step 8.3: End-to-end manual smoke**

Install + launch, exercise every tab:
1. Tree — load + drill down + suggest works + star-circle opens bookmarks
2. Search — search "Felis", icons appear, tap result → details with sunburst
3. Sources — list with logos, tap → detail with metadata
4. Metrics — release info + dataset sunburst + import metrics list
5. About — intro + identifiers + preferences picker + release metadata that changes with the picker
6. Switch release picker to COL24 — About metadata refreshes; Sources reloads for that release

---

## Self-review of this plan against the spec

- **§6 tab 3 (Sources)** — list with logo + title (Task 2), source detail with all metrics (Task 2). ✓
- **§6 tab 4 (Metrics)** — dataset taxonomic sunburst (Tasks 3 + 4 + 5), dataset import metrics list (Tasks 3 + 5). ✓
- **§6 tab 5 (About)** — intro + identifiers explanation + preferences (vernacular language picker) + release metadata that re-renders with picker selection (Task 6). ✓
- **§7 taxon detail sunburst** — single-ring (since per-taxon `/breakdown` endpoint doesn't exist); from tree children weighted by descendant count (Task 7). The plan's "2 rings" target is intentionally relaxed to "1 ring from /tree/{id}/children" and documented in Task 7's preface.
- **§8 Sunburst** — `SunburstView` Canvas component with sweep math, hit-testing, configurable depth (Task 4). The dataset-level renders 2 rings (matches §8 "fixed depth 2"); per-taxon falls back to 1 ring as documented.
- **§10 Vernacular language preference UI** — `PreferredLanguagePicker` in About; `AppState.preferredVernacularLang` already piped to display (storage + display landed in Plan 1.5). ✓
- **§5.1 endpoints** — `listSources`, `getSource` (Task 1); `getDatasetBreakdown`, `getImportMetrics` (Task 3). All four added to the protocol and live impl.
- **§13 testing** — fixtures + decoding tests for Sources, Breakdown, ImportMetrics; sunburst sweep + hit-test math tests; VM tests for SourcesViewModel.
- **§14 CI** — no workflow changes; existing CI covers everything.

No placeholders. Every step has the exact code or command. The per-taxon sunburst's reduced depth (1 ring vs 2) is the one intentional deviation from the original spec, justified by API reality and called out in the plan preface and in Task 7.
