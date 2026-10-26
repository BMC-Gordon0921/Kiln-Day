"""Sample matching patches from the legacy and Godot world screenshots.

Usage:
    python art/tools/sample_colors.py
    python art/tools/sample_colors.py --legacy <png> --godot <png> --box 0,95,1335,842
"""
from __future__ import annotations

import argparse
import pathlib

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[2]

POINTS = {
    "ground": (700, 640),
    "island_side": (300, 690),
    "roof": (800, 100),
    "brick_wall": (700, 190),
    "tree": (200, 470),
    "kiln_dome": (1030, 300),
    "chimney": (1160, 200),
    "backdrop": (40, 40),
}


def parse_box(text):
    parts = [int(v) for v in text.split(",")]
    return tuple(parts)  # left, top, right, bottom


def mean_patch(img, x, y, size=8):
    box = (x - size // 2, y - size // 2, x + size // 2, y + size // 2)
    patch = img.crop(box)
    pixels = list(patch.getdata())
    count = len(pixels)
    return tuple(sum(p[i] for p in pixels) // count for i in range(3))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--legacy", default=str(ROOT / ".local" / "legacy-shots" / "02-world.png"))
    ap.add_argument("--godot", default=str(ROOT / ".local" / "godot-shots" / "world.png"))
    ap.add_argument("--box", default="0,95,1335,842")
    args = ap.parse_args()

    box = parse_box(args.box)
    legacy = Image.open(args.legacy).convert("RGB").crop(box)
    godot = Image.open(args.godot).convert("RGB").crop(box)
    legacy.save(ROOT / ".local" / "tmp" / "cmp-legacy-crop.png")
    godot.save(ROOT / ".local" / "tmp" / "cmp-godot-crop.png")

    print(f"{'point':<12}{'legacy':<18}{'godot':<18}{'delta'}")
    for name, (x, y) in POINTS.items():
        l = mean_patch(legacy, x, y)
        g = mean_patch(godot, x, y)
        d = tuple(g[i] - l[i] for i in range(3))
        print(f"{name:<12}{str(l):<18}{str(g):<18}{d}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
