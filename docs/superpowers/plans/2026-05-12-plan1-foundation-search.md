# Plan 1 — Foundation + Search slice

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a first runnable iPhone build that loads CoL releases, lets the user pick the active release, search names, and view a basic taxon detail page (header + classification + synonymy + vernacular names).

**Architecture:** SwiftUI on iOS 18+, `@Observable` view-models, env-injected `AppState`, `URLSession`-backed `APIClient` (actor) returning typed domain models. Project file generated from `project.yml` via XcodeGen so the source of truth lives in the repo and diffs cleanly.

**Tech Stack:** Swift 6, SwiftUI, Swift Testing, `URLSession`, `URLCache`, `UserDefaults`, XcodeGen (build-tool only), GitHub Actions on `macos-15`.

**Spec reference:** `docs/superpowers/specs/2026-05-12-col-mobile-design.md` — Plan 1 implements §2, §3, §4, §5.1 (4 endpoints), §6 (tab2 + placeholder shells for the other 4 tabs + global release picker), §7 (sections 1–4 only, no sunburst/GBIF), §10 (storage + display only — picker UI deferred to Plan 3), §12 (error/loading), §13 (tests), §14 (CI).

**Out of scope for Plan 1 (deferred to later plans):**
- Tab1 (Tree), tab3 (Sources), tab4 (Metrics), tab5 (About) bodies — placeholders only
- Sunburst (`SunburstView`) — Plan 3
- TaxGroup `/vocab/taxgroup` + `GroupIcon` — Plan 2
- SwiftData favorites/recents + FavoritesSheet — Plan 2
- About-tab vernacular language picker UI — Plan 3 (storage + display lands here)
- GBIF integration (metrics, map, image carousel) — Plan 4
- "Open on catalogueoflife.org / checklistbank.org" detail toolbar action — Plan 2

---

## File map

**Created in this plan:**

```
project.yml                                       # XcodeGen spec
.github/workflows/ci.yml                          # CI

CatalogueOfLife/
├── App/
│   ├── CatalogueOfLifeApp.swift                  # @main entry
│   ├── AppState.swift                            # @Observable AppState
│   ├── RootTabView.swift                         # TabView + global release picker
│   └── ReleasePicker.swift                       # toolbar picker
├── Networking/
│   ├── APIClient.swift                           # protocol
│   ├── APIClientLive.swift                       # URLSession actor
│   ├── APIError.swift                            # APIError enum
│   ├── HTTPSession.swift                         # URLCache config
│   └── Endpoints.swift                           # URL builders
├── Models/
│   ├── DTOs/
│   │   ├── DatasetDTO.swift
│   │   ├── PagedDTO.swift
│   │   ├── NameUsageSearchHitDTO.swift
│   │   ├── TaxonInfoDTO.swift
│   │   └── VernacularNameDTO.swift
│   └── Domain/
│       ├── DatasetRef.swift
│       ├── Rank.swift
│       ├── TaxonStatus.swift
│       ├── SearchHit.swift
│       ├── TaxonInfo.swift
│       ├── ClassificationItem.swift
│       ├── SynonymyGroup.swift
│       └── VernacularName.swift
├── Features/
│   ├── Search/
│   │   ├── SearchView.swift
│   │   └── SearchViewModel.swift
│   ├── Taxon/
│   │   ├── TaxonDetailView.swift
│   │   ├── TaxonDetailViewModel.swift
│   │   ├── TaxonHeaderView.swift
│   │   ├── ClassificationChipsView.swift
│   │   ├── SynonymyView.swift
│   │   └── VernacularNamesView.swift
│   └── Placeholders/
│       └── TabPlaceholderView.swift              # one view, four uses (Tree/Sources/Metrics/About)
└── Resources/
    └── Assets.xcassets/

CatalogueOfLifeTests/
├── Fixtures/
│   ├── dataset_3LXR.json
│   ├── dataset_list.json
│   ├── name_search_felis.json
│   └── taxon_info_felis_catus.json
├── Helpers/
│   ├── FixtureLoader.swift
│   └── StubAPIClient.swift
├── DatasetDecodingTests.swift
├── NameSearchDecodingTests.swift
├── TaxonInfoDecodingTests.swift
├── SynonymyGroupingTests.swift
├── AppStateTests.swift
└── SearchViewModelTests.swift
```

**Constants used throughout (define in `Endpoints.swift`):**
- `kBaseURL = URL(string: "https://api.checklistbank.org")!`
- `kExtendedReleaseKey = 9837` — placeholder; real numeric key for 3LXR resolved at runtime via the dataset alias endpoint. (See Task 6 for the resolution path.)
- `kBaseReleaseKey` and `kExtendedReleaseKey` are looked up once on launch by alias (`3LR`, `3LXR`) and cached in `AppState`.

> **Note on dataset keys:** the spec uses CoL aliases `3LR` and `3LXR`. ChecklistBank's data API actually keys datasets by integer (e.g. `9837`). `/dataset/{aliasOrKey}` accepts both forms, so we always request by alias when known and store the resolved numeric `key` in `AppState`. The "is GBIF available?" rule checks `selectedDataset.alias ∈ {"3LR","3LXR"}` — not the numeric key.

---

## Task 1: Bootstrap repo with XcodeGen project

**Files:**
- Create: `project.yml`
- Create: `CatalogueOfLife/App/CatalogueOfLifeApp.swift`
- Create: `CatalogueOfLife/Resources/Assets.xcassets/Contents.json`
- Create: `CatalogueOfLife/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Create: `CatalogueOfLife/Info.plist` (empty placeholder — XcodeGen synthesizes)
- Create: `CatalogueOfLifeTests/PlaceholderTest.swift`

- [ ] **Step 1.1: Install XcodeGen if missing**

Run:
```bash
which xcodegen || brew install xcodegen
xcodegen --version
```

Expected: prints a version like `2.x`. XcodeGen is a build-tool dep only — not shipped in the app.

- [ ] **Step 1.2: Write `project.yml`**

```yaml
name: CatalogueOfLife
options:
  bundleIdPrefix: org.catalogueoflife
  deploymentTarget:
    iOS: "18.0"
  developmentLanguage: en
  groupSortPosition: top
  generateEmptyDirectories: true
settings:
  base:
    SWIFT_VERSION: "6.0"
    SWIFT_STRICT_CONCURRENCY: complete
    ENABLE_USER_SCRIPT_SANDBOXING: YES
    MARKETING_VERSION: "0.1.0"
    CURRENT_PROJECT_VERSION: "1"
targets:
  CatalogueOfLife:
    type: application
    platform: iOS
    sources:
      - path: CatalogueOfLife
    resources:
      - path: CatalogueOfLife/Resources
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: org.catalogueoflife.mobile
        INFOPLIST_FILE: CatalogueOfLife/Info.plist
        TARGETED_DEVICE_FAMILY: "1"        # iPhone only
        SUPPORTED_PLATFORMS: "iphoneos iphonesimulator"
        SUPPORTS_MACCATALYST: NO
        SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD: NO
        ENABLE_PREVIEWS: YES
  CatalogueOfLifeTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - path: CatalogueOfLifeTests
    dependencies:
      - target: CatalogueOfLife
    settings:
      base:
        TEST_HOST: "$(BUILT_PRODUCTS_DIR)/CatalogueOfLife.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/CatalogueOfLife"
        BUNDLE_LOADER: "$(TEST_HOST)"
schemes:
  CatalogueOfLife:
    build:
      targets:
        CatalogueOfLife: all
        CatalogueOfLifeTests: [test]
    test:
      targets:
        - CatalogueOfLifeTests
```

- [ ] **Step 1.3: Write `CatalogueOfLife/Info.plist`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDisplayName</key>
  <string>Catalogue of Life</string>
  <key>UILaunchScreen</key>
  <dict/>
  <key>UIRequiresFullScreen</key>
  <false/>
  <key>UISupportedInterfaceOrientations</key>
  <array>
    <string>UIInterfaceOrientationPortrait</string>
    <string>UIInterfaceOrientationLandscapeLeft</string>
    <string>UIInterfaceOrientationLandscapeRight</string>
  </array>
</dict>
</plist>
```

- [ ] **Step 1.4: Write minimal `CatalogueOfLifeApp.swift`**

```swift
import SwiftUI

@main
struct CatalogueOfLifeApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Catalogue of Life")
                .padding()
        }
    }
}
```

- [ ] **Step 1.5: Write empty asset catalog**

`CatalogueOfLife/Resources/Assets.xcassets/Contents.json`:
```json
{ "info": { "author": "xcode", "version": 1 } }
```

`CatalogueOfLife/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`:
```json
{
  "images": [
    { "idiom": "universal", "platform": "ios", "size": "1024x1024" }
  ],
  "info": { "author": "xcode", "version": 1 }
}
```

- [ ] **Step 1.6: Write placeholder test**

`CatalogueOfLifeTests/PlaceholderTest.swift`:
```swift
import Testing

@Test func smoke() {
    #expect(1 + 1 == 2)
}
```

- [ ] **Step 1.7: Generate and build**

Run:
```bash
xcodegen generate
xcodebuild -scheme CatalogueOfLife -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' build -quiet
```

Expected: succeeds with no errors. `CatalogueOfLife.xcodeproj` exists.

- [ ] **Step 1.8: Run test target**

Run:
```bash
xcodebuild -scheme CatalogueOfLife -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' test -quiet
```

Expected: 1 test passes (`smoke`).

- [ ] **Step 1.9: Commit**

Add `.xcodeproj` to .gitignore (we regenerate it from `project.yml`). Update `.gitignore`:

```bash
echo "" >> .gitignore
echo "# XcodeGen output" >> .gitignore
echo "*.xcodeproj/" >> .gitignore
```

```bash
git add .gitignore project.yml CatalogueOfLife CatalogueOfLifeTests
git commit -m "Bootstrap iOS app with XcodeGen + placeholder test"
```

---

## Task 2: CI workflow

**Files:**
- Create: `.github/workflows/ci.yml`

- [ ] **Step 2.1: Write workflow**

```yaml
name: CI
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  test:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4

      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_16.app

      - name: Install XcodeGen
        run: brew install xcodegen

      - name: Generate project
        run: xcodegen generate

      - name: Cache DerivedData
        uses: actions/cache@v4
        with:
          path: ~/Library/Developer/Xcode/DerivedData
          key: ${{ runner.os }}-deriveddata-${{ hashFiles('project.yml', 'CatalogueOfLife/**/*.swift', 'CatalogueOfLifeTests/**/*.swift') }}
          restore-keys: |
            ${{ runner.os }}-deriveddata-

      - name: Build & test
        run: |
          set -o pipefail
          xcodebuild \
            -scheme CatalogueOfLife \
            -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
            -enableCodeCoverage YES \
            test | xcbeautify --renderer github-actions || (echo "If xcbeautify is missing, falling back to raw output"; xcodebuild -scheme CatalogueOfLife -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' test)
        env:
          NSUnbufferedIO: YES
```

- [ ] **Step 2.2: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "Add GitHub Actions CI for iOS 18 simulator"
```

- [ ] **Step 2.3: Push and verify CI is green**

```bash
git push
```

Open the Actions tab on https://github.com/mdoering/col-mobile and confirm the run is green. If `xcbeautify` is missing on `macos-15`, the fallback inside the same step prints raw output — still passes.

---

## Task 3: APIError + HTTPSession + Endpoints scaffolding

**Files:**
- Create: `CatalogueOfLife/Networking/APIError.swift`
- Create: `CatalogueOfLife/Networking/HTTPSession.swift`
- Create: `CatalogueOfLife/Networking/Endpoints.swift`

- [ ] **Step 3.1: Write `APIError.swift`**

```swift
import Foundation

enum APIError: Error, Equatable {
    case network(URLError)
    case server(status: Int)
    case decoding(String)        // String, not DecodingError, so Equatable holds
    case notFound

    static func == (lhs: APIError, rhs: APIError) -> Bool {
        switch (lhs, rhs) {
        case (.notFound, .notFound): true
        case let (.server(a), .server(b)): a == b
        case let (.decoding(a), .decoding(b)): a == b
        case let (.network(a), .network(b)): a.code == b.code
        default: false
        }
    }
}
```

- [ ] **Step 3.2: Write `HTTPSession.swift`**

```swift
import Foundation

enum HTTPSession {
    static let shared: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.urlCache = URLCache(
            memoryCapacity: 8 * 1024 * 1024,     // 8 MB
            diskCapacity: 50 * 1024 * 1024,      // 50 MB
            directory: nil
        )
        cfg.requestCachePolicy = .useProtocolCachePolicy
        cfg.httpAdditionalHeaders = ["Accept": "application/json"]
        cfg.timeoutIntervalForRequest = 20
        return URLSession(configuration: cfg)
    }()
}
```

- [ ] **Step 3.3: Write `Endpoints.swift`**

```swift
import Foundation

enum Endpoints {
    static let baseURL = URL(string: "https://api.checklistbank.org")!

    static func dataset(_ keyOrAlias: String) -> URL {
        baseURL.appending(path: "dataset").appending(path: keyOrAlias)
    }

    static func datasetList(limit: Int = 100, offset: Int = 0) -> URL {
        var c = URLComponents(url: baseURL.appending(path: "dataset"), resolvingAgainstBaseURL: false)!
        c.queryItems = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset)),
            URLQueryItem(name: "origin", value: "released")
        ]
        return c.url!
    }

    static func nameSearch(datasetKey: Int, q: String, limit: Int = 25) -> URL {
        var c = URLComponents(
            url: baseURL.appending(path: "dataset/\(datasetKey)/nameusage/search"),
            resolvingAgainstBaseURL: false
        )!
        c.queryItems = [
            URLQueryItem(name: "q", value: q),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        return c.url!
    }

    static func taxonInfo(datasetKey: Int, taxonId: String) -> URL {
        baseURL.appending(path: "dataset/\(datasetKey)/taxon/\(taxonId)/info")
    }
}
```

- [ ] **Step 3.4: Build to confirm no errors**

Run:
```bash
xcodegen generate
xcodebuild -scheme CatalogueOfLife -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' build -quiet
```

Expected: success.

- [ ] **Step 3.5: Commit**

```bash
git add CatalogueOfLife/Networking
git commit -m "Add APIError, HTTPSession (50MB URLCache), Endpoints"
```

---

## Task 4: APIClient protocol and shared decoding helpers

**Files:**
- Create: `CatalogueOfLife/Networking/APIClient.swift`
- Create: `CatalogueOfLife/Networking/APIClientLive.swift`
- Create: `CatalogueOfLife/Models/DTOs/PagedDTO.swift`

These define the actor + protocol but the only method implemented in this task is `getJSON<T:Decodable>(_:as:)` — endpoint-specific methods land in subsequent tasks.

- [ ] **Step 4.1: Write `PagedDTO.swift`**

```swift
import Foundation

struct PagedDTO<T: Decodable & Sendable>: Decodable, Sendable {
    let result: [T]
    let total: Int?
    let offset: Int?
    let limit: Int?
}
```

- [ ] **Step 4.2: Write `APIClient.swift`**

```swift
import Foundation

protocol APIClient: Sendable {
    func getDataset(_ keyOrAlias: String) async throws -> DatasetRef
    func listReleases() async throws -> [DatasetRef]
    func searchNames(datasetKey: Int, q: String) async throws -> [SearchHit]
    func getTaxonInfo(datasetKey: Int, taxonId: String) async throws -> TaxonInfo
}
```

Note: the four domain types (`DatasetRef`, `SearchHit`, `TaxonInfo`, etc.) are declared in subsequent tasks. This file will not compile until Task 5 lands the first one. We add the protocol body now so the live impl can stub the methods.

- [ ] **Step 4.3: Write `APIClientLive.swift`**

```swift
import Foundation

actor APIClientLive: APIClient {
    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = HTTPSession.shared) {
        self.session = session
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        self.decoder = d
    }

    func getJSON<T: Decodable>(_ url: URL, as type: T.Type) async throws -> T {
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
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw APIError.decoding(String(describing: error))
            }
        case 404:
            throw APIError.notFound
        default:
            throw APIError.server(status: http.statusCode)
        }
    }

    // Real method implementations land in Tasks 5–8.
    func getDataset(_ keyOrAlias: String) async throws -> DatasetRef { fatalError("Task 5") }
    func listReleases() async throws -> [DatasetRef] { fatalError("Task 6") }
    func searchNames(datasetKey: Int, q: String) async throws -> [SearchHit] { fatalError("Task 7") }
    func getTaxonInfo(datasetKey: Int, taxonId: String) async throws -> TaxonInfo { fatalError("Task 9") }
}
```

> Build will fail until Task 5 lands `DatasetRef` etc. That's expected — we ship the protocol + the generic `getJSON` first, then fill in each endpoint method as its types arrive. Don't commit until the file compiles. Carry these files forward into Task 5 in the same commit.

- [ ] **Step 4.4: Defer commit**

Do not commit yet; the protocol references types that don't exist. We commit together with Task 5.

---

## Task 5: Dataset endpoint — DTO, domain type, mapper, test

**Files:**
- Create: `CatalogueOfLife/Models/DTOs/DatasetDTO.swift`
- Create: `CatalogueOfLife/Models/Domain/DatasetRef.swift`
- Create: `CatalogueOfLifeTests/Fixtures/dataset_3LXR.json`
- Create: `CatalogueOfLifeTests/Helpers/FixtureLoader.swift`
- Create: `CatalogueOfLifeTests/DatasetDecodingTests.swift`
- Modify: `CatalogueOfLife/Networking/APIClientLive.swift` (implement `getDataset`)

- [ ] **Step 5.1: Capture a real `/dataset/3LXR` response into the fixture**

Run:
```bash
curl -s 'https://api.checklistbank.org/dataset/3LXR' | python3 -m json.tool > CatalogueOfLifeTests/Fixtures/dataset_3LXR.json
head -40 CatalogueOfLifeTests/Fixtures/dataset_3LXR.json
```

Expected: pretty-printed JSON beginning with `{ "key": <int>, ... "alias": "3LXR", ... "origin": "released", "type": "nomenclatural" or similar }`. Review the fields present — we use a permissive DTO (only what we read).

- [ ] **Step 5.2: Write `DatasetDTO.swift`**

```swift
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
```

- [ ] **Step 5.3: Write `DatasetRef.swift` domain type + mapper**

```swift
import Foundation

struct DatasetRef: Equatable, Hashable, Identifiable, Sendable {
    let key: Int
    let alias: String?           // e.g. "3LXR", "3LR", or nil for an annual
    let title: String
    let version: String?
    let issued: String?
    let citation: String?

    var id: Int { key }

    /// True if this dataset is one of the two releases that GBIF's COL checklist tracks.
    var supportsGBIF: Bool {
        alias == "3LXR" || alias == "3LR"
    }
}

extension DatasetRef {
    init(dto: DatasetDTO) {
        self.init(
            key: dto.key,
            alias: dto.alias,
            title: dto.title,
            version: dto.version,
            issued: dto.issued,
            citation: dto.citation
        )
    }
}
```

- [ ] **Step 5.4: Write `FixtureLoader.swift`**

```swift
import Foundation

enum FixtureLoader {
    static func data(_ name: String) throws -> Data {
        let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")
            ?? Bundle(for: BundleToken.self).url(forResource: name, withExtension: "json", subdirectory: "Fixtures")
        guard let url else {
            throw NSError(domain: "FixtureLoader", code: 1, userInfo: [NSLocalizedDescriptionKey: "Fixture \(name).json not found"])
        }
        return try Data(contentsOf: url)
    }

    private final class BundleToken {}
}
```

> If `Bundle.module` is not available (which happens in `bundle.unit-test` targets that aren't SwiftPM modules), the `Bundle(for:)` fallback works. We'll also wire the fixtures into the test target's resources in Step 5.6.

- [ ] **Step 5.5: Write `DatasetDecodingTests.swift`**

```swift
import Testing
import Foundation
@testable import CatalogueOfLife

@Suite("Dataset decoding")
struct DatasetDecodingTests {

    @Test("Decodes /dataset/3LXR fixture into DatasetRef")
    func decodes3LXR() throws {
        let data = try FixtureLoader.data("dataset_3LXR")
        let dto = try JSONDecoder().decode(DatasetDTO.self, from: data)
        let ref = DatasetRef(dto: dto)
        #expect(ref.alias == "3LXR")
        #expect(ref.title.localizedCaseInsensitiveContains("Catalogue of Life"))
        #expect(ref.supportsGBIF == true)
    }
}
```

- [ ] **Step 5.6: Add `Fixtures/` to the test target resources**

Edit `project.yml`'s `CatalogueOfLifeTests` target so the fixture directory is bundled:

```yaml
  CatalogueOfLifeTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - path: CatalogueOfLifeTests
    resources:
      - path: CatalogueOfLifeTests/Fixtures
    dependencies:
      - target: CatalogueOfLife
    settings:
      base:
        TEST_HOST: "$(BUILT_PRODUCTS_DIR)/CatalogueOfLife.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/CatalogueOfLife"
        BUNDLE_LOADER: "$(TEST_HOST)"
```

(Replace the existing `CatalogueOfLifeTests` block.)

- [ ] **Step 5.7: Implement `getDataset` in `APIClientLive`**

Replace the `getDataset` stub:

```swift
func getDataset(_ keyOrAlias: String) async throws -> DatasetRef {
    let dto = try await getJSON(Endpoints.dataset(keyOrAlias), as: DatasetDTO.self)
    return DatasetRef(dto: dto)
}
```

- [ ] **Step 5.8: Run the dataset test**

```bash
xcodegen generate
xcodebuild -scheme CatalogueOfLife -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' test -only-testing:CatalogueOfLifeTests/DatasetDecodingTests -quiet
```

Expected: 1 test passes.

- [ ] **Step 5.9: Commit**

```bash
git add CatalogueOfLife CatalogueOfLifeTests project.yml
git commit -m "Add APIClient protocol + getDataset endpoint with decoding test"
```

---

## Task 6: List releases endpoint

> **Revised after Task 5 inspected the live API.** Original draft assumed `DatasetDTO.alias == "3LXR"/"3LR"` and a single-`origin` filter. Reality: `alias` is a drifting human label (`"COL26.4 XR"`); `3LXR`/`3LR` are URL aliases that resolve to numeric keys via `/dataset/3LXR` and `/dataset/3LR`. The API distinguishes `origin: "release"` (base) from `origin: "xrelease"` (extended), and accepts repeated `origin` query params so a single call returns both. Sorting depends on the resolved keys, so it lives in Task 7 (AppState) — Task 6 only fetches.

**Files:**
- Create: `CatalogueOfLifeTests/Fixtures/dataset_list.json`
- Modify: `CatalogueOfLife/Networking/Endpoints.swift` — broaden `datasetList` to accept multiple origins
- Modify: `CatalogueOfLife/Networking/APIClientLive.swift` (implement `listReleases`)
- Create: `CatalogueOfLifeTests/Helpers/StubAPIClient.swift`
- Modify: `CatalogueOfLifeTests/DatasetDecodingTests.swift` (add a decoding test for the list)

- [ ] **Step 6.1: Capture the release list fixture**

```bash
curl -s 'https://api.checklistbank.org/dataset?limit=200&origin=release&origin=xrelease' | python3 -m json.tool > CatalogueOfLifeTests/Fixtures/dataset_list.json
python3 -c "import json; d=json.load(open('CatalogueOfLifeTests/Fixtures/dataset_list.json')); print('total:', d['total'], 'origins:', sorted({r['origin'] for r in d['result']}))"
```

Expected: ~40+ entries with origins `{'release','xrelease'}`. The fixture is a snapshot; tests must not depend on the exact count or on specific aliases.

- [ ] **Step 6.2: Broaden `Endpoints.datasetList` to accept multiple origins**

Replace the existing function in `Endpoints.swift`:

```swift
static func datasetList(limit: Int = 200, offset: Int = 0, origins: [String] = ["release", "xrelease"]) -> URL {
    var c = URLComponents(url: baseURL.appending(path: "dataset"), resolvingAgainstBaseURL: false)!
    var items: [URLQueryItem] = [
        URLQueryItem(name: "limit", value: String(limit)),
        URLQueryItem(name: "offset", value: String(offset)),
    ]
    items.append(contentsOf: origins.map { URLQueryItem(name: "origin", value: $0) })
    c.queryItems = items
    return c.url!
}
```

The API accepts repeated `origin` query params (verified: `?origin=release&origin=xrelease` returns 200 with both kinds in `result`).

- [ ] **Step 6.3: Write `StubAPIClient.swift`** (used by ViewModel tests starting in Task 10)

```swift
import Foundation
@testable import CatalogueOfLife

final class StubAPIClient: APIClient, @unchecked Sendable {
    var releases: [DatasetRef] = []
    var datasetByKey: [String: DatasetRef] = [:]
    var searchResults: [String: [SearchHit]] = [:]
    var taxonInfo: [String: TaxonInfo] = [:]
    var error: APIError?

    func getDataset(_ keyOrAlias: String) async throws -> DatasetRef {
        if let error { throw error }
        guard let r = datasetByKey[keyOrAlias] else { throw APIError.notFound }
        return r
    }

    func listReleases() async throws -> [DatasetRef] {
        if let error { throw error }
        return releases
    }

    func searchNames(datasetKey: Int, q: String) async throws -> [SearchHit] {
        if let error { throw error }
        return searchResults[q] ?? []
    }

    func getTaxonInfo(datasetKey: Int, taxonId: String) async throws -> TaxonInfo {
        if let error { throw error }
        guard let info = taxonInfo[taxonId] else { throw APIError.notFound }
        return info
    }
}
```

- [ ] **Step 6.4: Add a decoding test to `DatasetDecodingTests.swift`**

```swift
@Test("Decodes /dataset list and surfaces both origins")
func decodesReleaseList() throws {
    let data = try FixtureLoader.data("dataset_list")
    let paged = try JSONDecoder().decode(PagedDTO<DatasetDTO>.self, from: data)
    let refs = paged.result.map(DatasetRef.init(dto:))
    #expect(!refs.isEmpty)
    let origins = Set(refs.compactMap(\.origin))
    #expect(origins.contains("release"))
    #expect(origins.contains("xrelease"))
}
```

(The test asserts on shape, not on specific keys or aliases — the fixture is a moving target.)

- [ ] **Step 6.5: Implement `listReleases` in `APIClientLive`**

Replace the stub:

```swift
func listReleases() async throws -> [DatasetRef] {
    let paged = try await getJSON(Endpoints.datasetList(), as: PagedDTO<DatasetDTO>.self)
    return paged.result.map(DatasetRef.init(dto:))
}
```

No sorting here — Task 7's `AppState` sorts using the resolved 3LXR/3LR numeric keys.

- [ ] **Step 6.6: Add `DatasetRef.sortedForPicker(_:latestExtendedKey:latestBaseKey:)`**

Append to `DatasetRef.swift`:

```swift
extension DatasetRef {
    /// Sort: latest extended (matches `latestExtendedKey`) first, latest base (matches `latestBaseKey`) second,
    /// remaining releases by `issued` descending. Pass `nil` for unknown resolved keys (they then rank as "other").
    static func sortedForPicker(_ refs: [DatasetRef],
                                 latestExtendedKey: Int?,
                                 latestBaseKey: Int?) -> [DatasetRef] {
        refs.sorted { a, b in
            func rank(_ r: DatasetRef) -> Int {
                if let k = latestExtendedKey, r.key == k { return 0 }
                if let k = latestBaseKey, r.key == k { return 1 }
                return 2
            }
            let ra = rank(a), rb = rank(b)
            if ra != rb { return ra < rb }
            return (a.issued ?? "") > (b.issued ?? "")
        }
    }
}
```

- [ ] **Step 6.7: Add a sort test**

Add to `DatasetDecodingTests.swift`:

```swift
@Test("sortedForPicker puts latest extended first, latest base second, others by issued desc")
func sortPlacesLatestReleasesFirst() {
    let refs = [
        DatasetRef(key: 11, alias: "COL24",    title: "C", version: nil, issued: "2024-01-01", origin: "release",  citation: nil),
        DatasetRef(key: 12, alias: "COL26.4 XR", title: "C", version: nil, issued: "2026-04-01", origin: "xrelease", citation: nil),
        DatasetRef(key: 13, alias: "COL26.4",  title: "C", version: nil, issued: "2026-04-15", origin: "release",  citation: nil),
        DatasetRef(key: 14, alias: "COL25",    title: "C", version: nil, issued: "2025-01-01", origin: "release",  citation: nil),
    ]
    let sorted = DatasetRef.sortedForPicker(refs, latestExtendedKey: 12, latestBaseKey: 13)
    #expect(sorted.map(\.key) == [12, 13, 14, 11])
}
```

- [ ] **Step 6.8: Run tests**

```bash
xcodegen generate
xcodebuild -scheme CatalogueOfLife -destination 'platform=iOS Simulator,name=iPhone 16e,OS=latest' test -only-testing:CatalogueOfLifeTests/DatasetDecodingTests -quiet
```

Expected: 3 tests pass (the original `decodes3LXR`, plus `decodesReleaseList` and `sortPlacesLatestReleasesFirst`).

- [ ] **Step 6.9: Commit**

```bash
git add CatalogueOfLife CatalogueOfLifeTests
git commit -m "Add listReleases endpoint with sortedForPicker(latestExtendedKey:latestBaseKey:)"
```

---

## Task 7: AppState — releases + 3LXR/3LR resolution + GBIF rule

> **Revised after Task 5 inspected the live API.** GBIF availability cannot be derived from `DatasetRef` alone — `3LXR` and `3LR` are URL aliases, not field values. Resolve them at launch by calling `/dataset/3LXR` and `/dataset/3LR`; cache the numeric keys; compare `selectedDatasetKey` against those.

**Files:**
- Create: `CatalogueOfLife/App/AppState.swift`
- Create: `CatalogueOfLifeTests/AppStateTests.swift`

`AppState` holds:
- `availableReleases: [DatasetRef]` — sorted with latest extended/base at the top
- `latestExtendedKey: Int?` and `latestBaseKey: Int?` — resolved from `/dataset/3LXR` and `/dataset/3LR`
- `selectedDatasetKey: Int` — persisted to UserDefaults
- `preferredVernacularLang: String?` — persisted to UserDefaults (ISO 639-3)
- derived `gbifAvailable: Bool`
- derived `selectedDataset: DatasetRef?`

- [ ] **Step 7.1: Write `AppState.swift`**

```swift
import Foundation
import Observation

@MainActor
@Observable
final class AppState {
    private let client: APIClient
    private let defaults: UserDefaults

    var availableReleases: [DatasetRef] = []
    private(set) var latestExtendedKey: Int?
    private(set) var latestBaseKey: Int?
    private(set) var loadReleasesError: APIError?

    /// Numeric key of the user's selected dataset. Persists across launches.
    var selectedDatasetKey: Int {
        didSet { defaults.set(selectedDatasetKey, forKey: Keys.selectedDatasetKey) }
    }

    /// ISO 639-3 code, or nil for "none".
    var preferredVernacularLang: String? {
        didSet {
            if let v = preferredVernacularLang {
                defaults.set(v, forKey: Keys.preferredVernacularLang)
            } else {
                defaults.removeObject(forKey: Keys.preferredVernacularLang)
            }
        }
    }

    var selectedDataset: DatasetRef? {
        availableReleases.first { $0.key == selectedDatasetKey }
    }

    /// True only when the user has selected the latest extended (3LXR) or base (3LR) release.
    /// GBIF's COL checklist tracks identifiers from those two specific releases.
    var gbifAvailable: Bool {
        let k = selectedDatasetKey
        return (latestExtendedKey.map { $0 == k } ?? false)
            || (latestBaseKey.map { $0 == k } ?? false)
    }

    init(client: APIClient, defaults: UserDefaults = .standard) {
        self.client = client
        self.defaults = defaults
        self.selectedDatasetKey = defaults.integer(forKey: Keys.selectedDatasetKey)
        self.preferredVernacularLang = defaults.string(forKey: Keys.preferredVernacularLang)
    }

    /// Load the release list and resolve the current 3LXR / 3LR numeric keys in parallel.
    /// Sorts the list and applies a default selection if none persists.
    func loadReleases() async {
        async let extendedTask: DatasetRef? = try? await client.getDataset("3LXR")
        async let baseTask: DatasetRef? = try? await client.getDataset("3LR")
        do {
            let raw = try await client.listReleases()
            let extended = await extendedTask
            let base = await baseTask

            self.latestExtendedKey = extended?.key
            self.latestBaseKey = base?.key

            // Merge the two resolved refs into the list so they appear even if not in /dataset
            // (they almost always will be, but if not, we want them present so the picker shows them).
            var merged = raw
            for ref in [extended, base].compactMap({ $0 }) where !merged.contains(where: { $0.key == ref.key }) {
                merged.append(ref)
            }

            self.availableReleases = DatasetRef.sortedForPicker(
                merged,
                latestExtendedKey: extended?.key,
                latestBaseKey: base?.key
            )

            // On first launch (or if stored selection has disappeared), default to the latest extended release.
            if !availableReleases.contains(where: { $0.key == selectedDatasetKey }) {
                if let extendedKey = extended?.key {
                    self.selectedDatasetKey = extendedKey
                } else if let baseKey = base?.key {
                    self.selectedDatasetKey = baseKey
                } else if let first = availableReleases.first {
                    self.selectedDatasetKey = first.key
                }
            }
            self.loadReleasesError = nil
        } catch let err as APIError {
            self.loadReleasesError = err
        } catch {
            self.loadReleasesError = .server(status: -1)
        }
    }

    private enum Keys {
        static let selectedDatasetKey = "selectedDatasetKey"
        static let preferredVernacularLang = "preferredVernacularLang"
    }
}
```

- [ ] **Step 7.2: Extend `StubAPIClient`** to support the parallel `getDataset("3LXR"/"3LR")` calls

Already supported via `datasetByKey` (introduced in Task 6 Step 6.3). Tests set entries for both `"3LXR"` and `"3LR"` keys.

- [ ] **Step 7.3: Write tests**

```swift
import Testing
import Foundation
@testable import CatalogueOfLife

@Suite("AppState")
@MainActor
struct AppStateTests {
    private func freshDefaults() -> UserDefaults {
        let suite = "AppStateTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    private func sampleStub() -> StubAPIClient {
        let stub = StubAPIClient()
        let extended = DatasetRef(key: 100, alias: "COL26.4 XR", title: "Catalogue of Life",
                                   version: "2026-04-15", issued: "2026-04-15", origin: "xrelease", citation: nil)
        let base = DatasetRef(key: 200, alias: "COL26.4", title: "Catalogue of Life",
                               version: "2026-04-15", issued: "2026-04-15", origin: "release", citation: nil)
        let annual = DatasetRef(key: 300, alias: "COL24", title: "Catalogue of Life",
                                 version: "2024-01-01", issued: "2024-01-01", origin: "release", citation: nil)
        stub.datasetByKey["3LXR"] = extended
        stub.datasetByKey["3LR"] = base
        stub.releases = [annual, base, extended]
        return stub
    }

    @Test("Defaults to latest extended release when no prior selection")
    func defaultsToLatestExtended() async {
        let defaults = freshDefaults()
        let stub = sampleStub()
        let state = AppState(client: stub, defaults: defaults)
        await state.loadReleases()
        #expect(state.selectedDatasetKey == 100)
        #expect(state.gbifAvailable == true)
        #expect(state.availableReleases.map(\.key) == [100, 200, 300])
    }

    @Test("Selecting the latest base release also enables gbifAvailable")
    func baseReleaseEnablesGBIF() async {
        let defaults = freshDefaults()
        let stub = sampleStub()
        let state = AppState(client: stub, defaults: defaults)
        await state.loadReleases()
        state.selectedDatasetKey = 200
        #expect(state.gbifAvailable == true)
    }

    @Test("Selecting an annual release disables gbifAvailable")
    func annualDisablesGBIF() async {
        let defaults = freshDefaults()
        let stub = sampleStub()
        let state = AppState(client: stub, defaults: defaults)
        await state.loadReleases()
        state.selectedDatasetKey = 300
        #expect(state.gbifAvailable == false)
    }

    @Test("Honors stored selection if still available")
    func honorsStoredSelection() async {
        let defaults = freshDefaults()
        defaults.set(300, forKey: "selectedDatasetKey")
        let stub = sampleStub()
        let state = AppState(client: stub, defaults: defaults)
        await state.loadReleases()
        #expect(state.selectedDatasetKey == 300)
        #expect(state.gbifAvailable == false)
    }

    @Test("Resolves alias keys even when /dataset list omits them")
    func mergesResolvedAliases() async {
        let defaults = freshDefaults()
        let stub = sampleStub()
        // Simulate the unusual case where /dataset doesn't return the extended release in the page.
        stub.releases = stub.releases.filter { $0.key != 100 }
        let state = AppState(client: stub, defaults: defaults)
        await state.loadReleases()
        #expect(state.availableReleases.contains(where: { $0.key == 100 }))
        #expect(state.selectedDatasetKey == 100)
    }

    @Test("Vernacular preference round-trips through UserDefaults")
    func vernacularPersists() {
        let defaults = freshDefaults()
        let state = AppState(client: StubAPIClient(), defaults: defaults)
        state.preferredVernacularLang = "deu"
        #expect(defaults.string(forKey: "preferredVernacularLang") == "deu")
        state.preferredVernacularLang = nil
        #expect(defaults.string(forKey: "preferredVernacularLang") == nil)
    }
}
```

- [ ] **Step 7.4: Run AppState tests**

```bash
xcodegen generate
xcodebuild -scheme CatalogueOfLife -destination 'platform=iOS Simulator,name=iPhone 16e,OS=latest' test -only-testing:CatalogueOfLifeTests/AppStateTests -quiet
```

Expected: 6 tests pass.

- [ ] **Step 7.5: Commit**

```bash
git add CatalogueOfLife/App/AppState.swift CatalogueOfLifeTests/AppStateTests.swift
git commit -m "Add AppState with /dataset/3LXR + 3LR resolution and key-based gbifAvailable"
```

---

## Task 8: Root TabView shell + global release picker

**Files:**
- Create: `CatalogueOfLife/App/RootTabView.swift`
- Create: `CatalogueOfLife/App/ReleasePicker.swift`
- Create: `CatalogueOfLife/Features/Placeholders/TabPlaceholderView.swift`
- Modify: `CatalogueOfLife/App/CatalogueOfLifeApp.swift`

- [ ] **Step 8.1: Write `TabPlaceholderView.swift`**

```swift
import SwiftUI

struct TabPlaceholderView: View {
    let title: String
    let symbol: String

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.title2)
                Text("Coming soon")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle(title)
            .toolbar { ToolbarItem(placement: .principal) { ReleasePicker() } }
        }
    }
}
```

- [ ] **Step 8.2: Write `ReleasePicker.swift`**

```swift
import SwiftUI

struct ReleasePicker: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        Menu {
            Picker("Release", selection: $state.selectedDatasetKey) {
                ForEach(state.availableReleases) { ref in
                    Text(label(for: ref)).tag(ref.key)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(state.selectedDataset.map(label(for:)) ?? "Loading…")
                    .font(.subheadline)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(.thinMaterial, in: Capsule())
        }
        .accessibilityLabel("Selected release")
    }

    private func label(for ref: DatasetRef) -> String {
        if let alias = ref.alias { return alias }
        if let issued = ref.issued?.prefix(4) { return "Annual \(issued)" }
        return ref.title
    }
}
```

- [ ] **Step 8.3: Write `RootTabView.swift`**

```swift
import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            TabPlaceholderView(title: "Tree", symbol: "tree")
                .tabItem { Label("Tree", systemImage: "tree") }
            SearchView()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
            TabPlaceholderView(title: "Sources", symbol: "books.vertical")
                .tabItem { Label("Sources", systemImage: "books.vertical") }
            TabPlaceholderView(title: "Metrics", symbol: "chart.pie")
                .tabItem { Label("Metrics", systemImage: "chart.pie") }
            TabPlaceholderView(title: "About", symbol: "info.circle")
                .tabItem { Label("About", systemImage: "info.circle") }
        }
    }
}
```

> `SearchView` lands in Task 11. To keep this task compiling, temporarily replace `SearchView()` with `TabPlaceholderView(title: "Search", symbol: "magnifyingglass")`. We swap it back in Task 11.

- [ ] **Step 8.4: Update `CatalogueOfLifeApp.swift`**

```swift
import SwiftUI

@main
struct CatalogueOfLifeApp: App {
    @State private var state: AppState = AppState(client: APIClientLive())

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(state)
                .task { await state.loadReleases() }
        }
    }
}
```

- [ ] **Step 8.5: Build and run on the simulator**

```bash
xcodegen generate
xcodebuild -scheme CatalogueOfLife -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' build -quiet
```

Then open the simulator manually via Xcode (`open CatalogueOfLife.xcodeproj`, press Cmd-R) and verify:
- Five tabs at the bottom (Tree, Search, Sources, Metrics, About).
- A "Release" capsule chip in the navigation bar at the top of every tab.
- After ~1s the chip's label changes from "Loading…" to "3LXR".
- Tapping the chip shows a Menu listing releases.

This is a manual verification step — no automated UI test. Capture a screenshot if you want.

- [ ] **Step 8.6: Commit**

```bash
git add CatalogueOfLife
git commit -m "Add root TabView shell with global release picker and tab placeholders"
```

---

## Task 9: Name search endpoint — DTO, domain, fixture, test

**Files:**
- Create: `CatalogueOfLife/Models/DTOs/NameUsageSearchHitDTO.swift`
- Create: `CatalogueOfLife/Models/Domain/Rank.swift`
- Create: `CatalogueOfLife/Models/Domain/TaxonStatus.swift`
- Create: `CatalogueOfLife/Models/Domain/SearchHit.swift`
- Create: `CatalogueOfLifeTests/Fixtures/name_search_felis.json`
- Create: `CatalogueOfLifeTests/NameSearchDecodingTests.swift`
- Modify: `CatalogueOfLife/Networking/APIClientLive.swift` (`searchNames`)

- [ ] **Step 9.1: Capture fixture**

```bash
curl -s 'https://api.checklistbank.org/dataset/3LXR/nameusage/search?q=felis&limit=10' \
  | python3 -m json.tool > CatalogueOfLifeTests/Fixtures/name_search_felis.json
head -60 CatalogueOfLifeTests/Fixtures/name_search_felis.json
```

Expected: a paged response. Each `result` item has `usage.id`, `usage.name.scientificName`, `usage.name.authorship`, `usage.name.rank`, `usage.status`, `acceptedId` (when synonym), plus probably a `group` field on the usage. If response key names differ from what's coded below, adjust the DTO `CodingKeys` and update the test accordingly.

- [ ] **Step 9.2: Write `Rank.swift`**

```swift
import Foundation

enum Rank: String, Codable, Sendable, CaseIterable {
    case domain, superkingdom, kingdom, subkingdom, infrakingdom
    case phylum, subphylum, superclass
    case `class` = "class", subclass, infraclass
    case superorder, order, suborder, infraorder
    case superfamily, family, subfamily, tribe, subtribe
    case genus, subgenus, section, subsection, series
    case species, subspecies, variety, form
    case unranked, other

    init(apiValue: String?) {
        guard let v = apiValue?.lowercased() else { self = .other; return }
        self = Rank(rawValue: v) ?? .other
    }
}
```

- [ ] **Step 9.3: Write `TaxonStatus.swift`**

```swift
import Foundation

enum TaxonStatus: String, Codable, Sendable {
    case accepted
    case provisionallyAccepted = "provisionally accepted"
    case synonym
    case ambiguousSynonym = "ambiguous synonym"
    case misapplied
    case bareName = "bare name"
    case unknown

    init(apiValue: String?) {
        guard let v = apiValue?.lowercased() else { self = .unknown; return }
        self = TaxonStatus(rawValue: v) ?? .unknown
    }

    var isSynonym: Bool {
        switch self {
        case .synonym, .ambiguousSynonym, .misapplied: true
        default: false
        }
    }
}
```

- [ ] **Step 9.4: Write `SearchHit.swift`**

```swift
import Foundation

struct SearchHit: Equatable, Identifiable, Sendable {
    let id: String                   // the usage id
    let scientificName: String
    let authorship: String?
    let rank: Rank
    let status: TaxonStatus
    let acceptedId: String?
    let group: String?               // taxgroup code — used in Plan 2

    /// The id we should navigate to when the row is tapped. If this hit is a synonym
    /// and the API provided `acceptedId`, that's the destination; otherwise the hit's own id.
    var navigationTaxonId: String { acceptedId ?? id }
}
```

- [ ] **Step 9.5: Write `NameUsageSearchHitDTO.swift`**

```swift
import Foundation

struct NameUsageSearchHitDTO: Decodable, Sendable {
    let usage: UsageDTO
    let acceptedId: String?

    struct UsageDTO: Decodable, Sendable {
        let id: String
        let status: String?
        let group: String?
        let name: NameDTO
    }

    struct NameDTO: Decodable, Sendable {
        let scientificName: String
        let authorship: String?
        let rank: String?
    }
}

extension SearchHit {
    init(dto: NameUsageSearchHitDTO) {
        self.init(
            id: dto.usage.id,
            scientificName: dto.usage.name.scientificName,
            authorship: dto.usage.name.authorship,
            rank: Rank(apiValue: dto.usage.name.rank),
            status: TaxonStatus(apiValue: dto.usage.status),
            acceptedId: dto.acceptedId,
            group: dto.usage.group
        )
    }
}
```

- [ ] **Step 9.6: Write decoding test**

`CatalogueOfLifeTests/NameSearchDecodingTests.swift`:

```swift
import Testing
import Foundation
@testable import CatalogueOfLife

@Suite("Name search decoding")
struct NameSearchDecodingTests {
    @Test("Decodes felis search fixture")
    func decodesFelis() throws {
        let data = try FixtureLoader.data("name_search_felis")
        let paged = try JSONDecoder().decode(PagedDTO<NameUsageSearchHitDTO>.self, from: data)
        let hits = paged.result.map(SearchHit.init(dto:))
        #expect(!hits.isEmpty)
        #expect(hits.contains { $0.scientificName.localizedCaseInsensitiveContains("Felis") })
    }

    @Test("Synonym hits route to acceptedId when present")
    func synonymRoutesToAccepted() {
        let synonym = SearchHit(
            id: "S1", scientificName: "Felis x", authorship: nil,
            rank: .species, status: .synonym, acceptedId: "ACC1", group: nil
        )
        let accepted = SearchHit(
            id: "ACC2", scientificName: "Felis catus", authorship: nil,
            rank: .species, status: .accepted, acceptedId: nil, group: nil
        )
        #expect(synonym.navigationTaxonId == "ACC1")
        #expect(accepted.navigationTaxonId == "ACC2")
    }
}
```

- [ ] **Step 9.7: Implement `searchNames`**

In `APIClientLive.swift`:

```swift
func searchNames(datasetKey: Int, q: String) async throws -> [SearchHit] {
    let url = Endpoints.nameSearch(datasetKey: datasetKey, q: q)
    let paged = try await getJSON(url, as: PagedDTO<NameUsageSearchHitDTO>.self)
    return paged.result.map(SearchHit.init(dto:))
}
```

- [ ] **Step 9.8: Run tests**

```bash
xcodegen generate
xcodebuild -scheme CatalogueOfLife -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' test -only-testing:CatalogueOfLifeTests/NameSearchDecodingTests -quiet
```

Expected: 2 tests pass.

- [ ] **Step 9.9: Commit**

```bash
git add CatalogueOfLife CatalogueOfLifeTests
git commit -m "Add name search endpoint with rank/status enums and synonym routing"
```

---

## Task 10: SearchViewModel with debounce

**Files:**
- Create: `CatalogueOfLife/Features/Search/SearchViewModel.swift`
- Create: `CatalogueOfLifeTests/SearchViewModelTests.swift`

- [ ] **Step 10.1: Write `SearchViewModel.swift`**

```swift
import Foundation
import Observation

@MainActor
@Observable
final class SearchViewModel {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded([SearchHit])
        case failed(APIError)
    }

    var query: String = "" {
        didSet { scheduleSearch() }
    }

    private(set) var state: LoadState = .idle

    private let client: APIClient
    private let getDatasetKey: @MainActor () -> Int?
    private var debounceTask: Task<Void, Never>?
    private var inFlight: Task<Void, Never>?

    /// Debounce duration in milliseconds. Overridable for tests.
    var debounceMillis: Int = 300

    init(client: APIClient, getDatasetKey: @escaping @MainActor () -> Int?) {
        self.client = client
        self.getDatasetKey = getDatasetKey
    }

    private func scheduleSearch() {
        debounceTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            state = .idle
            inFlight?.cancel()
            return
        }
        let delay = debounceMillis
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000)
            guard !Task.isCancelled, let self else { return }
            await self.run(query: trimmed)
        }
    }

    private func run(query: String) async {
        guard let key = getDatasetKey() else {
            state = .failed(.server(status: -1))
            return
        }
        inFlight?.cancel()
        state = .loading
        inFlight = Task {
            do {
                let hits = try await client.searchNames(datasetKey: key, q: query)
                guard !Task.isCancelled else { return }
                state = .loaded(hits)
            } catch let err as APIError {
                guard !Task.isCancelled else { return }
                state = .failed(err)
            } catch {
                state = .failed(.server(status: -1))
            }
        }
    }
}
```

- [ ] **Step 10.2: Write VM tests**

```swift
import Testing
import Foundation
@testable import CatalogueOfLife

@Suite("SearchViewModel")
@MainActor
struct SearchViewModelTests {

    private func make() -> (SearchViewModel, StubAPIClient) {
        let stub = StubAPIClient()
        let vm = SearchViewModel(client: stub, getDatasetKey: { 9837 })
        vm.debounceMillis = 10  // make tests fast
        return (vm, stub)
    }

    @Test("Empty query stays idle")
    func emptyQueryIdle() async {
        let (vm, _) = make()
        vm.query = "   "
        try? await Task.sleep(nanoseconds: 30_000_000)
        #expect(vm.state == .idle)
    }

    @Test("Loads results after debounce")
    func loadsResults() async {
        let (vm, stub) = make()
        let hit = SearchHit(id: "1", scientificName: "Felis catus", authorship: "L., 1758",
                            rank: .species, status: .accepted, acceptedId: nil, group: nil)
        stub.searchResults["felis"] = [hit]
        vm.query = "felis"
        try? await Task.sleep(nanoseconds: 80_000_000)
        if case let .loaded(hits) = vm.state {
            #expect(hits.first?.id == "1")
        } else {
            Issue.record("Expected .loaded but got \(vm.state)")
        }
    }

    @Test("Rapid typing only fires the last query")
    func debounceDropsIntermediate() async {
        let (vm, stub) = make()
        stub.searchResults["fel"] = []
        stub.searchResults["feli"] = []
        stub.searchResults["felis"] = [
            SearchHit(id: "1", scientificName: "Felis", authorship: nil, rank: .genus,
                      status: .accepted, acceptedId: nil, group: nil)
        ]
        vm.query = "fel"
        vm.query = "feli"
        vm.query = "felis"
        try? await Task.sleep(nanoseconds: 80_000_000)
        if case let .loaded(hits) = vm.state {
            #expect(hits.first?.scientificName == "Felis")
        } else {
            Issue.record("Expected .loaded but got \(vm.state)")
        }
    }

    @Test("API error surfaces as .failed")
    func errorSurfaces() async {
        let (vm, stub) = make()
        stub.error = .server(status: 500)
        vm.query = "felis"
        try? await Task.sleep(nanoseconds: 80_000_000)
        #expect(vm.state == .failed(.server(status: 500)))
    }
}
```

- [ ] **Step 10.3: Run VM tests**

```bash
xcodegen generate
xcodebuild -scheme CatalogueOfLife -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' test -only-testing:CatalogueOfLifeTests/SearchViewModelTests -quiet
```

Expected: 4 tests pass.

- [ ] **Step 10.4: Commit**

```bash
git add CatalogueOfLife/Features/Search CatalogueOfLifeTests/SearchViewModelTests.swift
git commit -m "Add SearchViewModel with debounce + load-state tests"
```

---

## Task 11: SearchView and wire into root TabView

**Files:**
- Create: `CatalogueOfLife/Features/Search/SearchView.swift`
- Modify: `CatalogueOfLife/App/RootTabView.swift` (swap placeholder for real SearchView)

- [ ] **Step 11.1: Write `SearchView.swift`**

```swift
import SwiftUI

struct SearchView: View {
    @Environment(AppState.self) private var appState
    @State private var vm: SearchViewModel?
    @State private var selectedTaxonId: String?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Search")
                .toolbar { ToolbarItem(placement: .principal) { ReleasePicker() } }
                .navigationDestination(item: $selectedTaxonId) { id in
                    TaxonDetailView(taxonId: id)
                }
        }
        .onAppear { ensureVM() }
    }

    private func ensureVM() {
        if vm == nil {
            vm = SearchViewModel(client: APIClientLive()) { [appState] in
                appState.selectedDataset?.key
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let vm {
            @Bindable var vm = vm
            ZStack {
                Color.clear
                switch vm.state {
                case .idle:
                    ContentUnavailableView("Search names",
                        systemImage: "magnifyingglass",
                        description: Text("Type to find taxa in \(appState.selectedDataset?.alias ?? "the selected release")."))
                case .loading:
                    ProgressView()
                case let .loaded(hits):
                    resultsList(hits)
                case let .failed(err):
                    errorView(err) { vm.query = vm.query }
                }
            }
            .searchable(text: $vm.query, prompt: "Scientific or vernacular name")
        } else {
            ProgressView()
        }
    }

    @ViewBuilder
    private func resultsList(_ hits: [SearchHit]) -> some View {
        if hits.isEmpty {
            ContentUnavailableView.search
        } else {
            List(hits) { hit in
                Button {
                    selectedTaxonId = hit.navigationTaxonId
                } label: {
                    SearchRow(hit: hit)
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
        }
    }

    @ViewBuilder
    private func errorView(_ err: APIError, retry: @escaping () -> Void) -> some View {
        VStack(spacing: 8) {
            Text("Couldn't search").font(.headline)
            Text(message(for: err)).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Retry", action: retry).buttonStyle(.bordered)
        }
        .padding()
    }

    private func message(for err: APIError) -> String {
        switch err {
        case .network: "Network unavailable. Check your connection."
        case .server(let s): "Server error (\(s))."
        case .decoding: "We couldn't understand the response."
        case .notFound: "No matches."
        }
    }
}

private struct SearchRow: View {
    let hit: SearchHit

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(hit.scientificName).italic().font(.body)
                if let auth = hit.authorship {
                    Text(auth).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(hit.rank.rawValue.capitalized)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.thinMaterial, in: Capsule())
            }
            if hit.status.isSynonym {
                Text("synonym").font(.caption2).foregroundStyle(.orange)
            }
        }
    }
}
```

- [ ] **Step 11.2: Update `RootTabView.swift`**

Replace the placeholder with the real `SearchView` (it was deferred in Task 8):

```swift
SearchView()
    .tabItem { Label("Search", systemImage: "magnifyingglass") }
```

- [ ] **Step 11.3: Build**

```bash
xcodegen generate
xcodebuild -scheme CatalogueOfLife -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' build -quiet
```

Expected: success. `TaxonDetailView` doesn't exist yet, so the `navigationDestination` line will fail to compile. Add a temporary stub in the same file *above* `SearchView`:

```swift
// Temporary stub — replaced by Task 13. Lets SearchView compile in isolation.
struct TaxonDetailView: View {
    let taxonId: String
    var body: some View {
        Text("Taxon: \(taxonId)").navigationTitle("Taxon")
    }
}
```

We delete this stub when Task 13 lands the real view (its own file).

- [ ] **Step 11.4: Manual verification**

Open Xcode, Cmd-R on iPhone 16 simulator. In the Search tab, type "felis". After ~300 ms a list of results appears with scientific name (italic) + authorship + rank chip. Tap a row → "Taxon: <id>" placeholder shows.

- [ ] **Step 11.5: Commit**

```bash
git add CatalogueOfLife
git commit -m "Add SearchView wired to SearchViewModel with debounced live search"
```

---

## Task 12: Taxon /info endpoint — DTOs, domain types, synonymy grouping, tests

**Files:**
- Create: `CatalogueOfLife/Models/DTOs/TaxonInfoDTO.swift`
- Create: `CatalogueOfLife/Models/DTOs/VernacularNameDTO.swift`
- Create: `CatalogueOfLife/Models/Domain/VernacularName.swift`
- Create: `CatalogueOfLife/Models/Domain/ClassificationItem.swift`
- Create: `CatalogueOfLife/Models/Domain/SynonymyGroup.swift`
- Create: `CatalogueOfLife/Models/Domain/TaxonInfo.swift`
- Create: `CatalogueOfLifeTests/Fixtures/taxon_info_felis_catus.json`
- Create: `CatalogueOfLifeTests/TaxonInfoDecodingTests.swift`
- Create: `CatalogueOfLifeTests/SynonymyGroupingTests.swift`
- Modify: `CatalogueOfLife/Networking/APIClientLive.swift` (`getTaxonInfo`)

- [ ] **Step 12.1: Capture fixture**

```bash
# First, find the taxon id for Felis catus in 3LXR — search for it:
curl -s 'https://api.checklistbank.org/dataset/3LXR/nameusage/search?q=Felis+catus&limit=1' \
  | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['result'][0]['usage']['id'])"
# Use the printed id below:
TAXON_ID=<paste id here>
curl -s "https://api.checklistbank.org/dataset/3LXR/taxon/$TAXON_ID/info" \
  | python3 -m json.tool > CatalogueOfLifeTests/Fixtures/taxon_info_felis_catus.json
head -80 CatalogueOfLifeTests/Fixtures/taxon_info_felis_catus.json
```

Expected: a JSON object with at least `taxon` (id, name, rank, status, group), `classification` (ordered array of parent ranks), `synonyms` (array, each with a `homotypic` boolean or a `type` field), and `vernacularNames`.

> **Schema-drift note:** the field name for grouping synonyms could be `homotypic: bool` or `type: "homotypic"|"heterotypic"`. The DTO below tries both via a custom decoder; if the real shape uses something else, adjust `SynonymDTO` and rerun the test.

- [ ] **Step 12.2: Write `VernacularName.swift` + DTO**

`CatalogueOfLife/Models/Domain/VernacularName.swift`:

```swift
import Foundation

struct VernacularName: Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    let language: String?       // ISO 639-3 code (matches AppState.preferredVernacularLang)
    let country: String?
    let area: String?
}
```

`CatalogueOfLife/Models/DTOs/VernacularNameDTO.swift`:

```swift
import Foundation

struct VernacularNameDTO: Decodable, Sendable {
    let name: String
    let language: String?
    let country: String?
    let area: String?
}

extension VernacularName {
    init(dto: VernacularNameDTO, id: String) {
        self.init(id: id, name: dto.name, language: dto.language, country: dto.country, area: dto.area)
    }
}
```

- [ ] **Step 12.3: Write `ClassificationItem.swift`**

```swift
import Foundation

struct ClassificationItem: Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    let rank: Rank
}
```

- [ ] **Step 12.4: Write `SynonymyGroup.swift`**

```swift
import Foundation

struct SynonymyEntry: Equatable, Identifiable, Sendable {
    let id: String
    let scientificName: String
    let authorship: String?
    let rank: Rank
}

struct SynonymyGroup: Equatable, Identifiable, Sendable {
    enum Kind: String, Sendable { case homotypic, heterotypic }

    let id: String          // basionym id, or synthesized
    let kind: Kind
    let entries: [SynonymyEntry]
}
```

- [ ] **Step 12.5: Write `TaxonInfo.swift`**

```swift
import Foundation

struct TaxonInfo: Equatable, Sendable {
    let taxonId: String
    let scientificName: String
    let authorship: String?
    let rank: Rank
    let status: TaxonStatus
    let group: String?
    let classification: [ClassificationItem]
    let synonymyGroups: [SynonymyGroup]
    let vernacularNames: [VernacularName]
}

extension TaxonInfo {
    /// Returns the vernacular name in the preferred ISO 639-3 language, if any.
    func preferredVernacular(language: String?) -> VernacularName? {
        guard let language else { return nil }
        return vernacularNames.first { $0.language == language }
    }
}
```

- [ ] **Step 12.6: Write `TaxonInfoDTO.swift`**

```swift
import Foundation

struct TaxonInfoDTO: Decodable, Sendable {
    let taxon: TaxonDTO
    let classification: [ClassificationDTO]?
    let synonyms: [SynonymDTO]?
    let vernacularNames: [VernacularNameDTO]?

    struct TaxonDTO: Decodable, Sendable {
        let id: String
        let name: NameDTO
        let status: String?
        let group: String?
    }

    struct NameDTO: Decodable, Sendable {
        let scientificName: String
        let authorship: String?
        let rank: String?
    }

    struct ClassificationDTO: Decodable, Sendable {
        let id: String
        let name: String
        let rank: String?
    }

    struct SynonymDTO: Decodable, Sendable {
        let id: String
        let name: NameDTO
        let homotypic: Bool?
        let type: String?           // alternative shape: "homotypic"|"heterotypic"
        let basionymId: String?

        var isHomotypic: Bool {
            if let h = homotypic { return h }
            return type?.lowercased() == "homotypic"
        }
    }
}

extension TaxonInfo {
    init(dto: TaxonInfoDTO) {
        let t = dto.taxon
        let classification = (dto.classification ?? []).map {
            ClassificationItem(id: $0.id, name: $0.name, rank: Rank(apiValue: $0.rank))
        }
        let synonymyGroups = SynonymyGroup.group(synonyms: dto.synonyms ?? [])
        let vernaculars = (dto.vernacularNames ?? []).enumerated().map { idx, v in
            VernacularName(dto: v, id: "v\(idx)")
        }
        self.init(
            taxonId: t.id,
            scientificName: t.name.scientificName,
            authorship: t.name.authorship,
            rank: Rank(apiValue: t.name.rank),
            status: TaxonStatus(apiValue: t.status),
            group: t.group,
            classification: classification,
            synonymyGroups: synonymyGroups,
            vernacularNames: vernaculars
        )
    }
}
```

- [ ] **Step 12.7: Write `SynonymyGroup.group(synonyms:)`**

Add to `SynonymyGroup.swift`:

```swift
extension SynonymyGroup {
    /// Buckets synonyms by basionym (homotypic share a basionym) and splits homotypic vs heterotypic.
    static func group(synonyms: [TaxonInfoDTO.SynonymDTO]) -> [SynonymyGroup] {
        var homotypicByBasionym: [String: [SynonymyEntry]] = [:]
        var heterotypic: [SynonymyEntry] = []

        for s in synonyms {
            let entry = SynonymyEntry(
                id: s.id,
                scientificName: s.name.scientificName,
                authorship: s.name.authorship,
                rank: Rank(apiValue: s.name.rank)
            )
            if s.isHomotypic {
                let key = s.basionymId ?? s.id   // group by basionym, fall back to self
                homotypicByBasionym[key, default: []].append(entry)
            } else {
                heterotypic.append(entry)
            }
        }

        var groups: [SynonymyGroup] = homotypicByBasionym
            .sorted { $0.key < $1.key }
            .map { SynonymyGroup(id: $0.key, kind: .homotypic, entries: $0.value) }

        if !heterotypic.isEmpty {
            groups.append(SynonymyGroup(id: "heterotypic", kind: .heterotypic, entries: heterotypic))
        }
        return groups
    }
}
```

- [ ] **Step 12.8: Write decoding test**

`CatalogueOfLifeTests/TaxonInfoDecodingTests.swift`:

```swift
import Testing
import Foundation
@testable import CatalogueOfLife

@Suite("Taxon info decoding")
struct TaxonInfoDecodingTests {
    @Test("Decodes Felis catus /info fixture")
    func decodesFelisCatus() throws {
        let data = try FixtureLoader.data("taxon_info_felis_catus")
        let dto = try JSONDecoder().decode(TaxonInfoDTO.self, from: data)
        let info = TaxonInfo(dto: dto)
        #expect(info.scientificName == "Felis catus")
        #expect(info.rank == .species)
        #expect(!info.classification.isEmpty)
        #expect(info.classification.contains { $0.rank == .kingdom })
    }
}
```

- [ ] **Step 12.9: Write synonymy grouping test**

`CatalogueOfLifeTests/SynonymyGroupingTests.swift`:

```swift
import Testing
@testable import CatalogueOfLife

@Suite("Synonymy grouping")
struct SynonymyGroupingTests {
    private func syn(_ id: String, basionym: String? = nil, homotypic: Bool, name: String = "X") -> TaxonInfoDTO.SynonymDTO {
        TaxonInfoDTO.SynonymDTO(
            id: id,
            name: TaxonInfoDTO.NameDTO(scientificName: name, authorship: nil, rank: "species"),
            homotypic: homotypic, type: nil, basionymId: basionym
        )
    }

    @Test("Homotypic synonyms sharing a basionym group together")
    func homotypicGroupsByBasionym() {
        let groups = SynonymyGroup.group(synonyms: [
            syn("A", basionym: "BASE", homotypic: true),
            syn("B", basionym: "BASE", homotypic: true),
            syn("C", basionym: nil,    homotypic: false)
        ])
        let homo = groups.first { $0.kind == .homotypic }
        let hetero = groups.first { $0.kind == .heterotypic }
        #expect(homo?.entries.count == 2)
        #expect(hetero?.entries.count == 1)
    }

    @Test("Heterotypic-only input emits a single heterotypic group")
    func heterotypicOnly() {
        let groups = SynonymyGroup.group(synonyms: [
            syn("A", homotypic: false),
            syn("B", homotypic: false)
        ])
        #expect(groups.count == 1)
        #expect(groups.first?.kind == .heterotypic)
        #expect(groups.first?.entries.count == 2)
    }

    @Test("Empty input yields no groups")
    func emptyInput() {
        #expect(SynonymyGroup.group(synonyms: []).isEmpty)
    }
}
```

- [ ] **Step 12.10: Implement `getTaxonInfo`**

In `APIClientLive.swift`:

```swift
func getTaxonInfo(datasetKey: Int, taxonId: String) async throws -> TaxonInfo {
    let url = Endpoints.taxonInfo(datasetKey: datasetKey, taxonId: taxonId)
    let dto = try await getJSON(url, as: TaxonInfoDTO.self)
    return TaxonInfo(dto: dto)
}
```

- [ ] **Step 12.11: Run tests**

```bash
xcodegen generate
xcodebuild -scheme CatalogueOfLife -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' test -only-testing:CatalogueOfLifeTests/TaxonInfoDecodingTests -only-testing:CatalogueOfLifeTests/SynonymyGroupingTests -quiet
```

Expected: 4 tests pass.

- [ ] **Step 12.12: Commit**

```bash
git add CatalogueOfLife CatalogueOfLifeTests
git commit -m "Add getTaxonInfo with synonymy grouping (homotypic/heterotypic) and vernaculars"
```

---

## Task 13: TaxonDetailViewModel + tests

**Files:**
- Create: `CatalogueOfLife/Features/Taxon/TaxonDetailViewModel.swift`
- Modify: `CatalogueOfLifeTests/Helpers/StubAPIClient.swift` (already supports `taxonInfo` — no edit needed)

- [ ] **Step 13.1: Write `TaxonDetailViewModel.swift`**

```swift
import Foundation
import Observation

@MainActor
@Observable
final class TaxonDetailViewModel {
    enum LoadState: Equatable {
        case loading
        case loaded(TaxonInfo)
        case failed(APIError)
    }

    private(set) var state: LoadState = .loading

    let taxonId: String
    private let client: APIClient
    private let getDatasetKey: @MainActor () -> Int?

    init(taxonId: String,
         client: APIClient,
         getDatasetKey: @escaping @MainActor () -> Int?) {
        self.taxonId = taxonId
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
            let info = try await client.getTaxonInfo(datasetKey: key, taxonId: taxonId)
            state = .loaded(info)
        } catch let err as APIError {
            state = .failed(err)
        } catch {
            state = .failed(.server(status: -1))
        }
    }
}
```

- [ ] **Step 13.2: Add VM test to existing test file**

Append to `CatalogueOfLifeTests/SearchViewModelTests.swift` — actually, create a new suite file `CatalogueOfLifeTests/TaxonDetailViewModelTests.swift`:

```swift
import Testing
import Foundation
@testable import CatalogueOfLife

@Suite("TaxonDetailViewModel")
@MainActor
struct TaxonDetailViewModelTests {

    private func sampleInfo(id: String = "T1") -> TaxonInfo {
        TaxonInfo(
            taxonId: id,
            scientificName: "Felis catus",
            authorship: "L., 1758",
            rank: .species,
            status: .accepted,
            group: nil,
            classification: [
                ClassificationItem(id: "K", name: "Animalia", rank: .kingdom),
                ClassificationItem(id: "G", name: "Felis", rank: .genus)
            ],
            synonymyGroups: [],
            vernacularNames: [
                VernacularName(id: "v0", name: "House cat", language: "eng", country: nil, area: nil),
                VernacularName(id: "v1", name: "Hauskatze", language: "deu", country: nil, area: nil)
            ]
        )
    }

    @Test("Loads taxon info successfully")
    func loadsSuccess() async {
        let stub = StubAPIClient()
        stub.taxonInfo["T1"] = sampleInfo()
        let vm = TaxonDetailViewModel(taxonId: "T1", client: stub, getDatasetKey: { 9837 })
        await vm.load()
        if case let .loaded(info) = vm.state {
            #expect(info.scientificName == "Felis catus")
        } else {
            Issue.record("Expected .loaded")
        }
    }

    @Test("Surfaces notFound when API returns it")
    func notFound() async {
        let stub = StubAPIClient()
        let vm = TaxonDetailViewModel(taxonId: "missing", client: stub, getDatasetKey: { 9837 })
        await vm.load()
        #expect(vm.state == .failed(.notFound))
    }

    @Test("preferredVernacular returns the language match")
    func preferredVernacularMatches() {
        let info = sampleInfo()
        #expect(info.preferredVernacular(language: "deu")?.name == "Hauskatze")
        #expect(info.preferredVernacular(language: "fra") == nil)
        #expect(info.preferredVernacular(language: nil) == nil)
    }
}
```

- [ ] **Step 13.3: Run tests**

```bash
xcodegen generate
xcodebuild -scheme CatalogueOfLife -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' test -only-testing:CatalogueOfLifeTests/TaxonDetailViewModelTests -quiet
```

Expected: 3 tests pass.

- [ ] **Step 13.4: Commit**

```bash
git add CatalogueOfLife/Features/Taxon CatalogueOfLifeTests/TaxonDetailViewModelTests.swift
git commit -m "Add TaxonDetailViewModel with load + preferredVernacular tests"
```

---

## Task 14: TaxonDetailView and its subviews

**Files:**
- Create: `CatalogueOfLife/Features/Taxon/TaxonDetailView.swift`
- Create: `CatalogueOfLife/Features/Taxon/TaxonHeaderView.swift`
- Create: `CatalogueOfLife/Features/Taxon/ClassificationChipsView.swift`
- Create: `CatalogueOfLife/Features/Taxon/SynonymyView.swift`
- Create: `CatalogueOfLife/Features/Taxon/VernacularNamesView.swift`
- Modify: `CatalogueOfLife/Features/Search/SearchView.swift` (delete the temporary `TaxonDetailView` stub from Step 11.3)

- [ ] **Step 14.1: Write `TaxonHeaderView.swift`**

```swift
import SwiftUI

struct TaxonHeaderView: View {
    let info: TaxonInfo
    let preferredVernacular: VernacularName?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(info.scientificName).italic().font(.title2).bold()
                if let auth = info.authorship {
                    Text(auth).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 6) {
                Text(info.rank.rawValue.capitalized)
                    .font(.caption)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(.thinMaterial, in: Capsule())
                if info.status != .accepted {
                    Text(info.status.rawValue)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            if let v = preferredVernacular {
                Text(v.name).font(.body).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
```

- [ ] **Step 14.2: Write `ClassificationChipsView.swift`**

```swift
import SwiftUI

struct ClassificationChipsView: View {
    let items: [ClassificationItem]
    let onSelect: (ClassificationItem) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(items) { item in
                    Button { onSelect(item) } label: {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.rank.rawValue.uppercased())
                                .font(.caption2).foregroundStyle(.secondary)
                            Text(item.name).font(.caption).italic()
                        }
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 1)
        }
    }
}
```

- [ ] **Step 14.3: Write `SynonymyView.swift`**

```swift
import SwiftUI

struct SynonymyView: View {
    let groups: [SynonymyGroup]

    var body: some View {
        if groups.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("Synonymy").font(.headline)
                ForEach(groups) { group in
                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(group.entries) { entry in
                                HStack(alignment: .firstTextBaseline) {
                                    Text(entry.scientificName).italic()
                                    if let auth = entry.authorship {
                                        Text(auth).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .padding(.top, 4)
                    } label: {
                        HStack {
                            Text(group.kind == .homotypic ? "Homotypic" : "Heterotypic")
                                .font(.subheadline)
                            Text("(\(group.entries.count))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 14.4: Write `VernacularNamesView.swift`**

```swift
import SwiftUI

struct VernacularNamesView: View {
    let names: [VernacularName]
    let preferredLanguage: String?

    var sorted: [VernacularName] {
        guard let lang = preferredLanguage else { return names }
        return names.sorted { a, b in
            (a.language == lang ? 0 : 1) < (b.language == lang ? 0 : 1)
        }
    }

    var body: some View {
        if names.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("Common names").font(.headline)
                ForEach(sorted) { v in
                    HStack {
                        Text(v.name)
                        Spacer()
                        if let lang = v.language {
                            Text(lang).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
}
```

- [ ] **Step 14.5: Write `TaxonDetailView.swift`**

```swift
import SwiftUI

struct TaxonDetailView: View {
    @Environment(AppState.self) private var appState
    let taxonId: String
    @State private var vm: TaxonDetailViewModel?
    @State private var navigateTo: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                switch vm?.state {
                case .loaded(let info):
                    TaxonHeaderView(
                        info: info,
                        preferredVernacular: info.preferredVernacular(language: appState.preferredVernacularLang)
                    )
                    ClassificationChipsView(items: info.classification) { item in
                        navigateTo = item.id
                    }
                    SynonymyView(groups: info.synonymyGroups)
                    VernacularNamesView(
                        names: info.vernacularNames,
                        preferredLanguage: appState.preferredVernacularLang
                    )
                case .failed(let err):
                    errorView(err)
                case .loading, .none:
                    ProgressView().padding()
                }
            }
            .padding()
        }
        .navigationTitle("Taxon")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .principal) { ReleasePicker() } }
        .navigationDestination(item: $navigateTo) { id in
            TaxonDetailView(taxonId: id)
        }
        .task {
            if vm == nil {
                vm = TaxonDetailViewModel(
                    taxonId: taxonId,
                    client: APIClientLive(),
                    getDatasetKey: { [appState] in appState.selectedDataset?.key }
                )
            }
            await vm?.load()
        }
    }

    @ViewBuilder
    private func errorView(_ err: APIError) -> some View {
        VStack(spacing: 8) {
            Text("Couldn't load this taxon").font(.headline)
            Button("Retry") { Task { await vm?.load() } }
                .buttonStyle(.bordered)
        }
    }
}
```

- [ ] **Step 14.6: Delete the temporary stub in `SearchView.swift`**

Remove the placeholder `TaxonDetailView` struct that was added in Step 11.3. The real one now lives in its own file.

- [ ] **Step 14.7: Build and verify**

```bash
xcodegen generate
xcodebuild -scheme CatalogueOfLife -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' build -quiet
```

Open the simulator. Search "Felis catus", tap the row. Confirm:
- Header shows scientific name italic, authorship, rank chip.
- Classification chips horizontally scroll, tapping a rank pushes the parent taxon detail.
- Synonymy section expands.
- Common-names section lists vernaculars. If you set `preferredVernacularLang` to `"eng"` (via `xcrun simctl spawn booted defaults write org.catalogueoflife.mobile preferredVernacularLang -string eng`) and relaunch, the English entry appears at the top *and* in the header under the scientific name.

- [ ] **Step 14.8: Commit**

```bash
git add CatalogueOfLife
git commit -m "Add TaxonDetailView with header, classification, synonymy, vernacular sections"
```

---

## Task 15: Plan 1 final checkpoint

- [ ] **Step 15.1: Run the full test suite**

```bash
xcodegen generate
xcodebuild -scheme CatalogueOfLife -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' test -quiet
```

Expected: all tests pass (~19 total: 1 smoke + 2 dataset + 2 name search + 1 taxon info + 3 synonymy + 3 app state + 4 search vm + 3 detail vm; placeholder smoke is deleted next).

- [ ] **Step 15.2: Delete the placeholder smoke test**

```bash
git rm CatalogueOfLifeTests/PlaceholderTest.swift
xcodegen generate
xcodebuild -scheme CatalogueOfLife -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' test -quiet
```

Expected: all remaining tests still pass.

- [ ] **Step 15.3: Push and confirm CI is green**

```bash
git add -u
git commit -m "Drop placeholder smoke test" || echo "no changes"
git push
```

Wait for the Actions run on GitHub to go green.

- [ ] **Step 15.4: Manual end-to-end smoke**

In the simulator:
1. Launch the app. Release picker chip shows "3LXR" after load.
2. Switch to "Annual <year>" from the picker. Confirm subsequent searches scope to that release.
3. Switch back to "3LXR".
4. Search "Quercus", tap any hit, observe header + classification + synonymy + common names.
5. Tap a classification chip, observe push navigation up the parent chain.
6. Kill and relaunch the app; the last-selected release persists.

If any of these fail, file a follow-up issue and fix before declaring Plan 1 complete.

---

## Self-review of this plan against the spec

- **§2 foundational decisions:** SwiftUI ✓, iOS 18 ✓, iPhone only ✓ (TARGETED_DEVICE_FAMILY=1), no third-party SPM deps ✓, vanilla `@Observable` ✓, URLCache configured ✓, Swift Testing ✓, GitHub Actions on macos-15 ✓, English UI ✓.
- **§3 repo layout:** matches.
- **§4 architecture:** `AppState` env-injected, view-models per screen, `APIClient` actor — all present.
- **§5.1 endpoints landed in Plan 1:** `getDataset`, `listReleases`, `searchNames`, `getTaxonInfo` ✓. Others (`/tree`, `/suggest`, classification, `/source`, `/breakdown`, `/vocab/taxgroup`, import metrics) explicitly deferred to Plans 2–3.
- **§5.3 GBIF availability rule:** `DatasetRef.supportsGBIF` + `AppState.gbifAvailable` ✓ (computed even though no UI consumes it yet — wired ready for Plan 4).
- **§6 per-tab:** tab2 functional; other tabs are placeholders with the global release picker; release picker in the toolbar of every tab ✓.
- **§7 taxon details:** sections 1–4 present (header, classification, synonymy, vernacular names). Sections 5–7 (sunburst, GBIF, sources) explicitly out of scope.
- **§10 vernacular preference:** stored as 3-letter ISO 639-3 in UserDefaults via `AppState`; displayed in the detail header and pinned in the common-names section. About-tab picker UI is deferred to Plan 3.
- **§12 error handling:** per-section `LoadState`, per-screen retry, no crashes on 404.
- **§13 testing:** decoding tests for every endpoint we ship; mapper tests for synonymy grouping; AppState rule tests; VM tests with debounce.
- **§14 CI:** workflow lands in Task 2.

No spec gaps for Plan 1's scope. Type names consistent across tasks (`DatasetRef`, `SearchHit`, `TaxonInfo`, `SynonymyGroup`, `LoadState`). No placeholders, no "TBD".
