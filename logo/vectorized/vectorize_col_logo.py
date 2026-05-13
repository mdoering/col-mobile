#!/usr/bin/env python3
"""
Vectorize the COL square logo from a raster source.

Strategy:
1. Center-crop source to square; upscale to 2048×2048 with Lanczos.
2. For each quadrant, try KMeans with k=3 colors. If the smallest cluster is
   below NOISE_THRESHOLD (= anti-aliasing noise), fall back to k=2.
3. The most-common cluster = background (drawn as a clean <rect>).
4. Remaining clusters become binary masks → traced individually with potrace.
   `-i` is required so potrace treats white pixels in the mask as foreground.
5. Compose final SVG: 4 <rect>s + N traced overlays per quadrant.

Per quadrant in the canonical COL logo:
  TL (blue):   3 layers - bg, medium-blue cell fills, dark-blue cell outlines
  TR (yellow): 2 layers - olive bg, pale-yellow butterfly
  BL (red):    3 layers - red bg, pale-pink mushroom, mid-pink ring detail
  BR (green):  2 layers - green bg, pale-green leaf venation

Requirements:
    pip install pillow numpy scikit-learn cairosvg
    apt install potrace imagemagick

Usage:
    python vectorize_col_logo.py <input.png|jpg> [out.svg]
"""
import re
import subprocess
import sys
from pathlib import Path
from PIL import Image
import numpy as np
from sklearn.cluster import KMeans

SRC      = sys.argv[1] if len(sys.argv) > 1 else 'col_square_logo.jpg'
OUT_SVG  = sys.argv[2] if len(sys.argv) > 2 else 'col_square_logo.svg'
WORK_DIR = Path('./_work'); WORK_DIR.mkdir(exist_ok=True)
CANVAS   = 2048
HALF     = CANVAS // 2
NOISE_THRESHOLD = 0.05   # cluster smaller than 5% = anti-aliasing, ignore

POSITIONS = {'TL': (0, 0), 'TR': (HALF, 0),
             'BL': (0, HALF), 'BR': (HALF, HALF)}

def cluster_quadrant(region):
    """Return (bg_color, [(layer_color, mask), ...]) sorted by area desc."""
    h, w, _ = region.shape
    px = region.reshape(-1, 3).astype(float)
    km = KMeans(n_clusters=3, n_init=10, random_state=0).fit(px)
    centers = np.clip(km.cluster_centers_, 0, 255).astype(np.uint8)
    counts = np.bincount(km.labels_, minlength=3)
    if counts.min() / counts.sum() < NOISE_THRESHOLD:
        km = KMeans(n_clusters=2, n_init=10, random_state=0).fit(px)
        centers = np.clip(km.cluster_centers_, 0, 255).astype(np.uint8)
        counts = np.bincount(km.labels_, minlength=2)
    order = np.argsort(-counts)
    bg = tuple(int(c) for c in centers[order[0]])
    layers = []
    for label in order[1:]:
        mask = (km.labels_ == label).reshape(h, w).astype(np.uint8) * 255
        layers.append((tuple(int(c) for c in centers[label]), mask))
    return bg, layers

def trace_mask(mask_png, out_svg):
    pbm = mask_png.with_suffix('.pbm')
    subprocess.run(['convert', str(mask_png), '-threshold', '50%', str(pbm)],
                   check=True)
    # -i: invert (treat white pixels as foreground).
    # turdsize/alphamax/opttolerance tuned for clean logo output at 2048 res.
    subprocess.run(['potrace', '-s', '-i', '-o', str(out_svg),
                    '--turdsize', '30',
                    '--alphamax', '1.0',
                    '--opttolerance', '0.2',
                    str(pbm)], check=True)

def hex_(rgb):
    return '#{:02x}{:02x}{:02x}'.format(*rgb)

def main():
    im = Image.open(SRC).convert('RGB')
    w, h = im.size
    sz = min(w, h)
    im = im.crop(((w-sz)//2, (h-sz)//2, (w+sz)//2, (h+sz)//2))
    im = im.resize((CANVAS, CANVAS), Image.LANCZOS)
    arr = np.array(im)

    quad_results = {}
    for name, (tx, ty) in POSITIONS.items():
        region = arr[ty:ty+HALF, tx:tx+HALF]
        bg, layers = cluster_quadrant(region)
        traced = []
        for i, (color, mask) in enumerate(layers):
            mask_path = WORK_DIR / f'mask_{name}_{i}.png'
            svg_path  = WORK_DIR / f'leaf_{name}_{i}.svg'
            Image.fromarray(mask).save(mask_path)
            trace_mask(mask_path, svg_path)
            traced.append((color, svg_path))
        quad_results[name] = {'bg': bg, 'layers': traced}
        layer_str = ' + '.join(hex_(c) for c, _ in traced) if traced else '(none)'
        print(f'  {name}: bg={hex_(bg)}  overlays: {layer_str}')

    out = ['<?xml version="1.0" encoding="UTF-8"?>',
           f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {CANVAS} {CANVAS}" '
           f'width="{CANVAS}" height="{CANVAS}">',
           '<title>Catalogue of Life</title>']
    for name, (tx, ty) in POSITIONS.items():
        out.append(f'<rect x="{tx}" y="{ty}" width="{HALF}" height="{HALF}" '
                   f'fill="{hex_(quad_results[name]["bg"])}"/>')
    for name, (tx, ty) in POSITIONS.items():
        for color, svg_path in quad_results[name]['layers']:
            body = svg_path.read_text()
            g = re.search(r'(<g[^>]*>.*?</g>)', body, re.DOTALL).group(1)
            g = re.sub(r'fill="#[0-9a-fA-F]{6}"', f'fill="{hex_(color)}"', g)
            out.append(f'<g transform="translate({tx},{ty})">{g}</g>')
    out.append('</svg>')

    svg = '\n'.join(out)
    def round_nums(m):
        n = float(m.group())
        return str(int(round(n))) if abs(n - round(n)) < 0.05 else f'{n:.1f}'
    svg = re.sub(r'-?\d+\.\d+', round_nums, svg)
    svg = re.sub(r'\n\s*', '\n', svg)
    Path(OUT_SVG).write_text(svg)
    print(f'\nWrote {OUT_SVG}  ({len(svg)} bytes, {svg.count("<path")} paths)')

if __name__ == '__main__':
    main()
