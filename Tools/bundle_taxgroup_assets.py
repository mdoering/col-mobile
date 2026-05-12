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

    bundled_path = BUNDLE_DIR / "taxgroup_vocab.json"
    bundled_path.write_text(json.dumps(vocab, indent=2) + "\n")
    print(f"Wrote bundled vocab snapshot ({len(vocab)} entries) -> {bundled_path}")

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
