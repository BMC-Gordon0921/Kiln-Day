"""Score a Godot world screenshot against the bare legacy capture.

Usage:
    python art/tools/parity_score.py --godot .local/godot-shots/world.png
    python art/tools/parity_score.py --godot shot.png --legacy .local/legacy-shots/02-world-bare.png
"""
from __future__ import annotations

import argparse
import json
import pathlib

import numpy as np
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[2]

# HUD leftovers still visible in the bare capture, in canvas-local coordinates.
IGNORE = [
    (10, 5, 150, 60),
    (385, 90, 545, 150),
    (390, 660, 890, 730),
]


def load(path, box):
    img = Image.open(path).convert("RGB").crop(box)
    return np.asarray(img, dtype=np.float64) / 255.0


def luma(rgb):
    return rgb[..., 0] * 0.2126 + rgb[..., 1] * 0.7152 + rgb[..., 2] * 0.0722


def ssim(a, b, win=8):
    la, lb = luma(a), luma(b)
    if la.shape != lb.shape:
        h = min(la.shape[0], lb.shape[0])
        w = min(la.shape[1], lb.shape[1])
        la, lb = la[:h, :w], lb[:h, :w]
    k = np.ones((win, win)) / (win * win)
    from numpy.lib.stride_tricks import sliding_window_view

    def filt(x):
        view = sliding_window_view(x, (win, win))
        return np.einsum("ijkl,kl->ij", view, k)

    mu_a, mu_b = filt(la), filt(lb)
    var_a = filt(la * la) - mu_a ** 2
    var_b = filt(lb * lb) - mu_b ** 2
    cov = filt(la * lb) - mu_a * mu_b
    c1, c2 = 0.01 ** 2, 0.03 ** 2
    num = (2 * mu_a * mu_b + c1) * (2 * cov + c2)
    den = (mu_a ** 2 + mu_b ** 2 + c1) * (var_a + var_b + c2)
    return float(np.mean(num / den))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--legacy", default=str(ROOT / ".local" / "legacy-shots" / "02-world-bare.png"))
    ap.add_argument("--godot", default=str(ROOT / ".local" / "godot-shots" / "world.png"))
    ap.add_argument("--box", default="0,95,1335,842")
    ap.add_argument("--json", default="")
    args = ap.parse_args()
    box = tuple(int(v) for v in args.box.split(","))
    a = load(args.legacy, box)
    b = load(args.godot, box)
    h = min(a.shape[0], b.shape[0])
    w = min(a.shape[1], b.shape[1])
    a, b = a[:h, :w], b[:h, :w]
    mask = np.ones((h, w), dtype=bool)
    for x0, y0, x1, y1 in IGNORE:
        mask[max(0, y0):min(h, y1), max(0, x0):min(w, x1)] = False
    diff = np.abs(a - b).mean(axis=2)
    print(f"ssim={ssim(a, b):.4f} mean_abs={diff.mean():.4f} masked_abs={diff[mask].mean():.4f}")
    # region breakdown: thirds of the canvas
    for name, sl in {
        "top": (slice(0, h // 3), slice(0, w)),
        "mid": (slice(h // 3, 2 * h // 3), slice(0, w)),
        "bottom": (slice(2 * h // 3, h), slice(0, w)),
    }.items():
        print(f"  {name:<7} abs={np.abs(a[sl] - b[sl]).mean():.4f}")
    if args.json:
        pathlib.Path(args.json).write_text(json.dumps({
            "ssim": ssim(a, b),
            "mean_abs": float(diff.mean()),
            "masked_abs": float(diff[mask].mean()),
        }), encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
