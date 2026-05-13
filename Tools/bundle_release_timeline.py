#!/usr/bin/env python3
"""Fetch /dataset/{alias}/import + /dataset/{alias} for each named release
and write a release-timeline JSON snapshot bundled into the app.

Re-run when COL releases change. The weekly refresh GH Action runs this too.
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
ALIASES = ["3LXR", "3LR", "COL2025", "COL2024", "COL2023", "COL2022", "COL2021"]
TIMEOUT = 30

def fetch_json(url: str):
    with urllib.request.urlopen(url, timeout=TIMEOUT) as resp:
        return json.load(resp)

def display_name(alias: str) -> str:
    return {
        "3LXR": "Latest",
        "3LR":  "Latest Base",
    }.get(alias, "COL " + alias.replace("COL", ""))

def main() -> int:
    BUNDLE_DIR.mkdir(parents=True, exist_ok=True)

    entries = []
    for alias in ALIASES:
        try:
            dataset = fetch_json(f"{API}/dataset/{alias}")
            imports = fetch_json(f"{API}/dataset/{alias}/import")
        except Exception as exc:
            print(f"  {alias}: skipped ({exc})", file=sys.stderr)
            continue

        if not isinstance(imports, list) or not imports:
            print(f"  {alias}: no import data", file=sys.stderr)
            continue

        latest = imports[0]
        rank_counts = latest.get("taxaByRankCount") or {}
        entries.append({
            "alias": alias,
            "displayName": display_name(alias),
            "datasetKey": dataset.get("key"),
            "issued": dataset.get("issued"),
            "taxonCount": latest.get("taxonCount") or 0,
            "nameCount": latest.get("nameCount") or 0,
            "synonymCount": latest.get("synonymCount") or 0,
            "families": rank_counts.get("family") or 0,
            "genera": rank_counts.get("genus") or 0,
            "species": rank_counts.get("species") or 0,
        })
        print(f"  {alias}: {entries[-1]['issued']}  species={entries[-1]['species']}")

    if not entries:
        print("ERROR: no entries collected", file=sys.stderr)
        return 1

    # Sort chronologically by `issued`.
    entries.sort(key=lambda e: (e.get("issued") or ""))

    OUT_PATH.write_text(json.dumps(entries, indent=2) + "\n")
    print(f"\nWrote {len(entries)} entries → {OUT_PATH}")
    return 0

if __name__ == "__main__":
    sys.exit(main())
