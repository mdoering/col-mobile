# Plan 2 — Tree + Persistence + GroupIcon Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Tree tab (tab1) with classification-jump suggest, add bundled TaxGroup icons everywhere a taxon name is shown, and add SwiftData-backed Favorites + Recents accessible from a Tree-tab toolbar sheet.

**Architecture:** Same as Plan 1 — SwiftUI + `@Observable` view-models + `APIClient` actor + env-injected `AppState`. Persistence via SwiftData (single `ModelContainer` env-injected at app launch). TaxGroup SVGs bundled at build time from `/vocab/taxgroup` snapshot; `GroupIcon` is a single reusable component.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, Swift Testing, XcodeGen, GitHub Actions.

**Spec reference:** `docs/superpowers/specs/2026-05-12-col-mobile-design.md` — Plan 2 implements §6 tab 1, §9 (persistence), §11 (TaxGroup icons), plus the suggest + classification helper endpoints in §5.1.

**Out of scope for Plan 2 (deferred):**
- Sunburst (`SunburstView`) — Plan 3
- Sources, Metrics, About tab bodies — Plan 3
- About-tab vernacular language picker UI — Plan 3 (the storage + system-fallback derivation already shipped in Plan 1.5)
- GBIF integration — Plan 4

---

## API facts (verified against live API on 2026-05-12)

- `GET /vocab/taxgroup` returns 37 entries with fields: `codes: [String]` (the values the API's `group` field may carry), `name: String` (canonical group name, e.g. `"viruses"`), `description: String`, `iconSVG: String` (PhyloPic URL), `icon: String` (PNG URL), `phylopic: String` (UUID), optional `parents: [String]`, `primaryParent: String?`, `other: Bool`.
- `GET /dataset/{key}/tree` returns `PagedDTO<TreeNodeDTO>` with each node: `datasetKey, id, parentId?, rank, status, count, childCount, name, authorship, labelHtml`. `childCount == 0` means leaf.
- `GET /dataset/{key}/tree/{taxonId}/children` returns the same `PagedDTO<TreeNodeDTO>` shape.
- `GET /dataset/{key}/nameusage/suggest?q=...` returns a flat `[SuggestEntryDTO]`: `match, context, usageId, nameId, rank, status, group, suggestion`. (NOT a paged response — just an array.)
- `GET /dataset/{key}/taxon/{id}/classification` returns a flat `[ClassificationEntryDTO]`: `id, name, rank, authorship, labelHtml` — ordered root → immediate parent (does NOT include the target taxon itself).

---

## File map

```
CatalogueOfLife/
├── Components/
│   └── GroupIcon.swift                                # new
├── Models/
│   ├── DTOs/
│   │   ├── TaxGroupVocabDTO.swift                     # new
│   │   ├── TreeNodeDTO.swift                          # new
│   │   ├── SuggestEntryDTO.swift                      # new
│   │   └── ClassificationEntryDTO.swift               # new
│   └── Domain/
│       ├── TaxGroup.swift                             # new
│       ├── TaxGroupVocab.swift                        # new
│       ├── TreeNode.swift                             # new
│       └── TaxonSuggestion.swift                      # new
├── Networking/
│   ├── APIClient.swift                                # MODIFY: add 4 new methods
│   ├── APIClientLive.swift                            # MODIFY: implement 4 new methods
│   └── Endpoints.swift                                # MODIFY: 4 new builders
├── Persistence/
│   ├── PersistenceStore.swift                         # new — ModelContainer setup
│   ├── Favorite.swift                                 # new — @Model
│   └── RecentTaxon.swift                              # new — @Model
├── Features/
│   ├── Favorites/
│   │   ├── FavoritesSheet.swift                       # new
│   │   └── FavoritesSheetViewModel.swift              # new
│   ├── Tree/
│   │   ├── TreeView.swift                             # new (replaces TabPlaceholderView usage)
│   │   ├── TreeViewModel.swift                        # new
│   │   ├── TreeRowView.swift                          # new
│   │   └── SuggestField.swift                         # new
│   ├── Search/
│   │   └── SearchView.swift                           # MODIFY: SearchRow gets GroupIcon
│   └── Taxon/
│       ├── TaxonHeaderView.swift                      # MODIFY: GroupIcon next to name
│       ├── TaxonDetailView.swift                      # MODIFY: star toggle in toolbar; recents bump
│       └── TaxonDetailViewModel.swift                 # MODIFY: bump recents on load
├── Resources/
│   └── Assets.xcassets/
│       └── Groups/
│           ├── viruses.imageset/
│           │   ├── viruses.svg
│           │   └── Contents.json
│           └── … one imageset per vocab entry
│       Bundle/
│         taxgroup_vocab.json                          # bundled vocab snapshot
└── App/
    ├── CatalogueOfLifeApp.swift                       # MODIFY: install ModelContainer
    └── RootTabView.swift                              # MODIFY: replace Tree placeholder with TreeView

CatalogueOfLifeTests/
├── Fixtures/
│   ├── vocab_taxgroup.json                            # new
│   ├── tree_root.json                                 # new
│   ├── tree_children.json                             # new
│   ├── suggest_felis.json                             # new
│   └── classification_felis_catus.json                # new
├── TaxGroupVocabTests.swift                           # new
├── TreeDecodingTests.swift                            # new
├── SuggestDecodingTests.swift                         # new
├── ClassificationDecodingTests.swift                  # new
├── PersistenceTests.swift                             # new
└── FavoritesSheetViewModelTests.swift                 # new
```

---

## Task 1: TaxGroup vocab DTO + domain + decoding test + bundled fixture

**Files:**
- Create: `CatalogueOfLife/Models/DTOs/TaxGroupVocabDTO.swift`
- Create: `CatalogueOfLife/Models/Domain/TaxGroup.swift`
- Create: `CatalogueOfLifeTests/Fixtures/vocab_taxgroup.json`
- Create: `CatalogueOfLifeTests/TaxGroupVocabTests.swift`

- [ ] **Step 1.1: Capture the vocab fixture**

```bash
curl -s 'https://api.checklistbank.org/vocab/taxgroup' | python3 -m json.tool > CatalogueOfLifeTests/Fixtures/vocab_taxgroup.json
python3 -c "
import json
d = json.load(open('CatalogueOfLifeTests/Fixtures/vocab_taxgroup.json'))
print('entries:', len(d))
print('all codes ever seen:', sorted({c for e in d for c in (e.get('codes') or [])}))
"
```

Expected: ~37 entries; flat list (NOT a paged response). If empty, STOP and report BLOCKED.

- [ ] **Step 1.2: Write `TaxGroupVocabDTO.swift`**

```swift
import Foundation

/// Wire shape from `GET /vocab/taxgroup`. Lives at the response root as a JSON array.
struct TaxGroupVocabDTO: Decodable, Sendable {
    let codes: [String]
    let name: String
    let description: String?
    let icon: String?
    let iconSVG: String?
    let phylopic: String?
    let parents: [String]?
    let primaryParent: String?
    let other: Bool?
}
```

- [ ] **Step 1.3: Write `TaxGroup.swift`** (domain)

```swift
import Foundation

/// One row of the TaxGroup vocabulary.
///
/// The API's `group` field on a taxon/search hit carries one of the `codes` strings.
/// The `name` field (e.g. "viruses") is the canonical group name and is what we use
/// as the bundled SVG asset name in `Assets.xcassets/Groups/<name>.imageset/`.
struct TaxGroup: Equatable, Hashable, Sendable {
    /// Strings that may appear as a `group` field on a taxon and route to this entry.
    let codes: [String]
    /// Canonical group name, used as the bundled image asset key.
    let name: String
    /// Human-readable description (English).
    let description: String?

    init(dto: TaxGroupVocabDTO) {
        self.codes = dto.codes
        self.name = dto.name
        self.description = dto.description
    }
}
```

- [ ] **Step 1.4: Write decoding test**

`CatalogueOfLifeTests/TaxGroupVocabTests.swift`:

```swift
import Testing
import Foundation
@testable import CatalogueOfLife

@Suite("TaxGroup vocab decoding")
struct TaxGroupVocabTests {
    @Test("Decodes the full vocab fixture")
    func decodesVocab() throws {
        let data = try FixtureLoader.data("vocab_taxgroup")
        let dtos = try JSONDecoder().decode([TaxGroupVocabDTO].self, from: data)
        let groups = dtos.map(TaxGroup.init(dto:))
        #expect(groups.count > 10)
        #expect(groups.contains { $0.name == "viruses" })
        #expect(groups.contains { $0.codes.contains("bacterial") })
    }
}
```

- [ ] **Step 1.5: Run test**

```bash
xcodegen generate
xcodebuild -scheme CatalogueOfLife -destination 'platform=iOS Simulator,name=iPhone 16e,OS=latest' test -only-testing:CatalogueOfLifeTests/TaxGroupVocabTests -quiet
```
Expected: 1 test passes.

- [ ] **Step 1.6: Commit**

```bash
git add CatalogueOfLife CatalogueOfLifeTests
git commit -m "Add TaxGroup vocab DTO + domain + decoding test"
```

---

## Task 2: Bundle TaxGroup vocab + SVG assets (with weekly auto-refresh)

This task does two things:
1. Adds a build-time script that fetches the live vocab + SVGs and regenerates the bundled assets
2. Adds a scheduled GitHub Action that runs the script weekly and commits any diff so the repo stays fresh automatically

The script is the source of truth; the committed snapshot is the build-time input. The cron job keeps them in sync.

**Files:**
- Create: `Tools/bundle_taxgroup_assets.py` (build-time script)
- Create: `CatalogueOfLife/Resources/Bundle/taxgroup_vocab.json` (committed snapshot)
- Create: `CatalogueOfLife/Resources/Assets.xcassets/Groups/<name>.imageset/<name>.svg` × N (one per vocab entry)
- Create: `CatalogueOfLife/Resources/Assets.xcassets/Groups/<name>.imageset/Contents.json` × N
- Modify: `project.yml` — `CatalogueOfLife/Resources` is already covered, no change needed
- Create: `.github/workflows/refresh-taxgroup.yml` (scheduled refresh)

- [ ] **Step 2.1: Write `Tools/bundle_taxgroup_assets.py`**

```python
#!/usr/bin/env python3
"""Fetch the TaxGroup vocab, download its SVG icons, and write Xcode asset
catalog entries + a bundled vocab JSON snapshot.

Re-run this whenever new groups are added to the upstream vocab.
"""
from __future__ import annotations
import json
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ASSETS_DIR = ROOT / "CatalogueOfLife/Resources/Assets.xcassets/Groups"
BUNDLE_DIR = ROOT / "CatalogueOfLife/Resources/Bundle"
VOCAB_URL = "https://api.checklistbank.org/vocab/taxgroup"
TIMEOUT = 30

def fetch_json(url: str):
    with urllib.request.urlopen(url, timeout=TIMEOUT) as resp:
        return json.load(resp)

def fetch_bytes(url: str) -> bytes:
    with urllib.request.urlopen(url, timeout=TIMEOUT) as resp:
        return resp.read()

def write_imageset(name: str, svg_bytes: bytes) -> None:
    imageset = ASSETS_DIR / f"{name}.imageset"
    imageset.mkdir(parents=True, exist_ok=True)
    svg_path = imageset / f"{name}.svg"
    svg_path.write_bytes(svg_bytes)
    contents = {
        "images": [
            {"filename": f"{name}.svg", "idiom": "universal"}
        ],
        "info": {"author": "xcode", "version": 1},
        "properties": {"preserves-vector-representation": True},
    }
    (imageset / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")

def main() -> int:
    ASSETS_DIR.mkdir(parents=True, exist_ok=True)
    BUNDLE_DIR.mkdir(parents=True, exist_ok=True)

    vocab = fetch_json(VOCAB_URL)
    if not isinstance(vocab, list) or not vocab:
        print("vocab response missing or empty", file=sys.stderr)
        return 1

    # Write the vocab JSON snapshot (committed alongside the app).
    bundled_path = BUNDLE_DIR / "taxgroup_vocab.json"
    bundled_path.write_text(json.dumps(vocab, indent=2) + "\n")
    print(f"Wrote bundled vocab snapshot ({len(vocab)} entries) → {bundled_path}")

    # Folder-level Contents.json so Xcode treats the directory as a "namespaced" folder.
    (ASSETS_DIR / "Contents.json").write_text(json.dumps({
        "info": {"author": "xcode", "version": 1},
        "properties": {"provides-namespace": True}
    }, indent=2) + "\n")

    successes = 0
    failures: list[tuple[str, str]] = []
    for entry in vocab:
        name = entry["name"]
        svg_url = entry.get("iconSVG")
        if not svg_url:
            failures.append((name, "no iconSVG URL"))
            continue
        try:
            svg = fetch_bytes(svg_url)
            if not svg.lstrip().startswith(b"<"):
                raise RuntimeError(f"not SVG-ish: starts {svg[:40]!r}")
            write_imageset(name, svg)
            successes += 1
            print(f"  {name}: {len(svg)} bytes")
        except Exception as exc:
            failures.append((name, str(exc)))

    print(f"\nWrote {successes} imagesets to {ASSETS_DIR}")
    if failures:
        print(f"Skipped {len(failures)}:")
        for name, why in failures:
            print(f"  {name}: {why}")
    return 0

if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 2.2: Run the script**

```bash
chmod +x Tools/bundle_taxgroup_assets.py
python3 Tools/bundle_taxgroup_assets.py
ls CatalogueOfLife/Resources/Assets.xcassets/Groups/ | head -5
ls CatalogueOfLife/Resources/Bundle/
```
Expected: ~37 imageset directories created; `taxgroup_vocab.json` present in `Bundle/`. If some entries lack `iconSVG`, the script reports them and continues — we render no icon for those.

- [ ] **Step 2.3: Modify `project.yml` to include the Bundle directory in resources**

The app target currently has:
```yaml
    resources:
      - path: CatalogueOfLife/Resources
```
This already covers `Resources/Bundle/` recursively. No change needed — verify by running `xcodegen generate` and grep-checking the project bundles the file.

- [ ] **Step 2.4: Verify Xcode catalogues the SVGs**

```bash
xcodegen generate
xcodebuild -scheme CatalogueOfLife -destination 'platform=iOS Simulator,name=iPhone 16e,OS=latest' build -quiet
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name CatalogueOfLife.app -type d -path '*Debug-iphonesimulator*' | head -1)
echo "App: $APP_PATH"
ls "$APP_PATH/Assets.car" 2>/dev/null || echo "Assets.car NOT present"
ls "$APP_PATH/taxgroup_vocab.json"
```
Expected: `Assets.car` exists (the compiled asset catalog containing the SVGs as PDFs); the JSON snapshot ships in the app bundle root.

- [ ] **Step 2.5: Add the scheduled refresh workflow**

`.github/workflows/refresh-taxgroup.yml`:

```yaml
name: Refresh TaxGroup assets
on:
  schedule:
    - cron: "17 4 * * 1"   # Monday 04:17 UTC — off-peak
  workflow_dispatch:        # allow manual trigger from the Actions UI

permissions:
  contents: write

jobs:
  refresh:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run bundling script
        run: |
          python3 Tools/bundle_taxgroup_assets.py

      - name: Commit and push if there are changes
        run: |
          if [ -n "$(git status --porcelain CatalogueOfLife/Resources/Bundle CatalogueOfLife/Resources/Assets.xcassets/Groups)" ]; then
            git config user.name "github-actions[bot]"
            git config user.email "github-actions[bot]@users.noreply.github.com"
            git add CatalogueOfLife/Resources/Bundle CatalogueOfLife/Resources/Assets.xcassets/Groups
            git commit -m "Refresh TaxGroup vocab + SVG assets (automated)"
            git push
          else
            echo "No vocab/asset changes."
          fi
```

The schedule runs once a week (Monday 04:17 UTC); `workflow_dispatch` lets you trigger it on demand from the Actions UI. `contents: write` permission lets the bot push directly to `main` — fine for a solo-developer repo.

- [ ] **Step 2.6: Commit**

```bash
git add Tools CatalogueOfLife/Resources .github/workflows/refresh-taxgroup.yml
git commit -m "Bundle TaxGroup SVG icons + vocab snapshot; add weekly auto-refresh workflow"
```

---

## Task 3: TaxGroupVocab loader + GroupIcon component + apply to existing screens

`TaxGroupVocab` is the runtime lookup: load the bundled JSON snapshot at app launch into a fast `[code: TaxGroup]` map. Optionally refresh from the live API on launch (a follow-up — not in Plan 2 scope; the bundled snapshot is fresh enough as long as the script is run before each release).

**Files:**
- Create: `CatalogueOfLife/Models/Domain/TaxGroupVocab.swift`
- Create: `CatalogueOfLife/Components/GroupIcon.swift`
- Modify: `CatalogueOfLife/App/CatalogueOfLifeApp.swift` — load vocab on launch, inject into environment
- Modify: `CatalogueOfLife/Features/Search/SearchView.swift` — `SearchRow` shows `GroupIcon(hit.group)`
- Modify: `CatalogueOfLife/Features/Taxon/TaxonHeaderView.swift` — `GroupIcon(info.group)` next to scientific name
- Modify: `CatalogueOfLifeTests/TaxGroupVocabTests.swift` — add lookup test

- [ ] **Step 3.1: Write `TaxGroupVocab.swift`**

```swift
import Foundation

@MainActor
final class TaxGroupVocab {
    private let byCode: [String: TaxGroup]

    init(groups: [TaxGroup]) {
        var map: [String: TaxGroup] = [:]
        for group in groups {
            for code in group.codes {
                map[code] = group
            }
        }
        self.byCode = map
    }

    /// Looks up the canonical `TaxGroup` for the given API `group` code.
    func lookup(code: String?) -> TaxGroup? {
        guard let code, !code.isEmpty else { return nil }
        return byCode[code]
    }

    /// Loads the bundled vocab snapshot from the app bundle. Falls back to an empty
    /// vocab (no icons rendered) if the file is missing or unparseable.
    static func loadBundled() -> TaxGroupVocab {
        guard let url = Bundle.main.url(forResource: "taxgroup_vocab", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let dtos = try? JSONDecoder().decode([TaxGroupVocabDTO].self, from: data) else {
            return TaxGroupVocab(groups: [])
        }
        return TaxGroupVocab(groups: dtos.map(TaxGroup.init(dto:)))
    }
}
```

- [ ] **Step 3.2: Write `GroupIcon.swift`**

```swift
import SwiftUI

/// Renders a 20pt TaxGroup icon for an API group code. Looks the code up in
/// the environment-injected `TaxGroupVocab` and resolves to the bundled SVG asset.
/// Renders nothing for nil/unknown codes.
struct GroupIcon: View {
    @Environment(TaxGroupVocab.self) private var vocab
    let code: String?
    var size: CGFloat = 20

    var body: some View {
        if let resolved = vocab.lookup(code: code) {
            Image("Groups/\(resolved.name)")
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .accessibilityLabel(resolved.description ?? resolved.name)
        } else {
            EmptyView()
        }
    }
}
```

- [ ] **Step 3.3: Inject `TaxGroupVocab` at launch**

Edit `CatalogueOfLife/App/CatalogueOfLifeApp.swift`:

```swift
import SwiftUI

@main
struct CatalogueOfLifeApp: App {
    @State private var state: AppState = AppState(client: APIClientLive())
    @State private var vocab: TaxGroupVocab = TaxGroupVocab.loadBundled()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(state)
                .environment(vocab)
                .task(id: "launch") { await state.loadReleases() }
        }
    }
}
```

`TaxGroupVocab` needs to be `Observable` to live in `@Environment(TaxGroupVocab.self)`. Update its declaration:

```swift
@MainActor
@Observable
final class TaxGroupVocab {
    // ... (rest unchanged)
}
```

- [ ] **Step 3.4: Add `GroupIcon` to `SearchRow`**

In `CatalogueOfLife/Features/Search/SearchView.swift`, the `SearchRow` struct currently begins with:

```swift
private struct SearchRow: View {
    let hit: SearchHit

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(hit.scientificName).italic().font(.body)
                ...
```

Insert a leading `GroupIcon` and reflow:

```swift
private struct SearchRow: View {
    let hit: SearchHit

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            GroupIcon(code: hit.group, size: 22)
                .padding(.top, 2)
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
                    HStack(spacing: 4) {
                        Text("synonym of").font(.caption2).foregroundStyle(.orange)
                        if let accepted = hit.acceptedName {
                            Text(accepted).italic().font(.caption2).foregroundStyle(.orange)
                        } else {
                            Text("—").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 3.5: Add `GroupIcon` to `TaxonHeaderView`**

Edit `CatalogueOfLife/Features/Taxon/TaxonHeaderView.swift`. Wrap the scientific-name HStack so the icon sits to the left:

```swift
var body: some View {
    VStack(alignment: .leading, spacing: 6) {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            GroupIcon(code: info.group, size: 28)
                .alignmentGuide(.firstTextBaseline) { d in d[.bottom] - 4 }
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
        }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
}
```

- [ ] **Step 3.6: Add lookup test**

Append to `CatalogueOfLifeTests/TaxGroupVocabTests.swift`:

```swift
@Test("Lookup resolves a code to its canonical group name")
@MainActor
func vocabLookup() throws {
    let data = try FixtureLoader.data("vocab_taxgroup")
    let dtos = try JSONDecoder().decode([TaxGroupVocabDTO].self, from: data)
    let vocab = TaxGroupVocab(groups: dtos.map(TaxGroup.init(dto:)))
    let bacterial = vocab.lookup(code: "bacterial")
    #expect(bacterial != nil)
    #expect(vocab.lookup(code: nil) == nil)
    #expect(vocab.lookup(code: "totally-fake-code") == nil)
}
```

- [ ] **Step 3.7: Run tests + manual sim build**

```bash
xcodegen generate
xcodebuild -scheme CatalogueOfLife -destination 'platform=iOS Simulator,name=iPhone 16e,OS=latest' test -quiet
```
Expected: full suite passes (was 26; now 27 with the new lookup test).

```bash
xcodebuild -scheme CatalogueOfLife -destination 'platform=iOS Simulator,name=iPhone 16e,OS=latest' -configuration Debug -derivedDataPath /tmp/col-mobile-dd build -quiet
APP_PATH=$(find /tmp/col-mobile-dd/Build/Products -name CatalogueOfLife.app -type d | head -1)
SIM_ID=$(xcrun simctl list devices booted -j | python3 -c "import json,sys; d=json.load(sys.stdin); [print(dev['udid']) for runtime in d['devices'] for dev in d['devices'][runtime] if dev.get('state')=='Booted'][0]")
xcrun simctl install "$SIM_ID" "$APP_PATH"
xcrun simctl launch "$SIM_ID" org.catalogueoflife.mobile
sleep 4
xcrun simctl io "$SIM_ID" screenshot /tmp/col-mobile-task3.png
```

In the running app, search for "felis" and verify each row shows the bundled group icon to the left of the scientific name.

- [ ] **Step 3.8: Commit**

```bash
git add CatalogueOfLife CatalogueOfLifeTests
git commit -m "Add GroupIcon component + apply to search results and taxon header"
```

---

## Task 4: Persistence — SwiftData container + Favorite + RecentTaxon models

**Files:**
- Create: `CatalogueOfLife/Persistence/PersistenceStore.swift`
- Create: `CatalogueOfLife/Persistence/Favorite.swift`
- Create: `CatalogueOfLife/Persistence/RecentTaxon.swift`
- Modify: `CatalogueOfLife/App/CatalogueOfLifeApp.swift` — install the `ModelContainer`
- Create: `CatalogueOfLifeTests/PersistenceTests.swift`

- [ ] **Step 4.1: Write `Favorite.swift`**

```swift
import Foundation
import SwiftData

@Model
final class Favorite {
    /// Unique composite identifier: "<datasetKey>:<taxonId>" — SwiftData doesn't support
    /// multi-attribute uniqueness, so we synthesize the key client-side.
    @Attribute(.unique) var compositeKey: String
    var datasetKey: Int
    var taxonId: String
    var name: String
    var authorship: String?
    var rank: String
    var group: String?
    var addedAt: Date

    init(datasetKey: Int, taxonId: String, name: String, authorship: String?, rank: String, group: String?) {
        self.compositeKey = Self.key(datasetKey: datasetKey, taxonId: taxonId)
        self.datasetKey = datasetKey
        self.taxonId = taxonId
        self.name = name
        self.authorship = authorship
        self.rank = rank
        self.group = group
        self.addedAt = Date()
    }

    static func key(datasetKey: Int, taxonId: String) -> String {
        "\(datasetKey):\(taxonId)"
    }
}
```

- [ ] **Step 4.2: Write `RecentTaxon.swift`**

```swift
import Foundation
import SwiftData

@Model
final class RecentTaxon {
    @Attribute(.unique) var compositeKey: String
    var datasetKey: Int
    var taxonId: String
    var name: String
    var rank: String
    var group: String?
    var lastVisited: Date

    init(datasetKey: Int, taxonId: String, name: String, rank: String, group: String?) {
        self.compositeKey = Favorite.key(datasetKey: datasetKey, taxonId: taxonId)
        self.datasetKey = datasetKey
        self.taxonId = taxonId
        self.name = name
        self.rank = rank
        self.group = group
        self.lastVisited = Date()
    }
}
```

- [ ] **Step 4.3: Write `PersistenceStore.swift`**

```swift
import Foundation
import SwiftData

enum PersistenceStore {
    /// On-disk schema for the app.
    @MainActor
    static let shared: ModelContainer = {
        let schema = Schema([Favorite.self, RecentTaxon.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create persistent ModelContainer: \(error)")
        }
    }()

    /// In-memory container for tests. Each call returns a fresh container.
    @MainActor
    static func makeInMemory() -> ModelContainer {
        let schema = Schema([Favorite.self, RecentTaxon.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [config])
    }

    /// Caps the RecentTaxon table at 50 entries by evicting the oldest.
    static let recentsCap = 50

    /// Upserts a `RecentTaxon` row (touches `lastVisited`) and evicts the oldest entries
    /// beyond `recentsCap`.
    @MainActor
    static func bumpRecent(_ context: ModelContext,
                            datasetKey: Int,
                            taxonId: String,
                            name: String,
                            rank: String,
                            group: String?) {
        let key = Favorite.key(datasetKey: datasetKey, taxonId: taxonId)
        let descriptor = FetchDescriptor<RecentTaxon>(predicate: #Predicate { $0.compositeKey == key })
        if let existing = try? context.fetch(descriptor).first {
            existing.lastVisited = Date()
            existing.name = name
            existing.rank = rank
            existing.group = group
        } else {
            let row = RecentTaxon(datasetKey: datasetKey, taxonId: taxonId, name: name, rank: rank, group: group)
            context.insert(row)
        }
        try? context.save()
        evictOldRecents(context)
    }

    @MainActor
    private static func evictOldRecents(_ context: ModelContext) {
        var fd = FetchDescriptor<RecentTaxon>(sortBy: [SortDescriptor(\.lastVisited, order: .reverse)])
        fd.fetchLimit = 0
        guard let all = try? context.fetch(fd) else { return }
        guard all.count > recentsCap else { return }
        for row in all[recentsCap...] {
            context.delete(row)
        }
        try? context.save()
    }
}
```

- [ ] **Step 4.4: Inject `ModelContainer` in `CatalogueOfLifeApp.swift`**

```swift
import SwiftUI
import SwiftData

@main
struct CatalogueOfLifeApp: App {
    @State private var state: AppState = AppState(client: APIClientLive())
    @State private var vocab: TaxGroupVocab = TaxGroupVocab.loadBundled()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(state)
                .environment(vocab)
                .modelContainer(PersistenceStore.shared)
                .task(id: "launch") { await state.loadReleases() }
        }
    }
}
```

- [ ] **Step 4.5: Write `PersistenceTests.swift`**

```swift
import Testing
import Foundation
import SwiftData
@testable import CatalogueOfLife

@Suite("Persistence")
@MainActor
struct PersistenceTests {

    private func freshContext() -> ModelContext {
        let container = PersistenceStore.makeInMemory()
        return ModelContext(container)
    }

    @Test("Bumping a new taxon inserts a RecentTaxon row")
    func bumpsNewTaxon() throws {
        let ctx = freshContext()
        PersistenceStore.bumpRecent(ctx, datasetKey: 1, taxonId: "T1", name: "Felis catus", rank: "species", group: "mammals")
        let rows = try ctx.fetch(FetchDescriptor<RecentTaxon>())
        #expect(rows.count == 1)
        #expect(rows.first?.taxonId == "T1")
        #expect(rows.first?.compositeKey == "1:T1")
    }

    @Test("Bumping an existing taxon updates lastVisited (does not duplicate)")
    func bumpsExistingTaxon() async throws {
        let ctx = freshContext()
        PersistenceStore.bumpRecent(ctx, datasetKey: 1, taxonId: "T1", name: "Felis catus", rank: "species", group: nil)
        let firstVisit = try ctx.fetch(FetchDescriptor<RecentTaxon>()).first?.lastVisited
        try await Task.sleep(nanoseconds: 5_000_000)
        PersistenceStore.bumpRecent(ctx, datasetKey: 1, taxonId: "T1", name: "Felis catus", rank: "species", group: "mammals")
        let rows = try ctx.fetch(FetchDescriptor<RecentTaxon>())
        #expect(rows.count == 1)
        #expect((rows.first?.lastVisited ?? Date.distantPast) > (firstVisit ?? Date.distantFuture))
        #expect(rows.first?.group == "mammals")
    }

    @Test("Recents cap at 50: oldest are evicted")
    func capsAtFifty() throws {
        let ctx = freshContext()
        for i in 1...55 {
            PersistenceStore.bumpRecent(ctx, datasetKey: 1, taxonId: "T\(i)", name: "Name\(i)", rank: "species", group: nil)
        }
        let all = try ctx.fetch(FetchDescriptor<RecentTaxon>(sortBy: [SortDescriptor(\.lastVisited, order: .reverse)]))
        #expect(all.count == 50)
        // Evicted entries are the first 5 inserted (T1…T5).
        let ids = Set(all.map(\.taxonId))
        #expect(!ids.contains("T1"))
        #expect(!ids.contains("T5"))
        #expect(ids.contains("T6"))
    }

    @Test("Favorite uniqueness via composite key")
    func favoriteUniqueness() throws {
        let ctx = freshContext()
        ctx.insert(Favorite(datasetKey: 1, taxonId: "T1", name: "Felis", authorship: nil, rank: "species", group: nil))
        ctx.insert(Favorite(datasetKey: 1, taxonId: "T1", name: "Felis", authorship: nil, rank: "species", group: nil))
        // SwiftData's unique constraint should fail on the second insert at save time.
        do { try ctx.save() } catch {
            // Expected — uniqueness enforced
            return
        }
        let rows = try ctx.fetch(FetchDescriptor<Favorite>())
        #expect(rows.count == 1, "Expected uniqueness on compositeKey")
    }

    @Test("Same taxon id in different datasets are distinct favorites")
    func datasetScopedFavorites() throws {
        let ctx = freshContext()
        ctx.insert(Favorite(datasetKey: 1, taxonId: "T1", name: "Felis", authorship: nil, rank: "species", group: nil))
        ctx.insert(Favorite(datasetKey: 2, taxonId: "T1", name: "Felis", authorship: nil, rank: "species", group: nil))
        try ctx.save()
        let rows = try ctx.fetch(FetchDescriptor<Favorite>())
        #expect(rows.count == 2)
    }
}
```

- [ ] **Step 4.6: Run tests**

```bash
xcodegen generate
xcodebuild -scheme CatalogueOfLife -destination 'platform=iOS Simulator,name=iPhone 16e,OS=latest' test -only-testing:CatalogueOfLifeTests/PersistenceTests -quiet
```
Expected: 5 tests pass.

- [ ] **Step 4.7: Commit**

```bash
git add CatalogueOfLife CatalogueOfLifeTests
git commit -m "Add SwiftData Favorite/RecentTaxon models + container + persistence tests"
```

---

## Task 5: Star toggle + recents bumping on TaxonDetailView

**Files:**
- Modify: `CatalogueOfLife/Features/Taxon/TaxonDetailView.swift` — add a star button in the toolbar; bump recents after a successful load
- Modify: `CatalogueOfLife/Features/Taxon/TaxonDetailViewModel.swift` — surface the loaded taxon for the view to consume in the bump call (no functional change)

The bump happens in the view via the SwiftData environment (the VM stays pure and doesn't depend on `ModelContext`).

- [ ] **Step 5.1: Modify `TaxonDetailView.swift`**

```swift
import SwiftUI
import SwiftData

struct TaxonDetailView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query private var favorites: [Favorite]
    let taxonId: String
    @State private var vm: TaxonDetailViewModel?
    @State private var navigateTo: String?

    init(taxonId: String) {
        self.taxonId = taxonId
        // Filter favorites by this taxon's composite key — we don't know datasetKey here,
        // but we'll match on taxonId + datasetKey filtered by the @State VM result.
        // Simpler: query all favorites, filter in body.
    }

    private var isFavorite: Bool {
        guard let key = appState.selectedDataset?.key else { return false }
        return favorites.contains { $0.compositeKey == Favorite.key(datasetKey: key, taxonId: taxonId) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                switch vm?.state {
                case .loaded(let info):
                    TaxonHeaderView(
                        info: info,
                        preferredVernacular: info.preferredVernacular(language: appState.effectiveVernacularLanguage)
                    )
                    ClassificationChipsView(items: info.classification) { item in
                        navigateTo = item.id
                    }
                    SynonymyView(groups: info.synonymyGroups)
                    VernacularNamesView(
                        names: info.vernacularNames,
                        preferredLanguage: appState.effectiveVernacularLanguage
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
        .toolbar {
            ToolbarItem(placement: .principal) { ReleasePicker() }
            ToolbarItem(placement: .topBarTrailing) {
                if case let .loaded(info) = vm?.state {
                    HStack(spacing: 8) {
                        Button {
                            toggleFavorite(info)
                        } label: {
                            Image(systemName: isFavorite ? "star.fill" : "star")
                                .foregroundStyle(isFavorite ? .yellow : .secondary)
                        }
                        .accessibilityLabel(isFavorite ? "Remove from favorites" : "Add to favorites")
                        Text("COL:\(info.taxonId)")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }
        }
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
            // After a successful load, bump recents
            if case let .loaded(info) = vm?.state, let key = appState.selectedDataset?.key {
                PersistenceStore.bumpRecent(modelContext,
                                             datasetKey: key,
                                             taxonId: info.taxonId,
                                             name: info.scientificName,
                                             rank: info.rank.rawValue,
                                             group: info.group)
            }
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

    private func toggleFavorite(_ info: TaxonInfo) {
        guard let key = appState.selectedDataset?.key else { return }
        let composite = Favorite.key(datasetKey: key, taxonId: info.taxonId)
        if let existing = favorites.first(where: { $0.compositeKey == composite }) {
            modelContext.delete(existing)
        } else {
            let fav = Favorite(datasetKey: key,
                                taxonId: info.taxonId,
                                name: info.scientificName,
                                authorship: info.authorship,
                                rank: info.rank.rawValue,
                                group: info.group)
            modelContext.insert(fav)
        }
        try? modelContext.save()
    }
}
```

- [ ] **Step 5.2: Build to confirm no warnings**

```bash
xcodegen generate
xcodebuild -scheme CatalogueOfLife -destination 'platform=iOS Simulator,name=iPhone 16e,OS=latest' build -quiet
```

- [ ] **Step 5.3: Run full suite**

```bash
xcodebuild -scheme CatalogueOfLife -destination 'platform=iOS Simulator,name=iPhone 16e,OS=latest' test -quiet
```
Expected: tests still pass (~32 now: 27 + 5 persistence).

- [ ] **Step 5.4: Manual sim test**

Install + launch. Search "Felis catus", tap result, tap star icon, kill the app, relaunch, navigate back to the same taxon, confirm the star is filled.

```bash
xcodebuild -scheme CatalogueOfLife -destination 'platform=iOS Simulator,name=iPhone 16e,OS=latest' -configuration Debug -derivedDataPath /tmp/col-mobile-dd build -quiet
APP_PATH=$(find /tmp/col-mobile-dd/Build/Products -name CatalogueOfLife.app -type d | head -1)
SIM_ID=$(xcrun simctl list devices booted -j | python3 -c "import json,sys; d=json.load(sys.stdin); [print(dev['udid']) for runtime in d['devices'] for dev in d['devices'][runtime] if dev.get('state')=='Booted'][0]")
xcrun simctl install "$SIM_ID" "$APP_PATH"
xcrun simctl launch "$SIM_ID" org.catalogueoflife.mobile
sleep 4
```

- [ ] **Step 5.5: Commit**

```bash
git add CatalogueOfLife
git commit -m "Add favorite-toggle star + recents bumping on TaxonDetailView"
```

---

## Task 6: FavoritesSheet

A sheet showing two segments — Favorites | Recents — scoped to the current dataset, with a footer showing the count of favorites in other releases.

**Files:**
- Create: `CatalogueOfLife/Features/Favorites/FavoritesSheet.swift`
- Create: `CatalogueOfLife/Features/Favorites/FavoritesSheetViewModel.swift`
- Create: `CatalogueOfLifeTests/FavoritesSheetViewModelTests.swift`

- [ ] **Step 6.1: Write `FavoritesSheetViewModel.swift`**

```swift
import Foundation
import Observation

@MainActor
@Observable
final class FavoritesSheetViewModel {
    enum Segment: String, CaseIterable, Sendable { case favorites = "Favorites", recents = "Recents" }
    var segment: Segment = .favorites

    private(set) var datasetFavoritesCount: Int = 0
    private(set) var otherDatasetFavoritesCount: Int = 0

    /// Splits favorites into current-dataset and other-dataset buckets.
    func update(favorites: [Favorite], currentDatasetKey: Int?) {
        guard let key = currentDatasetKey else {
            datasetFavoritesCount = 0
            otherDatasetFavoritesCount = favorites.count
            return
        }
        datasetFavoritesCount = favorites.filter { $0.datasetKey == key }.count
        otherDatasetFavoritesCount = favorites.count - datasetFavoritesCount
    }
}
```

- [ ] **Step 6.2: Write `FavoritesSheet.swift`**

```swift
import SwiftUI
import SwiftData

struct FavoritesSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Favorite.addedAt, order: .reverse) private var favorites: [Favorite]
    @Query(sort: \RecentTaxon.lastVisited, order: .reverse) private var recents: [RecentTaxon]

    @State private var vm = FavoritesSheetViewModel()
    @State private var navigateTo: String?

    private var currentKey: Int? { appState.selectedDataset?.key }
    private var datasetFavorites: [Favorite] { favorites.filter { $0.datasetKey == currentKey } }
    private var datasetRecents: [RecentTaxon] { recents.filter { $0.datasetKey == currentKey } }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("View", selection: $vm.segment) {
                    ForEach(FavoritesSheetViewModel.Segment.allCases, id: \.self) { seg in
                        Text(seg.rawValue).tag(seg)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                Group {
                    switch vm.segment {
                    case .favorites: favoritesList
                    case .recents: recentsList
                    }
                }
            }
            .navigationTitle("Bookmarks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .navigationDestination(item: $navigateTo) { id in
                TaxonDetailView(taxonId: id)
            }
        }
        .task { vm.update(favorites: favorites, currentDatasetKey: currentKey) }
        .onChange(of: favorites) { vm.update(favorites: $1, currentDatasetKey: currentKey) }
        .onChange(of: currentKey) { _, _ in vm.update(favorites: favorites, currentDatasetKey: currentKey) }
    }

    @ViewBuilder
    private var favoritesList: some View {
        if datasetFavorites.isEmpty {
            ContentUnavailableView(
                "No favorites yet",
                systemImage: "star",
                description: Text("Tap the ★ on any taxon page to save it here.")
            )
        } else {
            List(datasetFavorites) { fav in
                Button { navigateTo = fav.taxonId } label: {
                    favRow(fav)
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
            .safeAreaInset(edge: .bottom) {
                if vm.otherDatasetFavoritesCount > 0 {
                    Text("Favorites in other releases (\(vm.otherDatasetFavoritesCount))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .background(.thinMaterial)
                }
            }
        }
    }

    @ViewBuilder
    private var recentsList: some View {
        if datasetRecents.isEmpty {
            ContentUnavailableView(
                "No recents yet",
                systemImage: "clock",
                description: Text("Open a taxon to see it here.")
            )
        } else {
            List(datasetRecents) { row in
                Button { navigateTo = row.taxonId } label: {
                    recentRow(row)
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
        }
    }

    private func favRow(_ fav: Favorite) -> some View {
        HStack(alignment: .top, spacing: 8) {
            GroupIcon(code: fav.group, size: 22).padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(fav.name).italic()
                Text(fav.rank.capitalized).font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private func recentRow(_ row: RecentTaxon) -> some View {
        HStack(alignment: .top, spacing: 8) {
            GroupIcon(code: row.group, size: 22).padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.name).italic()
                Text(row.rank.capitalized).font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}
```

- [ ] **Step 6.3: Write VM tests**

`CatalogueOfLifeTests/FavoritesSheetViewModelTests.swift`:

```swift
import Testing
@testable import CatalogueOfLife

@Suite("FavoritesSheetViewModel")
@MainActor
struct FavoritesSheetViewModelTests {

    private func fav(datasetKey: Int, taxonId: String) -> Favorite {
        Favorite(datasetKey: datasetKey, taxonId: taxonId, name: "X", authorship: nil, rank: "species", group: nil)
    }

    @Test("Splits favorites into current-dataset vs other buckets")
    func splitsByDataset() {
        let vm = FavoritesSheetViewModel()
        let favorites = [fav(datasetKey: 1, taxonId: "A"), fav(datasetKey: 1, taxonId: "B"), fav(datasetKey: 2, taxonId: "C")]
        vm.update(favorites: favorites, currentDatasetKey: 1)
        #expect(vm.datasetFavoritesCount == 2)
        #expect(vm.otherDatasetFavoritesCount == 1)
    }

    @Test("Counts all as 'other' when no current dataset")
    func noCurrentDataset() {
        let vm = FavoritesSheetViewModel()
        vm.update(favorites: [fav(datasetKey: 1, taxonId: "A")], currentDatasetKey: nil)
        #expect(vm.datasetFavoritesCount == 0)
        #expect(vm.otherDatasetFavoritesCount == 1)
    }
}
```

- [ ] **Step 6.4: Run tests**

```bash
xcodegen generate
xcodebuild -scheme CatalogueOfLife -destination 'platform=iOS Simulator,name=iPhone 16e,OS=latest' test -only-testing:CatalogueOfLifeTests/FavoritesSheetViewModelTests -quiet
```
Expected: 2 tests pass.

- [ ] **Step 6.5: Commit**

```bash
git add CatalogueOfLife/Features/Favorites CatalogueOfLifeTests/FavoritesSheetViewModelTests.swift
git commit -m "Add FavoritesSheet with segmented Favorites/Recents + other-release footer"
```

---

## Task 7: Tree, Suggest, Classification endpoints

Three endpoint additions in one task — same network pattern, similar DTOs.

**Files:**
- Create: `CatalogueOfLife/Models/DTOs/TreeNodeDTO.swift`
- Create: `CatalogueOfLife/Models/DTOs/SuggestEntryDTO.swift`
- Create: `CatalogueOfLife/Models/DTOs/ClassificationEntryDTO.swift`
- Create: `CatalogueOfLife/Models/Domain/TreeNode.swift`
- Create: `CatalogueOfLife/Models/Domain/TaxonSuggestion.swift`
- Modify: `CatalogueOfLife/Networking/Endpoints.swift` — add 3 builders
- Modify: `CatalogueOfLife/Networking/APIClient.swift` — add 3 methods to protocol
- Modify: `CatalogueOfLife/Networking/APIClientLive.swift` — implement 3 methods
- Modify: `CatalogueOfLifeTests/Helpers/StubAPIClient.swift` — add 3 stub maps
- Create: `CatalogueOfLifeTests/Fixtures/tree_root.json`, `tree_children.json`, `suggest_felis.json`, `classification_felis_catus.json`
- Create: `CatalogueOfLifeTests/TreeDecodingTests.swift`, `SuggestDecodingTests.swift`, `ClassificationDecodingTests.swift`

- [ ] **Step 7.1: Capture fixtures**

```bash
TID=$(curl -s 'https://api.checklistbank.org/dataset/3LXR/nameusage/search?q=Felis+catus&limit=1' | python3 -c "import json,sys; print(json.load(sys.stdin)['result'][0]['usage']['id'])")

curl -s 'https://api.checklistbank.org/dataset/3LXR/tree?limit=10'           | python3 -m json.tool > CatalogueOfLifeTests/Fixtures/tree_root.json
curl -s 'https://api.checklistbank.org/dataset/3LXR/tree/CRLT8/children?limit=10' | python3 -m json.tool > CatalogueOfLifeTests/Fixtures/tree_children.json
curl -s 'https://api.checklistbank.org/dataset/3LXR/nameusage/suggest?q=felis'   | python3 -m json.tool > CatalogueOfLifeTests/Fixtures/suggest_felis.json
curl -s "https://api.checklistbank.org/dataset/3LXR/taxon/$TID/classification"   | python3 -m json.tool > CatalogueOfLifeTests/Fixtures/classification_felis_catus.json

for f in tree_root tree_children suggest_felis classification_felis_catus; do
  echo "=== $f ==="
  python3 -c "
import json
d = json.load(open('CatalogueOfLifeTests/Fixtures/$f.json'))
if isinstance(d, list):
    print('  array, len:', len(d))
    if d: print('  first keys:', sorted(d[0].keys()))
else:
    print('  dict keys:', sorted(d.keys()))
    if 'result' in d and d['result']: print('  first result keys:', sorted(d['result'][0].keys()))
"
done
```
Confirm:
- `tree_root` and `tree_children` both have `result` with entries having `id, rank, status, name, count, childCount`
- `suggest_felis` is a flat array with entries having `match, context, usageId, rank, status, group, suggestion`
- `classification_felis_catus` is a flat array with entries having `id, name, rank, authorship`

- [ ] **Step 7.2: Write `TreeNodeDTO.swift`**

```swift
import Foundation

struct TreeNodeDTO: Decodable, Sendable {
    let id: String
    let parentId: String?
    let name: String
    let authorship: String?
    let rank: String?
    let status: String?
    let count: Int?
    let childCount: Int?
}
```

- [ ] **Step 7.3: Write `SuggestEntryDTO.swift`**

```swift
import Foundation

struct SuggestEntryDTO: Decodable, Sendable {
    let match: String?
    let context: String?
    let usageId: String
    let rank: String?
    let status: String?
    let group: String?
    let suggestion: String
}
```

- [ ] **Step 7.4: Write `ClassificationEntryDTO.swift`**

```swift
import Foundation

struct ClassificationEntryDTO: Decodable, Sendable {
    let id: String
    let name: String
    let rank: String?
    let authorship: String?
}
```

- [ ] **Step 7.5: Write `TreeNode.swift`** (domain)

```swift
import Foundation

struct TreeNode: Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    let authorship: String?
    let rank: Rank
    let status: TaxonStatus
    let count: Int
    let childCount: Int

    var isLeaf: Bool { childCount == 0 }
}

extension TreeNode {
    init(dto: TreeNodeDTO) {
        self.init(
            id: dto.id,
            name: dto.name,
            authorship: dto.authorship,
            rank: Rank(apiValue: dto.rank),
            status: TaxonStatus(apiValue: dto.status),
            count: dto.count ?? 0,
            childCount: dto.childCount ?? 0
        )
    }
}
```

- [ ] **Step 7.6: Write `TaxonSuggestion.swift`** (domain)

```swift
import Foundation

struct TaxonSuggestion: Equatable, Identifiable, Sendable {
    let id: String                 // == usageId
    let scientificName: String     // == match
    let context: String?           // parent or family hint
    let rank: Rank
    let group: String?
    let suggestion: String         // display string from API
}

extension TaxonSuggestion {
    init(dto: SuggestEntryDTO) {
        self.init(
            id: dto.usageId,
            scientificName: dto.match ?? "",
            context: dto.context,
            rank: Rank(apiValue: dto.rank),
            group: dto.group,
            suggestion: dto.suggestion
        )
    }
}
```

- [ ] **Step 7.7: Add Endpoints**

In `CatalogueOfLife/Networking/Endpoints.swift`, add (note: dataset can be Int or alias):

```swift
static func treeChildren(datasetKey: Int, parentId: String?, limit: Int = 100) -> URL {
    var path = "dataset/\(datasetKey)/tree"
    if let parentId { path += "/\(parentId)/children" }
    var c = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false)!
    c.queryItems = [URLQueryItem(name: "limit", value: String(limit))]
    return c.url!
}

static func suggest(datasetKey: Int, q: String, limit: Int = 15) -> URL {
    var c = URLComponents(
        url: baseURL.appending(path: "dataset/\(datasetKey)/nameusage/suggest"),
        resolvingAgainstBaseURL: false
    )!
    c.queryItems = [
        URLQueryItem(name: "q", value: q),
        URLQueryItem(name: "limit", value: String(limit))
    ]
    return c.url!
}

static func classification(datasetKey: Int, taxonId: String) -> URL {
    baseURL
        .appending(path: "dataset")
        .appending(path: "\(datasetKey)")
        .appending(path: "taxon")
        .appending(path: taxonId)
        .appending(path: "classification")
}
```

- [ ] **Step 7.8: Extend `APIClient` protocol**

Add to `CatalogueOfLife/Networking/APIClient.swift`:

```swift
protocol APIClient: Sendable {
    func getDataset(_ keyOrAlias: String) async throws -> DatasetRef
    func listReleases() async throws -> [DatasetRef]
    func searchNames(datasetKey: Int, q: String) async throws -> [SearchHit]
    func getTaxonInfo(datasetKey: Int, taxonId: String) async throws -> TaxonInfo

    // Plan 2 additions:
    func getTreeChildren(datasetKey: Int, parentId: String?) async throws -> [TreeNode]
    func suggest(datasetKey: Int, q: String) async throws -> [TaxonSuggestion]
    func getClassification(datasetKey: Int, taxonId: String) async throws -> [ClassificationItem]
}
```

- [ ] **Step 7.9: Implement in `APIClientLive.swift`**

```swift
func getTreeChildren(datasetKey: Int, parentId: String?) async throws -> [TreeNode] {
    let url = Endpoints.treeChildren(datasetKey: datasetKey, parentId: parentId)
    let paged = try await getJSON(url, as: PagedDTO<TreeNodeDTO>.self)
    return paged.result.map(TreeNode.init(dto:))
}

func suggest(datasetKey: Int, q: String) async throws -> [TaxonSuggestion] {
    let url = Endpoints.suggest(datasetKey: datasetKey, q: q)
    let dtos = try await getJSON(url, as: [SuggestEntryDTO].self)
    return dtos.map(TaxonSuggestion.init(dto:))
}

func getClassification(datasetKey: Int, taxonId: String) async throws -> [ClassificationItem] {
    let url = Endpoints.classification(datasetKey: datasetKey, taxonId: taxonId)
    let dtos = try await getJSON(url, as: [ClassificationEntryDTO].self)
    return dtos.map { ClassificationItem(id: $0.id, name: $0.name, rank: Rank(apiValue: $0.rank)) }
}
```

- [ ] **Step 7.10: Extend `StubAPIClient`**

```swift
final class StubAPIClient: APIClient, @unchecked Sendable {
    var releases: [DatasetRef] = []
    var datasetByKey: [String: DatasetRef] = [:]
    var searchResults: [String: [SearchHit]] = [:]
    var taxonInfo: [String: TaxonInfo] = [:]
    var treeChildren: [String: [TreeNode]] = [:]              // key: parentId ?? "root"
    var suggestions: [String: [TaxonSuggestion]] = [:]
    var classifications: [String: [ClassificationItem]] = [:]
    var error: APIError?

    func getDataset(_ keyOrAlias: String) async throws -> DatasetRef { /* existing */ ... }
    func listReleases() async throws -> [DatasetRef]              { /* existing */ ... }
    func searchNames(datasetKey: Int, q: String) async throws -> [SearchHit] { /* existing */ ... }
    func getTaxonInfo(datasetKey: Int, taxonId: String) async throws -> TaxonInfo { /* existing */ ... }

    func getTreeChildren(datasetKey: Int, parentId: String?) async throws -> [TreeNode] {
        if let error { throw error }
        return treeChildren[parentId ?? "root"] ?? []
    }
    func suggest(datasetKey: Int, q: String) async throws -> [TaxonSuggestion] {
        if let error { throw error }
        return suggestions[q] ?? []
    }
    func getClassification(datasetKey: Int, taxonId: String) async throws -> [ClassificationItem] {
        if let error { throw error }
        return classifications[taxonId] ?? []
    }
}
```

(Keep the existing method bodies; only add the three new ones.)

- [ ] **Step 7.11: Write decoding tests**

`CatalogueOfLifeTests/TreeDecodingTests.swift`:

```swift
import Testing
import Foundation
@testable import CatalogueOfLife

@Suite("Tree decoding")
struct TreeDecodingTests {
    @Test("Root tree response decodes into TreeNodes")
    func decodesRoot() throws {
        let data = try FixtureLoader.data("tree_root")
        let paged = try JSONDecoder().decode(PagedDTO<TreeNodeDTO>.self, from: data)
        let nodes = paged.result.map(TreeNode.init(dto:))
        #expect(!nodes.isEmpty)
        #expect(nodes.allSatisfy { $0.id.count > 0 })
    }

    @Test("Children response decodes the same shape")
    func decodesChildren() throws {
        let data = try FixtureLoader.data("tree_children")
        let paged = try JSONDecoder().decode(PagedDTO<TreeNodeDTO>.self, from: data)
        let nodes = paged.result.map(TreeNode.init(dto:))
        #expect(!nodes.isEmpty)
    }
}
```

`CatalogueOfLifeTests/SuggestDecodingTests.swift`:

```swift
import Testing
import Foundation
@testable import CatalogueOfLife

@Suite("Suggest decoding")
struct SuggestDecodingTests {
    @Test("Suggest response decodes into TaxonSuggestion list")
    func decodes() throws {
        let data = try FixtureLoader.data("suggest_felis")
        let dtos = try JSONDecoder().decode([SuggestEntryDTO].self, from: data)
        let suggestions = dtos.map(TaxonSuggestion.init(dto:))
        #expect(!suggestions.isEmpty)
        #expect(suggestions.contains { $0.scientificName.localizedCaseInsensitiveContains("Felis") })
    }
}
```

`CatalogueOfLifeTests/ClassificationDecodingTests.swift`:

```swift
import Testing
import Foundation
@testable import CatalogueOfLife

@Suite("Classification decoding")
struct ClassificationDecodingTests {
    @Test("Classification array decodes ordered root → parent")
    func decodes() throws {
        let data = try FixtureLoader.data("classification_felis_catus")
        let dtos = try JSONDecoder().decode([ClassificationEntryDTO].self, from: data)
        let items = dtos.map { ClassificationItem(id: $0.id, name: $0.name, rank: Rank(apiValue: $0.rank)) }
        #expect(!items.isEmpty)
        // Should start with a high rank (kingdom or domain) and end with genus (immediate parent of species).
        #expect(items.first?.rank == .domain || items.first?.rank == .kingdom)
        #expect(items.last?.rank == .genus)
    }
}
```

- [ ] **Step 7.12: Run tests**

```bash
xcodegen generate
xcodebuild -scheme CatalogueOfLife -destination 'platform=iOS Simulator,name=iPhone 16e,OS=latest' test -quiet
```
Expected: full suite passes (~37 now: 32 + 5 new decoding tests).

- [ ] **Step 7.13: Commit**

```bash
git add CatalogueOfLife CatalogueOfLifeTests
git commit -m "Add tree, suggest, classification endpoints + DTOs + decoding tests"
```

---

## Task 8: TreeView + TreeViewModel + TreeRowView

The Tree tab pushes children onto a NavigationStack one level at a time. Tap a leaf row → push `TaxonDetailView`. Tap a non-leaf → push another `TreeView` rooted at that taxon.

**Files:**
- Create: `CatalogueOfLife/Features/Tree/TreeViewModel.swift`
- Create: `CatalogueOfLife/Features/Tree/TreeView.swift`
- Create: `CatalogueOfLife/Features/Tree/TreeRowView.swift`
- Create: `CatalogueOfLifeTests/TreeViewModelTests.swift`

- [ ] **Step 8.1: Write `TreeViewModel.swift`**

```swift
import Foundation
import Observation

@MainActor
@Observable
final class TreeViewModel {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded([TreeNode])
        case failed(APIError)
    }

    let parentId: String?
    let parentName: String?
    private(set) var state: LoadState = .idle

    private let client: APIClient
    private let getDatasetKey: @MainActor () -> Int?

    init(parentId: String?,
         parentName: String?,
         client: APIClient,
         getDatasetKey: @escaping @MainActor () -> Int?) {
        self.parentId = parentId
        self.parentName = parentName
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
            let nodes = try await client.getTreeChildren(datasetKey: key, parentId: parentId)
            state = .loaded(nodes)
        } catch let err as APIError {
            state = .failed(err)
        } catch {
            state = .failed(.server(status: -1))
        }
    }
}
```

- [ ] **Step 8.2: Write `TreeRowView.swift`**

```swift
import SwiftUI

struct TreeRowView: View {
    let node: TreeNode

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            GroupIcon(code: nil, size: 22)        // GroupIcon resolves only if we have a group; tree endpoint omits it, so this renders nothing today. Placeholder for future enrichment.
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline) {
                    Text(node.name).italic().font(.body)
                    if let auth = node.authorship {
                        Text(auth).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(node.rank.rawValue.capitalized)
                        .font(.caption2)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(.thinMaterial, in: Capsule())
                }
                HStack(spacing: 8) {
                    if !node.isLeaf {
                        Label("\(node.childCount)", systemImage: "chevron.right.2")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Text("\(node.count) descendants")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            }
        }
    }
}
```

> Note: `/tree` doesn't return a `group` field on nodes today, so the `GroupIcon(code: nil, ...)` renders nothing. The slot is kept so a future Plan 2.1 or Plan 3 can request the field if the API adds it.

- [ ] **Step 8.3: Write `TreeView.swift`**

```swift
import SwiftUI

struct TreeView: View {
    @Environment(AppState.self) private var appState
    let rootParentId: String?         // nil = dataset root
    let rootParentName: String?       // for the nav title
    @State private var vm: TreeViewModel?
    @State private var nextParentId: String?      // for non-leaf pushes
    @State private var nextParentName: String?
    @State private var nextLeafId: String?        // for leaf → TaxonDetailView

    init(rootParentId: String? = nil, rootParentName: String? = nil) {
        self.rootParentId = rootParentId
        self.rootParentName = rootParentName
    }

    var body: some View {
        content
            .navigationTitle(rootParentName ?? "Tree")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .principal) { ReleasePicker() } }
            .navigationDestination(item: $nextParentId) { id in
                TreeView(rootParentId: id, rootParentName: nextParentName)
            }
            .navigationDestination(item: $nextLeafId) { id in
                TaxonDetailView(taxonId: id)
            }
            .task {
                if vm == nil {
                    vm = TreeViewModel(parentId: rootParentId,
                                        parentName: rootParentName,
                                        client: APIClientLive(),
                                        getDatasetKey: { [appState] in appState.selectedDataset?.key })
                }
                await vm?.load()
            }
    }

    @ViewBuilder
    private var content: some View {
        switch vm?.state {
        case .loaded(let nodes):
            if nodes.isEmpty {
                ContentUnavailableView("No children", systemImage: "tree", description: Text("This taxon has no listed descendants in the current release."))
            } else {
                List(nodes) { node in
                    Button {
                        if node.isLeaf {
                            nextLeafId = node.id
                        } else {
                            nextParentName = node.name
                            nextParentId = node.id
                        }
                    } label: {
                        TreeRowView(node: node)
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
            }
        case .failed(let err):
            VStack(spacing: 8) {
                Text("Couldn't load tree").font(.headline)
                Text(String(describing: err)).foregroundStyle(.secondary).font(.caption)
                Button("Retry") { Task { await vm?.load() } }.buttonStyle(.bordered)
            }
        case .loading, .idle, .none:
            ProgressView()
        }
    }
}
```

- [ ] **Step 8.4: Write VM tests**

`CatalogueOfLifeTests/TreeViewModelTests.swift`:

```swift
import Testing
import Foundation
@testable import CatalogueOfLife

@Suite("TreeViewModel")
@MainActor
struct TreeViewModelTests {
    @Test("Loads root nodes from client")
    func loadsRoot() async {
        let stub = StubAPIClient()
        stub.treeChildren["root"] = [
            TreeNode(id: "K1", name: "Animalia", authorship: nil, rank: .kingdom, status: .accepted, count: 100, childCount: 5)
        ]
        let vm = TreeViewModel(parentId: nil, parentName: nil, client: stub, getDatasetKey: { 9837 })
        await vm.load()
        if case let .loaded(nodes) = vm.state {
            #expect(nodes.first?.name == "Animalia")
        } else {
            Issue.record("Expected .loaded; got \(vm.state)")
        }
    }

    @Test("Loads children of a specific parent")
    func loadsChildren() async {
        let stub = StubAPIClient()
        stub.treeChildren["K1"] = [
            TreeNode(id: "P1", name: "Chordata", authorship: nil, rank: .phylum, status: .accepted, count: 10, childCount: 3)
        ]
        let vm = TreeViewModel(parentId: "K1", parentName: "Animalia", client: stub, getDatasetKey: { 9837 })
        await vm.load()
        if case let .loaded(nodes) = vm.state {
            #expect(nodes.first?.rank == .phylum)
        } else {
            Issue.record("Expected .loaded")
        }
    }

    @Test("Server error surfaces as .failed")
    func errorSurfaces() async {
        let stub = StubAPIClient()
        stub.error = .server(status: 500)
        let vm = TreeViewModel(parentId: nil, parentName: nil, client: stub, getDatasetKey: { 9837 })
        await vm.load()
        #expect(vm.state == .failed(.server(status: 500)))
    }
}
```

- [ ] **Step 8.5: Run tests**

```bash
xcodegen generate
xcodebuild -scheme CatalogueOfLife -destination 'platform=iOS Simulator,name=iPhone 16e,OS=latest' test -only-testing:CatalogueOfLifeTests/TreeViewModelTests -quiet
```
Expected: 3 tests pass.

- [ ] **Step 8.6: Commit**

```bash
git add CatalogueOfLife/Features/Tree CatalogueOfLifeTests/TreeViewModelTests.swift
git commit -m "Add TreeView/TreeViewModel/TreeRowView for child-by-child taxonomy browsing"
```

---

## Task 9: SuggestField — debounced suggest + classification-based jump

The `SuggestField` appears at the top of the root `TreeView`. Selecting a suggestion fires `getClassification` for the picked taxon and the caller pushes the resulting parent chain into the NavigationStack.

**Files:**
- Create: `CatalogueOfLife/Features/Tree/SuggestField.swift`
- Modify: `CatalogueOfLife/Features/Tree/TreeView.swift` — add `SuggestField` as a `safeAreaInset(edge: .top)` on the root only

- [ ] **Step 9.1: Write `SuggestField.swift`**

```swift
import SwiftUI
import Observation

@MainActor
@Observable
final class SuggestFieldViewModel {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded([TaxonSuggestion])
        case failed(APIError)
    }

    var query: String = "" {
        didSet { scheduleSearch() }
    }
    private(set) var state: LoadState = .idle

    private let client: APIClient
    private let getDatasetKey: @MainActor () -> Int?
    private var debounceTask: Task<Void, Never>?

    var debounceMillis: Int = 300

    init(client: APIClient, getDatasetKey: @escaping @MainActor () -> Int?) {
        self.client = client
        self.getDatasetKey = getDatasetKey
    }

    private func scheduleSearch() {
        debounceTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { state = .idle; return }
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(self?.debounceMillis ?? 300) * 1_000_000)
            guard !Task.isCancelled, let self else { return }
            await run(query: trimmed)
        }
    }

    private func run(query: String) async {
        guard let key = getDatasetKey() else { state = .failed(.server(status: -1)); return }
        state = .loading
        do {
            let s = try await client.suggest(datasetKey: key, q: query)
            state = .loaded(s)
        } catch let err as APIError {
            state = .failed(err)
        } catch {
            state = .failed(.server(status: -1))
        }
    }
}

struct SuggestField: View {
    @State private var vm: SuggestFieldViewModel
    let onPick: (TaxonSuggestion) -> Void

    init(client: APIClient, getDatasetKey: @escaping @MainActor () -> Int?, onPick: @escaping (TaxonSuggestion) -> Void) {
        self._vm = State(initialValue: SuggestFieldViewModel(client: client, getDatasetKey: getDatasetKey))
        self.onPick = onPick
    }

    var body: some View {
        @Bindable var vm = vm
        VStack(alignment: .leading, spacing: 0) {
            TextField("Jump to taxon", text: $vm.query)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding(.horizontal)
                .padding(.vertical, 6)
            if case let .loaded(suggestions) = vm.state, !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(suggestions) { s in
                        Button {
                            vm.query = ""
                            onPick(s)
                        } label: {
                            HStack(alignment: .firstTextBaseline) {
                                GroupIcon(code: s.group, size: 18)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(s.suggestion).font(.caption)
                                    if let ctx = s.context {
                                        Text(ctx).font(.caption2).foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding(.horizontal).padding(.vertical, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                }
                .background(.thinMaterial)
            }
        }
    }
}
```

- [ ] **Step 9.2: Modify `TreeView` to host SuggestField at the root**

In `CatalogueOfLife/Features/Tree/TreeView.swift`, change the body to wrap the existing content with a `safeAreaInset` only at the root level (when `rootParentId == nil`):

```swift
var body: some View {
    content
        .navigationTitle(rootParentName ?? "Tree")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .principal) { ReleasePicker() } }
        .safeAreaInset(edge: .top) {
            if rootParentId == nil {
                SuggestField(client: APIClientLive(),
                             getDatasetKey: { [appState] in appState.selectedDataset?.key }) { suggestion in
                    handlePick(suggestion)
                }
            }
        }
        .navigationDestination(item: $nextParentId) { id in
            TreeView(rootParentId: id, rootParentName: nextParentName)
        }
        .navigationDestination(item: $nextLeafId) { id in
            TaxonDetailView(taxonId: id)
        }
        .task {
            if vm == nil {
                vm = TreeViewModel(parentId: rootParentId,
                                    parentName: rootParentName,
                                    client: APIClientLive(),
                                    getDatasetKey: { [appState] in appState.selectedDataset?.key })
            }
            await vm?.load()
        }
}

private func handlePick(_ suggestion: TaxonSuggestion) {
    // For v1, just push the taxon detail directly.
    // (Future: fetch classification and rebuild the navigation path.)
    nextLeafId = suggestion.id
}
```

> **v1 simplification:** picking a suggestion pushes `TaxonDetailView` directly. The plan's full design says "navigate the tree to that taxon's row using the classification helper" — that requires pre-fetching `/classification` and synthetically constructing a `NavigationStack` `path`, which is a non-trivial wiring change. We ship the simpler "open details" behaviour in v1 and defer the in-tree jump to a later iteration. The classification endpoint is still in place; only the UI wiring is deferred.

- [ ] **Step 9.3: Build**

```bash
xcodegen generate
xcodebuild -scheme CatalogueOfLife -destination 'platform=iOS Simulator,name=iPhone 16e,OS=latest' build -quiet
```

- [ ] **Step 9.4: Manual smoke**

Install and launch; in the (still-placeholder, until Task 10) Tree tab, the SuggestField field will only render once the tab swap happens — so this task ships but the visual confirmation lands together with Task 10.

- [ ] **Step 9.5: Commit**

```bash
git add CatalogueOfLife/Features/Tree
git commit -m "Add SuggestField with debounce; pick opens taxon details (in-tree jump deferred)"
```

---

## Task 10: Wire TreeView into RootTabView + FavoritesSheet toolbar button

**Files:**
- Modify: `CatalogueOfLife/App/RootTabView.swift`

- [ ] **Step 10.1: Replace the Tree placeholder**

```swift
import SwiftUI

struct RootTabView: View {
    @State private var showingFavorites = false

    var body: some View {
        TabView {
            NavigationStack {
                TreeView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                showingFavorites = true
                            } label: {
                                Image(systemName: "star.circle")
                            }
                            .accessibilityLabel("Open bookmarks")
                        }
                    }
            }
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
        .sheet(isPresented: $showingFavorites) {
            FavoritesSheet()
        }
    }
}
```

> Note: `TreeView`'s body already has a `.toolbar { ToolbarItem(placement: .principal) }`. The outer NavigationStack's additional `ToolbarItem(placement: .topBarTrailing)` for the bookmarks button combines correctly.

- [ ] **Step 10.2: Build + run + manual smoke**

```bash
xcodegen generate
xcodebuild -scheme CatalogueOfLife -destination 'platform=iOS Simulator,name=iPhone 16e,OS=latest' build -quiet
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name CatalogueOfLife.app -type d -path '*Debug-iphonesimulator*' | head -1)
SIM_ID=$(xcrun simctl list devices booted -j | python3 -c "import json,sys; d=json.load(sys.stdin); [print(dev['udid']) for runtime in d['devices'] for dev in d['devices'][runtime] if dev.get('state')=='Booted'][0]")
xcrun simctl install "$SIM_ID" "$APP_PATH"
xcrun simctl launch "$SIM_ID" org.catalogueoflife.mobile
sleep 4
xcrun simctl io "$SIM_ID" screenshot /tmp/col-mobile-plan2-task10.png
echo "Screenshot at /tmp/col-mobile-plan2-task10.png"
```

In the simulator:
- Tap the Tree tab. After ~2-5s a list of top-level taxa (Archaea, Bacteria, etc.) appears
- The suggest field is at the top
- A star-circle icon is in the top-right of the nav bar; tapping opens the bookmarks sheet
- Typing "felis" in the suggest field shows suggestion rows; tapping one opens the taxon detail page

- [ ] **Step 10.3: Commit**

```bash
git add CatalogueOfLife/App/RootTabView.swift
git commit -m "Wire TreeView into tab 1 + FavoritesSheet toolbar button"
```

---

## Task 11: Plan 2 final checkpoint

- [ ] **Step 11.1: Full test suite**

```bash
xcodegen generate
xcodebuild -scheme CatalogueOfLife -destination 'platform=iOS Simulator,name=iPhone 16e,OS=latest' test -quiet
```
Expected: ~40 tests pass (Plan 1 had 26; Plan 2 adds: 1 TaxGroup, 1 vocab lookup, 5 persistence, 2 FavSheet VM, 2 tree decoding, 1 suggest, 1 classification, 3 tree VM = 16 new = 42 total).

- [ ] **Step 11.2: Push + watch CI**

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
    if r['head_sha'].startswith('$NEW_SHA'[:7]) or '$NEW_SHA'.startswith(r['head_sha'][:7]):
        print(r['status'], r['conclusion'] or '-', r['html_url'])
        break
")
  echo "[$ATTEMPTS/24] $STATUS"
  case "$STATUS" in
    *completed*success*) echo "CI green"; break ;;
    *completed*failure*) echo "CI failed"; break ;;
  esac
  sleep 30
done
```

- [ ] **Step 11.3: End-to-end manual smoke**

In the simulator:
1. Launch app — Tree tab loads top-level taxa with group icons (where available), suggest field at top, star-circle bookmarks button in nav bar
2. Tap "Animalia" → children loaded (Chordata, etc.)
3. Drill down to a leaf taxon → TaxonDetailView with star button in toolbar
4. Tap star → row appears in bookmarks sheet (open via star-circle button)
5. Switch to Search tab, search "Felis catus", verify GroupIcon appears beside results
6. Tap a result, observe recents bumped (visible in bookmarks sheet → Recents segment)
7. Switch release picker to an annual (e.g. COL24) — the Favorites segment now shows only annual-COL24 favorites with the "Favorites in other releases (n)" footer

If any step fails, file a follow-up and fix before declaring Plan 2 complete.

---

## Self-review of this plan against the spec

- **§9 Persistence** — Favorite (Task 4), RecentTaxon (Task 4), bumping (Task 5), star toggle (Task 5), composite key (Task 4), cap at 50 (Task 4). ✓
- **§10 Vernacular preference UI** — Out of Plan 2 scope; storage + display already shipped in Plan 1.5.
- **§11 TaxGroup icons** — vocab + bundled snapshot (Task 1), bundled SVG assets (Task 2), GroupIcon component + applied to SearchRow and TaxonHeaderView (Task 3). FavoritesSheet rows also use GroupIcon (Task 6). Tree rows do NOT today because the API doesn't return `group` on tree nodes — documented in Task 8 Step 8.2.
- **§6 Tab 1 (Tree)** — Browser (Task 8), suggest field (Task 9 — with deferred in-tree jump, documented), FavoritesSheet toolbar button (Task 10). ✓ partial (deferred jump is noted)
- **§5.1 Endpoints** — `getTreeChildren`, `suggest`, `getClassification`, `getTaxGroupVocab` (via bundled snapshot, not runtime fetch). All landed in Task 7 (endpoints) and Tasks 1-2 (vocab bundling). ✓
- **§12 Error handling** — Per-section LoadState in TreeViewModel, SuggestFieldViewModel; inline error banners with retry. ✓
- **§13 Testing** — Decoding tests for all four new endpoints; VM tests for TreeViewModel; Persistence unit tests; VM tests for FavoritesSheetViewModel. ✓
- **§14 CI** — No changes; Plan 1's workflow continues running on every push, including Plan 2 commits.

Type consistency check passes: `TreeNode`, `TaxonSuggestion`, `ClassificationItem` (re-used from Plan 1), `Favorite`, `RecentTaxon`, `TaxGroup`, `TaxGroupVocab`, `GroupIcon` — all named consistently across the tasks they appear in.

No placeholders. Every step has the exact code or command. Manual sim verification is gated behind `xcodebuild build` and the test suite; the in-tree classification jump is explicitly deferred with a justification rather than left as a TBD.
