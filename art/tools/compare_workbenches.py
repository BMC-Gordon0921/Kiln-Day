"""Compare the rebuilt workbenches against the real three.js geometry.

The oracle is ``.local/tmp/legacy-wb/legacy-workbenches.json`` produced by
``art/tools/legacy_workbench_dump.mjs``: for every part the old demo draws we
know its material colour, triangle count, centroid and size in world space.

This script loads ``game/assets/models/workbenches/<id>.glb``, computes the same
signature, and reports each part that has no counterpart (or sits in the wrong
place).  Tessellation density is expected to differ (Blender keeps quads), so
matching is done on colour + centroid; triangle counts are printed for context.

Usage:
    blender -b --factory-startup --disable-autoexec \
        --python art/tools/compare_workbenches.py -- [--in DIR] [--oracle FILE] [--render DIR]
"""
import argparse
import json
import sys
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
GLB_DIR = ROOT / 'game' / 'assets' / 'models' / 'workbenches'
ORACLE = ROOT / '.local' / 'tmp' / 'legacy-wb' / 'legacy-workbenches.json'
IDS = ('clay', 'wheel', 'carve', 'paint', 'serve', 'kiln')
LEVELS = (1, 2, 3)
TIER_LEVEL = {'base': 1, 'upgrade1': 2, 'upgrade2': 3}
TOLERANCE = 0.02  # metres; a mismatched part is usually off by much more
SIZE_TOLERANCE = 0.12  # relative, per axis


def to_three(co):
    """Blender world (Z up) -> three.js world (Y up), the inverse of SWIZZLE."""
    return Vector((co[0], co[2], -co[1]))


def size_to_three(size):
    return Vector((size[0], size[2], size[1]))


def linear_to_srgb(value):
    return 12.92 * value if value <= 0.0031308 else 1.055 * value ** (1 / 2.4) - 0.055


def material_hex(mat):
    if mat is None or not mat.use_nodes:
        return '#000000'
    for node in mat.node_tree.nodes:
        if node.type == 'BSDF_PRINCIPLED':
            color = node.inputs['Base Color'].default_value
            srgb = [max(0.0, min(1.0, linear_to_srgb(c))) for c in color[:3]]
            return '#%02x%02x%02x' % tuple(round(c * 255) for c in srgb)
    return '#000000'


def signature(obj):
    mesh = obj.data
    mesh.calc_loop_triangles()
    world = obj.matrix_world
    total = Vector()
    area = 0.0
    count = 0
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for tri in mesh.loop_triangles:
        verts = [to_three(world @ mesh.vertices[index].co) for index in tri.vertices]
        # area weighted, so the value matches the three.js oracle no matter how
        # the polygon was triangulated
        weight = (verts[1] - verts[0]).cross(verts[2] - verts[0]).length / 2.0
        centre = (verts[0] + verts[1] + verts[2]) / 3.0
        total += centre * weight
        area += weight
        count += 1
        for co in verts:
            lo = Vector((min(lo[i], co[i]) for i in range(3)))
            hi = Vector((max(hi[i], co[i]) for i in range(3)))
    centroid = total / area if area > 1e-12 else Vector()
    return {
        'color': material_hex(obj.material_slots[0].material if obj.material_slots else None),
        'tris': count,
        'centroid': [round(v, 4) for v in centroid],
        'size': [round(v, 4) for v in (hi - lo)],
        'name': obj.name,
    }


def tier_level(obj):
    tier = obj.get('tier', 'base')
    if isinstance(tier, (int, float)):
        return int(tier)
    return TIER_LEVEL.get(str(tier), 1)


def load_parts(glb, level=3):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(glb))
    parts = []
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for obj in bpy.context.scene.objects:
        if obj.type != 'MESH':
            continue
        if tier_level(obj) > level:  # the web demo hides later upgrades
            continue
        sig = signature(obj)
        if sig['tris'] == 0:
            continue
        parts.append(sig)
        for corner in obj.bound_box:
            co = to_three(obj.matrix_world @ Vector(corner))
            lo = Vector((min(lo[i], co[i]) for i in range(3)))
            hi = Vector((max(hi[i], co[i]) for i in range(3)))
    return parts, ([round(v, 4) for v in lo], [round(v, 4) for v in hi])


def size_off(mine, legacy):
    """Axes whose bounding-box extent disagrees by more than SIZE_TOLERANCE."""
    wrong = []
    for i in range(3):
        a, b = mine[i], legacy[i]
        if abs(a - b) > max(0.02, SIZE_TOLERANCE * max(a, b)):
            wrong.append((i, round(a, 3), round(b, 3)))
    return wrong


def diff(bench_id, mine, legacy):
    """Greedy nearest-centroid match on the same colour, then verify the extent."""
    remaining = list(range(len(legacy)))
    unmatched = []
    deformed = []
    worst = 0.0
    for part in mine:
        best = None
        for idx in remaining:
            other = legacy[idx]
            if other['color'] != part['color']:
                continue
            distance = sum((a - b) ** 2 for a, b in zip(other['centroid'], part['centroid'])) ** 0.5
            if best is None or distance < best[1]:
                best = (idx, distance)
        if best is None or best[1] > TOLERANCE:
            unmatched.append(part)
            continue
        remaining.remove(best[0])
        worst = max(worst, best[1])
        wrong = size_off(part['size'], legacy[best[0]]['size'])
        if wrong:
            deformed.append((part, legacy[best[0]], wrong))
    missing = [legacy[idx] for idx in remaining]
    return unmatched, missing, deformed, worst


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--in', dest='glb_dir', default=str(GLB_DIR))
    parser.add_argument('--oracle', default=str(ORACLE))
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else [])

    oracle = json.loads(Path(args.oracle).read_text(encoding='utf-8'))
    glb_dir = Path(args.glb_dir)
    total_bad = 0

    for bench_id in IDS:
        for level in LEVELS:
            key = f'{bench_id}-L{level}'
            legacy = oracle[key]
            parts, bounds = load_parts(glb_dir / f'{bench_id}.glb', level)
            unmatched, missing, deformed, worst = diff(bench_id, parts, legacy['partList'])
            ok = not unmatched and not missing and not deformed
            total_bad += 0 if ok else 1
            print(f'== {key}: mine={len(parts)} parts / legacy={legacy["parts"]} parts '
                  f'-> {"OK" if ok else "MISMATCH"} (worst match {worst:.4f}, '
                  f'deformed {len(deformed)})')
            if ok:
                continue
            print(f'   bounds mine={bounds[0]}..{bounds[1]}')
            print(f'   bounds old ={legacy["bounds"]["min"]}..{legacy["bounds"]["max"]}')
            for part in unmatched:
                print(f'   + extra  {part["color"]} tris={part["tris"]:<5} '
                      f'at {part["centroid"]} size={part["size"]} ({part["name"]})')
            for part in missing:
                print(f'   - absent {part["color"]} tris={part["tris"]:<5} '
                      f'at {part["centroid"]} size={part["size"]}')
            for part, old, wrong in deformed:
                axes = ', '.join(f'{"xyz"[i]}:{a}->want{b}' for i, a, b in wrong)
                print(f'   ~ shape  {part["color"]} at {part["centroid"]} '
                      f'size={part["size"]} want={old["size"]} ({axes}) ({part["name"]})')

    print('COMPARE', 'OK' if total_bad == 0 else f'MISMATCH in {total_bad} bench(es)')


main()
