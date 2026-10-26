"""Compare Godot screenshots against legacy three.js references.

Usage:
    python art/tools/compare_shots.py
    python art/tools/compare_shots.py --pairs 02-world:shot-world,06-wheel:shot-wheel
    python art/tools/compare_shots.py --crop 0,60,1330,760

With no --pairs, every PNG present in BOTH directories is compared by file name.
Exit code 0 when all pairs reach the thresholds, 1 otherwise.
"""
from __future__ import annotations

import argparse
import json
import pathlib
import sys

import numpy as np
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[2]
LEGACY = ROOT / ".local" / "legacy-shots"
GODOT = ROOT / ".local" / "godot-shots"
REPORT = ROOT / ".local" / "tmp" / "parity-report.json"

SSIM_MIN = 0.92
DIFF_MAX = 0.06


def load(path, size=None):
    img = Image.open(path).convert("RGB")
    if size and img.size != size:
        img = img.resize(size, Image.LANCZOS)
    return np.asarray(img, dtype=np.float64) / 255.0


def to_luma(rgb):
    return rgb[..., 0] * 0.2126 + rgb[..., 1] * 0.7152 + rgb[..., 2] * 0.0722


def _box_mean(x, win):
    k = np.ones((win, win), dtype=np.float64)
    return _conv_valid(x, k)


def _conv_valid(x, k):
    kh, kw = k.shape
    h, w = x.shape
    oh, ow = h - kh + 1, w - kw + 1
    out = np.zeros((oh, ow), dtype=np.float64)
    for i in range(kh):
        for j in range(kw):
            out += x[i:i + oh, j:j + ow] * k[i, j]
    return out / k.sum()


def ssim(a, b, win=8):
    """Uniform-window SSIM on luminance."""
    la, lb = to_luma(a), to_luma(b)
    if la.shape != lb.shape:
        h = min(la.shape[0], lb.shape[0])
        w = min(la.shape[1], lb.shape[1])
        la, lb = la[:h, :w], lb[:h, :w]
    win = min(win, la.shape[0], la.shape[1])
    if win < 2:
        return 0.0
    c1, c2 = 0.01 ** 2, 0.03 ** 2
    mu_a, mu_b = _box_mean(la, win), _box_mean(lb, win)
    aa, bb, ab = _box_mean(la * la, win), _box_mean(lb * lb, win), _box_mean(la * lb, win)
    var_a = np.maximum(aa - mu_a * mu_a, 0.0)
    var_b = np.maximum(bb - mu_b * mu_b, 0.0)
    cov = ab - mu_a * mu_b
    num = (2 * mu_a * mu_b + c1) * (2 * cov + c2)
    den = (mu_a * mu_a + mu_b * mu_b + c1) * (var_a + var_b + c2)
    return float(np.mean(num / np.maximum(den, 1e-12)))


def crop(rgb, box):
    x, y, w, h = box
    return rgb[y:y + h, x:x + w]


def diff_map(a, b, out_path):
    d = np.abs(a - b).mean(axis=2)
    heat = np.zeros(a.shape, dtype=np.uint8)
    heat[..., 0] = np.clip(d * 255 * 4, 0, 255)
    heat[..., 1] = np.clip(255 - d * 255 * 4, 0, 255)
    Image.fromarray(heat).save(out_path)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--legacy", default=str(LEGACY))
    ap.add_argument("--godot", default=str(GODOT))
    ap.add_argument("--pairs", default="")
    ap.add_argument("--crop", default="")
    ap.add_argument("--out", default=str(ROOT / ".local" / "tmp" / "diff"))
    args = ap.parse_args()

    legacy_dir, godot_dir = pathlib.Path(args.legacy), pathlib.Path(args.godot)
    box = tuple(int(v) for v in args.crop.split(",")) if args.crop else None

    if args.pairs:
        pairs = []
        for item in args.pairs.split(","):
            lname, _, gname = item.partition(":")
            pairs.append((lname, gname or lname))
    else:
        names = sorted(p.stem for p in legacy_dir.glob("*.png"))
        pairs = [(n, n) for n in names if (godot_dir / (n + ".png")).exists()]

    if not pairs:
        print("no overlapping screenshots (legacy=%s godot=%s)" % (legacy_dir, godot_dir))
        return 2

    out_dir = pathlib.Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)

    rows, failed = [], 0
    for lname, gname in pairs:
        lp, gp = legacy_dir / (lname + ".png"), godot_dir / (gname + ".png")
        if not lp.exists() or not gp.exists():
            rows.append({"legacy": lname, "godot": gname, "error": "missing file"})
            failed += 1
            continue
        a, b = load(lp), load(gp, size=Image.open(lp).size)
        if box:
            a, b = crop(a, box), crop(b, box)
        value = ssim(a, b)
        diff = float(np.abs(a - b).mean())
        ok = value >= SSIM_MIN and diff <= DIFF_MAX
        diff_map(a, b, out_dir / ("diff-%s.png" % lname))
        rows.append({"legacy": lname, "godot": gname, "ssim": round(value, 4),
                     "meanDiff": round(diff, 4), "ok": ok})
        if not ok:
            failed += 1
        print("%-22s ssim=%.4f diff=%.4f %s" % (lname, value, diff, "OK" if ok else "MISMATCH"))

    REPORT.write_text(json.dumps({"thresholds": {"ssim": SSIM_MIN, "meanDiff": DIFF_MAX},
                                  "crop": box, "rows": rows}, ensure_ascii=False, indent=1),
                      encoding="utf-8")
    print("PAIRS OK %d / %d" % (len(pairs) - failed, len(pairs)) if not failed
          else "PARITY MISMATCH %d / %d" % (failed, len(pairs)))
    return 0 if not failed else 1


if __name__ == "__main__":
    sys.exit(main())
