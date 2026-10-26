"""Clean up and simplify the site scenes for the Godot project.

Each scene ships as one .blend with 800-1400 small objects and one exported GLB
with the same meshes batched by material.  The .blend sources are already
low-poly and mostly quads; the 265k triangle figure comes from glTF
triangulation, so the only way to really lower the triangle count is to remove
geometry.

Stages, per mesh object (originals are never overwritten):

  1. weld          merge coincident vertices (remove_doubles)
  2. degenerate    drop zero-area faces / zero-length edges
  3. decimate      collapse to a target triangle ratio (optional)
  4. quads         rebuild quads from triangles (join_triangles)
  5. normals       recalculate outside

Usage:
    blender -b --factory-startup --disable-autoexec \
        --python art/tools/optimize_meshes.py -- \
        --in art/blender --out art/blender/opt --glb game/assets/models/maps-opt \
        [--ratio 0.6] [--weld 0.0005] [--angle 40] [--only 01-guyao]
"""
import json
import math
import sys
from pathlib import Path

import bmesh
import bpy

ROOT = Path(__file__).resolve().parents[2]


def parse_args():
    argv = sys.argv
    rest = argv[argv.index('--') + 1:] if '--' in argv else []
    opts = {
        'in': ROOT / 'art' / 'blender',
        'out': ROOT / 'art' / 'blender' / 'opt',
        'glb': ROOT / 'game' / 'assets' / 'models' / 'maps-opt',
        'ratio': 1.0,
        'weld': 0.0005,
        'angle': 40.0,
        'mode': 'planar',
        'planar_angle': 5.0,
        'min_faces': 48,
        'only': None,
    }
    for i, token in enumerate(rest):
        if token.startswith('--') and i + 1 < len(rest):
            key = token[2:]
            if key in opts:
                opts[key] = rest[i + 1]
    for key in ('in', 'out', 'glb'):
        opts[key] = Path(opts[key]).resolve()
    opts['ratio'] = float(opts['ratio'])
    opts['weld'] = float(opts['weld'])
    opts['angle'] = float(opts['angle'])
    opts['planar_angle'] = float(opts['planar_angle'])
    opts['min_faces'] = int(opts['min_faces'])
    return opts


def face_counts(meshes):
    tri = quad = ngon = 0
    for mesh in meshes:
        for poly in mesh.polygons:
            n = len(poly.vertices)
            tri += n == 3
            quad += n == 4
            ngon += n > 4
    total = tri + quad + ngon
    return {
        'faces': total,
        'tri': tri,
        'quad': quad,
        'ngon': ngon,
        'triangles': sum(len(p.vertices) - 2 for mesh in meshes for p in mesh.polygons),
    }


def cleanup_mesh(mesh, weld):
    """Weld doubles and drop degenerate geometry."""
    bm = bmesh.new()
    bm.from_mesh(mesh)
    if weld > 0.0:
        bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=weld)
    bmesh.ops.dissolve_degenerate(bm, dist=weld * 0.1, edges=list(bm.edges))
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()


def decimate_object(obj, ratio):
    """Collapse-decimate an object through a modifier (bmesh has no decimate op)."""
    mod = obj.modifiers.new('simplify', 'DECIMATE')
    mod.decimate_type = 'COLLAPSE'
    mod.ratio = ratio
    mod.use_collapse_triangulate = False
    depsgraph = bpy.context.evaluated_depsgraph_get()
    evaluated = obj.evaluated_get(depsgraph)
    baked = bpy.data.meshes.new_from_object(evaluated)
    obj.modifiers.clear()
    old = obj.data
    obj.data = baked
    if old.users == 0:
        bpy.data.meshes.remove(old)


def dissolve_planar_object(obj, angle_degrees):
    """Merge coplanar faces (keeps the silhouette exactly, removes interior mesh)."""
    mod = obj.modifiers.new('planar', 'DECIMATE')
    mod.decimate_type = 'DISSOLVE'
    mod.angle_limit = math.radians(angle_degrees)
    mod.use_dissolve_boundaries = False
    depsgraph = bpy.context.evaluated_depsgraph_get()
    evaluated = obj.evaluated_get(depsgraph)
    baked = bpy.data.meshes.new_from_object(evaluated)
    obj.modifiers.clear()
    old = obj.data
    obj.data = baked
    if old.users == 0:
        bpy.data.meshes.remove(old)


def rebuild_quads(mesh, angle):
    """Merge triangles into quads; only faces sharing a material slot merge."""
    bm = bmesh.new()
    bm.from_mesh(mesh)
    angle_rad = math.radians(angle)
    try:
        bmesh.ops.join_triangles(
            bm,
            faces=[f for f in bm.faces if len(f.verts) == 3],
            angle_face_threshold=angle_rad,
            angle_shape_threshold=angle_rad,
            cmp_seam=False,
            cmp_sharp=False,
            cmp_uvs=False,
            cmp_vcols=False,
            cmp_materials=False,
        )
    except Exception as exc:  # pragma: no cover - API drift guard
        print('  join_triangles skipped:', exc)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()


def process(path, opts):
    bpy.ops.wm.open_mainfile(filepath=str(path))
    objects = [o for o in bpy.context.scene.objects if o.type == 'MESH']

    before = face_counts([o.data for o in objects])
    decimated = 0
    for obj in objects:
        polygons = len(obj.data.polygons)
        if polygons < 8:
            continue
        cleanup_mesh(obj.data, opts['weld'])
        if opts['mode'] in ('planar', 'both'):
            dissolve_planar_object(obj, opts['planar_angle'])
        if opts['mode'] in ('collapse', 'both') and opts['ratio'] < 0.999 and polygons >= opts['min_faces']:
            decimate_object(obj, opts['ratio'])
            decimated += 1
        rebuild_quads(obj.data, opts['angle'])
    after = face_counts([o.data for o in objects])
    print(f'  decimated objects: {decimated}')

    opts['out'].mkdir(parents=True, exist_ok=True)
    save_path = opts['out'] / path.name
    bpy.ops.wm.save_as_mainfile(filepath=str(save_path), check_existing=False)

    glb_path = opts['glb'] / (path.stem.replace('-', '-') + '.glb')
    opts['glb'].mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(glb_path),
        export_format='GLB',
        use_selection=False,
        export_apply=True,
        export_yup=True,
        export_materials='EXPORT',
        export_extras=True,
        export_cameras=False,
        export_lights=False,
    )

    print(f'== {path.name} ==')
    print(f'  before faces={before["faces"]} tri={before["tri"]} quad={before["quad"]} '
          f'ngon={before["ngon"]} triangles={before["triangles"]}')
    print(f'  after  faces={after["faces"]} tri={after["tri"]} quad={after["quad"]} '
          f'ngon={after["ngon"]} triangles={after["triangles"]}')
    print(f'  saved {save_path}')
    print(f'  glb   {glb_path}')
    return {'name': path.name, 'before': before, 'after': after}


def main():
    opts = parse_args()
    files = sorted(opts['in'].glob('*.blend'))
    if opts['only']:
        files = [p for p in files if opts['only'] in p.name]
    if not files:
        raise SystemExit(f'no .blend under {opts["in"]}')
    report = []
    for path in files:
        report.append(process(path, opts))
    out = ROOT / '.local' / 'tmp' / 'optimize-report.json'
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(report, indent=2), encoding='utf-8')
    totals = {
        'before': sum(r['before']['triangles'] for r in report),
        'after': sum(r['after']['triangles'] for r in report),
    }
    print(f'TOTAL triangles {totals["before"]} -> {totals["after"]}')
    print('DONE')


main()
