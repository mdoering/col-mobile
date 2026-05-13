#!/usr/bin/env python3
"""Fetch /dataset and /dataset/{key}/import for every release + xrelease dataset
and write release_timeline.json with one entry per release.

The runtime chart filters by `origin` to toggle Base vs Extended timelines.
"""
from __future__ import annotations
import json
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BUNDLE_DIR = ROOT / "CatalogueOfLife/Resources/Bundle"
OUT_PATH = BUNDLE_DIR / "release_timeline.json"

API = "https://api.checklistbank.org"
TIMEOUT = 30

def fetch_json(url: str):
    with urllib.request.urlopen(url, timeout=TIMEOUT) as resp:
        return json.load(resp)

def main() -> int:
    BUNDLE_DIR.mkdir(parents=True, exist_ok=True)

    releases = []
    for origin in ["release", "xrelease"]:
        page = fetch_json(f"{API}/dataset?origin={origin}&limit=200")
        for r in (page.get("result") or []):
            # Skip non-public/private/test releases that leak into the listing.
            # The official CoL release of every year has access PUBLIC; user
            # snapshots are PRIVATE or have alias prefixes like "Markus".
            if r.get("access") and r.get("access") != "PUBLIC":
                continue
            title = (r.get("title") or "")
            alias = (r.get("alias") or "")
            if "test" in title.lower() or "test" in alias.lower():
                continue
            releases.append({
                "key": r.get("key"),
                "alias": alias,
                "issued": r.get("issued"),
                "origin": origin,
            })

    entries = []
    for r in releases:
        key = r["key"]
        try:
            imports = fetch_json(f"{API}/dataset/{key}/import")
        except Exception as exc:
            print(f"  {r['alias']} ({key}): import skipped ({exc})", file=sys.stderr)
            continue

        if not isinstance(imports, list) or not imports:
            continue

        latest = imports[0]
        rank_counts = latest.get("taxaByRankCount") or {}
        entries.append({
            "alias": r["alias"],
            "displayName": r["alias"] or str(key),
            "datasetKey": key,
            "issued": r["issued"],
            "origin": r["origin"],
            "taxonCount": latest.get("taxonCount") or 0,
            "nameCount": latest.get("nameCount") or 0,
            "synonymCount": latest.get("synonymCount") or 0,
            "families": rank_counts.get("family") or 0,
            "genera": rank_counts.get("genus") or 0,
            "species": rank_counts.get("species") or 0,
        })
        print(f"  {r['alias']} ({r['origin']}): {r['issued']} species={entries[-1]['species']}")

    if not entries:
        print("ERROR: no entries collected", file=sys.stderr)
        return 1

    entries.sort(key=lambda e: (e.get("issued") or ""))
    OUT_PATH.write_text(json.dumps(entries, indent=2) + "\n")
    print(f"\nWrote {len(entries)} entries → {OUT_PATH}")
    return 0

if __name__ == "__main__":
    sys.exit(main())
