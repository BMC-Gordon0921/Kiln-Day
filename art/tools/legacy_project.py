"""Analytic legacy projection for a few world points (three.js ortho camera math).

Usage:
    python art/tools/legacy_project.py
"""
from __future__ import annotations

import math

TARGET = (-0.2, 0.7, -0.7)
HOME_EYE = (10.0, 17.0, 20.0)
WIDTH, HEIGHT = 1335.0, 747.0
GROUND_LIFT = 0.09

# name -> (x, y, z) in world space (y is already relative to the site root)
POINTS = {
    "kiln": (-5.65, 0.0, 0.3),
    "clay": (-5.65, 0.0, -3.65),
    "wheel": (-2.7, 0.0, -3.65),
    "carve": (0.4, 0.0, -3.65),
    "paint": (-1.25, 0.0, 1.35),
    "serve": (3.2, 0.0, 0.0),
    "island_corner": (-10.0, 0.0, 8.0),
}


def sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def norm(a):
    length = math.sqrt(dot(a, a))
    return (a[0] / length, a[1] / length, a[2] / length)


def main() -> int:
    aspect = WIDTH / HEIGHT
    vh = max(15.8, 24.0 / aspect)
    f = norm(sub(TARGET, HOME_EYE))
    r = norm(cross(f, (0.0, 1.0, 0.0)))
    u = cross(r, f)
    print(f"aspect={aspect:.5f} vh={vh:.3f}")
    for name, (x, y, z) in POINTS.items():
        p = (x, y + GROUND_LIFT, z)
        rel = sub(p, HOME_EYE)
        ndc_x = dot(rel, r) / (vh * aspect / 2.0)
        ndc_y = dot(rel, u) / (vh / 2.0)
        sx = (ndc_x + 1.0) * WIDTH / 2.0
        sy = (1.0 - ndc_y) * HEIGHT / 2.0
        print(f"{name:<14} x={sx:8.2f} y={sy:8.2f}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
