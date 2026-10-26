"""Find the pixel offset that best aligns the Godot world shot to the legacy shot.

Usage:
    python art/tools/align_shots.py
    python art/tools/align_shots.py --range 60 --step 1
"""
from __future__ import annotations

import argparse
import pathlib

import numpy as np
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[2]


def load(path, box):
    img = Image.open(path).convert("RGB").crop(box)
    return np.asarray(img, dtype=np.float64) / 255.0


def luma(rgb):
    return rgb[..., 0] * 0.2126 + rgb[..., 1] * 0.7152 + rgb[..., 2] * 0.0722


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--legacy", default=str(ROOT / ".local" / "legacy-shots" / "02-world.png"))
    ap.add_argument("--godot", default=str(ROOT / ".local" / "godot-shots" / "world.png"))
    ap.add_argument("--box", default="0,95,1335,842")
    ap.add_argument("--range", type=int, default=60)
    ap.add_argument("--step", type=int, default=2)
    args = ap.parse_args()
    box = tuple(int(v) for v in args.box.split(","))
    la = luma(load(args.legacy, box))
    lb = luma(load(args.godot, box))
    h, w = la.shape
    margin = args.range + 4
    # centre window used for scoring, shifted around
    cw, ch = w - 2 * margin, h - 2 * margin
    ref = la[margin:margin + ch, margin:margin + cw]
    best = None
    for dy in range(-args.range, args.range + 1, args.step):
        for dx in range(-args.range, args.range + 1, args.step):
            y0, x0 = margin + dy, margin + dx
            if y0 < 0 or x0 < 0 or y0 + ch > h or x0 + cw > w:
                continue
            cand = lb[y0:y0 + ch, x0:x0 + cw]
            err = float(np.abs(ref - cand).mean())
            if best is None or err < best[0]:
                best = (err, dx, dy)
    print(f"best offset dx={best[1]} dy={best[2]} mean_abs={best[0]:.4f}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
