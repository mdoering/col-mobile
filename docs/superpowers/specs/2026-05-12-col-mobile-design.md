# Catalogue of Life Mobile — Design

Date: 2026-05-12
Status: Approved for planning

## 1. Goals

Build a native iPhone app that lets users explore the most comprehensive global taxonomy (Catalogue of Life) directly from the ChecklistBank API. Five bottom tabs: Tree, Search, Sources, Metrics, About. A taxon details screen ties everything together. Read-only, online-first.

## 2. Foundational decisions

| Topic | Decision |
| --- | --- |
| UI framework | SwiftUI |
| Min iOS | 18.0 |
| Devices | iPhone only (runs on iPad scaled) |
| Dependencies | Apple frameworks only; no third-party SPM packages in v1 |
| Architecture | Vanilla SwiftUI + `@Observable` view-models, env-injected `AppState` |
| Persistence | `UserDefaults` (settings) + SwiftData (favorites, recents) + `URLCache` (HTTP) |
| Testing | Swift Testing — unit tests for clients, mappers, sunburst math, AppState |
| CI | GitHub Actions, `xcodebuild test` on `macos-15` against iOS 18 simulator |
| Localization | UI in English; vernacular-name language is a separate user preference |

## 3. Repository layout

```
col-mobile/
├── CatalogueOfLife.xcodeproj/
├── CatalogueOfLife/
│   ├── App/                          # App entry, root TabView, AppState, environment
│   ├── Networking/                   # APIClient (CLB), GBIFClient
│   ├── Models/                       # Codable DTOs + domain types
│   ├── Persistence/                  # SwiftData: Favorite, RecentTaxon
│   ├── Features/
│   │   ├── Tree/     # TreeView + TreeViewModel
│   │   ├── Search/   # SearchView + SearchViewModel
│   │   ├── Taxon/    # TaxonDetailView + TaxonDetailViewModel
│   │   ├── Sources/  # SourcesView, SourceDetailView, view-models
│   │   ├── Metrics/  # MetricsView + view-model
│   │   └── About/    # AboutView + view-model
│   ├── Components/                   # SunburstView, GBIFMapView, ImageCarouselView,
│   │                                 # GroupIcon, FavoritesSheet, ReleasePicker
│   └── Resources/                    # Assets.xcassets (incl. Groups/), bundled vocab JSON
├── CatalogueOfLifeTests/             # Swift Testing target + Fixtures/
├── .github/workflows/ci.yml
├── README.md
├── specs.md
└── docs/superpowers/specs/2026-05-12-col-mobile-design.md
```

Bundle id: `org.catalogueoflife.mobile` (subject to change before TestFlight).

## 4. Architecture

Approach **A — Vanilla SwiftUI + `@Observable` view-models**.

- One `@Observable` view-model per screen, owning `LoadState` for its data and an injected client.
- A single root `@Observable AppState` injected via SwiftUI environment. It holds:
  - `selectedDatasetKey: Int` (persisted to `UserDefaults`)
  - `availableReleases: [DatasetRef]` (fetched on launch, refreshable)
  - `preferredVernacularLang: String?` (ISO 639-3 code, persisted to `UserDefaults`)
  - `favorites: [Favorite]` / `recents: [RecentTaxon]` (SwiftData-backed)
  - derived `gbifAvailable: Bool` — true only for the latest extended release (3LXR) and the base release (3LR)
- Views are dumb; they read view-model state and call view-model methods.
- Clients (`APIClient`, `GBIFClient`) are protocols. Production implementations wrap `URLSession`; test stubs return fixtures.

## 5. Networking

### 5.1 ChecklistBank API (`APIClient`)

Base: `https://api.checklistbank.org`. Actor with one method per endpoint we consume:

- `getDataset(_ key: Int)` — `/dataset/{key}`
- `listReleases()` — discovers 3LXR, 3LR, and annual releases for the release picker
- `getTreeChildren(datasetKey:, taxonId:?)` — `/dataset/{key}/tree[/{id}]`
- `getTaxonClassification(datasetKey:, taxonId:)` — parent chain (used by tab1 suggest jump)
- `searchNames(datasetKey:, q:)` — `/dataset/{key}/nameusage/search`
- `suggest(datasetKey:, q:)` — `/dataset/{key}/nameusage/suggest`
- `getTaxonInfo(datasetKey:, taxonId:)` — `/dataset/{key}/taxon/{id}/info`
- `getBreakdown(datasetKey:, taxonId:?)` — `/dataset/{key}[/taxon/{id}]/breakdown` (drives sunburst)
- `listSources(datasetKey:)` — `/dataset/{key}/source`
- `getSource(datasetKey:, sourceKey:)` — `/dataset/{key}/source/{key}`
- `getImportMetrics(datasetKey:)` — for tab4
- `getTaxGroupVocab()` — `https://api.checklistbank.org/vocab/taxgroup` (cached, bundled fallback)

Exact paths confirmed against the live API at implementation time.

All responses decoded into Codable DTOs, then mapped to domain types in the client layer so views see clean models. `URLCache` (≈50 MB on-disk) gives free re-use of recent GETs. Errors normalized to:

```swift
enum APIError: Error {
    case network(URLError)
    case server(status: Int)
    case decoding(DecodingError)
    case notFound
}
```

### 5.2 GBIF API (`GBIFClient`)

Base: `https://api.gbif.org`. Uses GBIF's new multi-taxonomy v2 API; COL identifiers are first-class.

- Constant: `COL_CHECKLIST_KEY = "7ddf754f-d193-4cc9-b351-99906754a03b"`
- Every call adds `checklistKey=<COL>` and passes the COL `taxonId` directly (no `/v1/species/match` round-trip).
- Occurrence metrics: `GET /v1/occurrence/search?checklistKey=...&taxonKey=<COL-id>&limit=0` — reads counts + facets from the response.
- Images: same endpoint with `mediaType=StillImage&limit=20`.
- Map tiles: `MKTileOverlay` against `https://api.gbif.org/v2/map/occurrence/density/{z}/{x}/{y}@1x.png?checklistKey=...&taxonId=<COL-id>`.
- Cross-checks (future): `GET /v2/experimental/taxon/{checklistKey}/{taxonId}`.

The `classifications` map in occurrence responses is decoded but unused in v1 — COL classification already comes from CLB's `/info`.

### 5.3 GBIF availability rule

GBIF integration uses identifiers from the latest extended release (3LXR) and base release (3LR) only. For all annual releases, identifiers differ and won't resolve in GBIF's COL checklist.

- `AppState.gbifAvailable` is `true` iff `selectedDatasetKey ∈ {3LXR, 3LR}`.
- `TaxonDetailViewModel` does not fire any `GBIFClient` request when `gbifAvailable` is false.
- `TaxonDetailView` omits the entire GBIF section (metrics, map, image carousel) when false. No empty box, no banner.

## 6. Per-tab features

### Tab 1 — Tree
- `NavigationStack` browser. Root shows top-level taxa for the selected dataset. Tapping a row pushes the next rank.
- Top quick-suggest field bound to `suggest`. Picking a suggestion calls `getTaxonClassification` to load the parent path, then pushes that chain into the NavigationStack so the user lands on the matched row with siblings/children visible.
- Toolbar button (top-trailing) opens `FavoritesSheet`.

### Tab 2 — Search
- Search bar bound to `searchNames` with 300 ms debounce.
- Tabular results: `GroupIcon`, canonical name, authorship, rank chip, status.
- Tapping a synonym hit resolves to its accepted taxon (via the search result's `acceptedId`) before pushing `TaxonDetailView`. There are no synonym detail pages.

### Tab 3 — Sources
- Scrolling list of `listSources` results; rows show logo + title.
- Tap → `SourceDetailView` showing all metrics from `getSource`.

### Tab 4 — Metrics
- Dataset-level taxonomic sunburst (rooted at the dataset) — see §8.
- Dataset import metrics from `getImportMetrics`.

### Tab 5 — About
- Static intro: what CoL is, how identifiers work.
- **Preferences** section: a `Picker` to choose the preferred common-name language (see §10).
- Release metadata section that re-renders when `selectedDatasetKey` changes (title, version, issued date, citation, contributors, license — sourced from `getDataset`).

### Release picker
- Global toolbar control at the top of every tab. Chip-style `Picker` listing the releases from `AppState.availableReleases`. Selecting an entry updates `AppState.selectedDatasetKey`, which propagates everywhere reactively.

## 7. Taxon detail page

Single scrolling `TaxonDetailView`, sections top-to-bottom:

1. **Header** — `GroupIcon` + scientific name (italic) + authorship + rank chip + status. Star button to toggle favorite. If a vernacular exists in the preferred language, it shows under the scientific name. Toolbar overflow has "Open on catalogueoflife.org" for 3LXR, "Open on checklistbank.org" otherwise.
2. **Classification breadcrumb** — parent chain from `/info` as a horizontal scroll of chips; tap a rank to push that taxon.
3. **Synonymy** — homotypic + heterotypic groups from `/info`, rendered as collapsible sections, basionym highlighted. Tapping a synonym row does not navigate (no synonym page); it reveals authorship + source inline.
4. **Vernacular names** — all vernaculars from `/info`, with the preferred-language one pinned to the top.
5. **Taxonomic breakdown sunburst** — 2 rings rooted on this taxon. Data from `getBreakdown(datasetKey:, taxonId:)`. Tap ring-1 or ring-2 → push that descendant's details. Tap center → pop to parent. See §8.
6. **GBIF section** (only when `gbifAvailable`):
   - **Metrics row**: occurrence count, distinct countries, distinct datasets.
   - **Map card**: `MKMapView` (~180 pt tall) with `GBIFTileOverlay` for COL's checklist + this taxon's id.
   - **Image carousel**: `TabView(.page)` paging through the first ~20 `StillImage` results; tap → full-screen viewer with attribution + license.
7. **Sources** — sources contributing this taxon, with logo + link into tab3's source detail.

Per-section `LoadState`: sunburst and GBIF sections load independently so a slow GBIF call never blocks synonymy/sunburst above it.

## 8. Sunburst (`SunburstView`)

Fixed depth: always 2 rings.

- Center disk = the current taxon (or dataset root for tab4).
- Ring 1 = direct children. Ring 2 = grandchildren.
- Data source: a single call to `getBreakdown(datasetKey:, taxonId:?)`. No recursive tree fetching.

Math:
- Polar layout. Each child arc occupies a sweep proportional to its `count` within its parent's sweep: `childSweep = parentSweep * child.count / parent.count`.
- Ring thickness = `(outerRadius − innerRadius) / 2`.
- Labels render only when an arc's sweep exceeds a legibility threshold (e.g., > 8°), otherwise the arc is icon-only and shows the name on long-press.

Drawing:
- SwiftUI `Canvas` body. One `Path` per arc using `addArc` + an inner counter-arc to form donut wedges. Per-rank palette; saturation modulated by parent so descendants tint with their ancestor.

Interaction:
- Tap arc → push that taxon. Tap center → pop to parent. Long-press → popover with full name + count.

## 9. Persistence

### SwiftData models

```swift
@Model final class Favorite {
    @Attribute(.unique) var compositeKey: String  // "<datasetKey>:<taxonId>"
    var datasetKey: Int
    var taxonId: String
    var name: String
    var authorship: String?
    var rank: String
    var group: String?
    var addedAt: Date
}

@Model final class RecentTaxon {
    @Attribute(.unique) var compositeKey: String  // "<datasetKey>:<taxonId>"
    var datasetKey: Int
    var taxonId: String
    var name: String
    var rank: String
    var group: String?
    var lastVisited: Date
}
```

- Recents bumped on every successful taxon-details load; capped at 50 (oldest evicted).
- Favorites toggled by the star button on `TaxonDetailView`. Unbounded.
- Both keyed by `(datasetKey, taxonId)`: a favorite from 3LXR doesn't pollute the favorites list when viewing an annual. The Favorites sheet shows favorites *for the current dataset*, with a small "favorites in other releases (n)" footer.
- `FavoritesSheet` opens from tab1's toolbar; two segments: Favorites | Recents.

### UserDefaults keys

- `selectedDatasetKey: Int` — default 3LXR.
- `preferredVernacularLang: String?` — ISO 639-3 code; nil = "none".
- `hasSeenOnboarding: Bool` — reserved.

## 10. Vernacular language preference

- Stored as a 3-letter ISO 639-3 code matching the API's `language` field on vernacular records. Nil = "None / scientific name only".
- About-tab `Picker` lists a fixed initial set: `eng, spa, fra, deu, por, ita, nld, zho, jpn, rus, ara`, plus "None". Display labels are localized language names from `Locale` so the user reads "English / Español / Deutsch / …" while the stored value is the API code.
- When set, the vernacular shows as a lighter secondary line under the scientific name in: tree rows (tab1), search results (tab2), favorites/recents rows, and the taxon details header. If a taxon has no vernacular in the chosen language, only the scientific name renders — no fallback to other languages.
- Tab1/tab2 list endpoints may not include vernaculars by default; we'll request them via the API's vernacular parameter if available. If not, vernaculars only appear on the details page in v1. **Open item.**

## 11. TaxGroup icons

- Vocabulary at `https://api.checklistbank.org/vocab/taxgroup`. Each entry has a code, label, and SVG icon.
- Codes appear as a `group` field on many CLB responses (search hits, taxon, etc.).
- SVGs bundled as vector image assets under `Assets.xcassets/Groups/<groupCode>.imageset/`. Vocab JSON also bundled, refreshed on app update.
- `GroupIcon(_ group: String?)` is the single SwiftUI component used everywhere a group icon should appear: tree rows, search results, favorites/recents rows, taxon details header. Unknown `group` value → renders nothing.
- Adding new groups is a maintenance task: drop the new SVG into the asset catalog and update the bundled vocab JSON.

## 12. Error and loading handling

- View-models expose per-section `LoadState<T> { idle, loading, loaded(T), failed(APIError) }`.
- Skeleton placeholders over spinners where layout is known (rows, cards).
- Errors are inline per section, never screen-level:
  - `.notFound` → empty state with friendly copy.
  - `.network` → inline banner with retry.
  - `.decoding` → user sees a generic "something went wrong"; logged + `assertionFailure` in DEBUG to catch schema drift.
  - `.server(status)` → inline retry banner; status code surfaced in DEBUG only.
- Offline: no explicit offline mode in v1. `URLCache` serves repeat GETs when available.

## 13. Testing

Target `CatalogueOfLifeTests` using Swift Testing:

1. **API client decoding** — fixture-driven `Codable` round-trips for every endpoint we call.
2. **Domain mapping** — DTO → domain transforms (synonymy grouping, accepted-taxon resolution for synonym hits, classification chain).
3. **Sunburst math** — sweep allocation, hit-testing polar coords, label threshold rules.
4. **AppState rules** — `gbifAvailable` derivation, dataset-key-scoped favorites lookup, recents 50-cap eviction, vernacular preference filtering.

Both clients are protocols; tests use in-memory stubs returning fixtures from `CatalogueOfLifeTests/Fixtures/`. No network in CI.

## 14. CI

`.github/workflows/ci.yml`:
- Runner `macos-15`, Xcode 16 selected via `xcodes`.
- Triggers: push + PR to `main`.
- Steps: checkout → `xcodebuild test` against an iOS 18 iPhone simulator, with DerivedData caching.
- No lint/format gate in v1.

## 15. Non-goals (v1)

- iPad-optimized layouts; macOS Catalyst; visionOS
- Localization of UI strings beyond English
- Offline data download / full sync
- Push notifications
- User accounts / sign-in
- Edit / contribute workflows (app is read-only)
- Snapshot / UI tests; performance tests
- Crash reporting / analytics
- Deep links / universal links
- Widgets, Live Activities, Shortcuts
- Dark-mode custom theming (use system defaults)
- App Store submission (TestFlight first when the build is ready)

## 16. Open items (to resolve at implementation time)

- Confirm exact CLB endpoint paths and response shapes against the live API.
- Confirm `/breakdown` endpoint shape and query parameters; fall back to depth-limited `/tree` calls if unavailable.
- Confirm whether list endpoints (search, suggest, tree children) can include vernacular names; if not, accept that vernacular display in lists ships in a later version.
- Pull COL brand color tokens from the portal CSS to drive the per-rank sunburst palette and UI accents.
- App icon — placeholder for v1, real icon later.
- Bundle id default `org.catalogueoflife.mobile` unless the team prefers another.
- TestFlight signing and distribution — out of scope until the build is ready.

## 17. Risks

- GBIF multi-taxonomy v2 endpoints are still labelled "experimental"; schema may shift before v1 ships.
- Sunburst label legibility on the 2nd ring with many small arcs — mitigated by the legibility threshold rule, may need iteration on real data.
- Vocab drift for `taxgroup` — bundling means we ship a new app version when CoL adds groups; acceptable for v1.
