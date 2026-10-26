"""Report mesh topology statistics for glTF/GLB files (no saving, read-only).

Usage:
    blender --background --factory-startup --disable-autoexec \
        --python art/tools/mesh_stats.py -- --in <dir-or-glb> [--json <out.json>]

Prints one line per object plus a per-file summary:
  tris / quads / ngons, loose parts, non-manifold edges, zero-area faces,
  material count, and world bounding box.
"""
import json
import sys
from pathlib import Path

import bmesh
import bpy


def parse_args():
    argv = sys.argv
    rest = argv[argv.index('--') + 1:] if '--' in argv else []
    target = None
    json_out = None
    for i, token in enumerate(rest):
        if token == '--in' and i + 1 < len(rest):
            target = Path(rest[i + 1]).resolve()
        elif token == '--json' and i + 1 < len(rest):
            json_out = Path(rest[i + 1]).resolve()
    if target is None:
        raise SystemExit('missing --in <dir-or-glb>')
    return target, json_out


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def mesh_report(obj):
    mesh = obj.data
    bm = bmesh.new()
    bm.from_mesh(mesh)
    tri = quad = ngon = 0
    for face in bm.faces:
        n = len(face.verts)
        if n == 3:
            tri += 1
        elif n == 4:
            quad += 1
        else:
            ngon += 1
    non_manifold = sum(1 for e in bm.edges if not e.is_manifold)
    boundary = sum(1 for e in bm.edges if e.is_boundary)
    loose_verts = sum(1 for v in bm.verts if not v.link_faces)
    zero_area = sum(1 for f in bm.faces if f.calc_area() < 1e-9)

    # Connected components (loose parts).
    seen = set()
    parts = 0
    for v in bm.verts:
        if v.index in seen:
            continue
        parts += 1
        stack = [v]
        while stack:
            cur = stack.pop()
            if cur.index in seen:
                continue
            seen.add(cur.index)
            for edge in cur.link_edges:
                other = edge.other_vert(cur)
                if other.index not in seen:
                    stack.append(other)

    bm.free()
    mats = [slot.material.name if slot.material else '<none>' for slot in obj.material_slots]
    return {
        'name': obj.name,
        'verts': len(mesh.vertices),
        'faces': len(mesh.polygons),
        'tris_if_triangulated': sum(len(p.vertices) - 2 for p in mesh.polygons),
        'tri_faces': tri,
        'quad_faces': quad,
        'ngon_faces': ngon,
        'loose_parts': parts,
        'non_manifold_edges': non_manifold,
        'boundary_edges': boundary,
        'loose_verts': loose_verts,
        'zero_area_faces': zero_area,
        'materials': len(mats),
        'material_names': mats,
    }


def analyse(path, results):
    reset_scene()
    bpy.ops.import_scene.gltf(filepath=str(path))
    objects = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    total_tris_geo = 0
    total_tris = 0
    total_quads = 0
    total_ngons = 0
    total_parts = 0
    per_object = []
    for obj in objects:
        rep = mesh_report(obj)
        per_object.append(rep)
        total_tris_geo += rep['tris_if_triangulated']
        total_tris += rep['tri_faces']
        total_quads += rep['quad_faces']
        total_ngons += rep['ngon_faces']
        total_parts += rep['loose_parts']

    print(f'== {path.name} ==')
    for rep in per_object:
        print('  {name:<34} f={faces:<6} tri={tri_faces:<6} quad={quad_faces:<6} '
              'ngon={ngon_faces:<4} parts={loose_parts:<4} nm={non_manifold_edges:<4} '
              'mat={materials}'.format(**rep))
    print(f'  SUM objects={len(objects)} faces={total_tris + total_quads + total_ngons} '
          f'tri_faces={total_tris} quad_faces={total_quads} ngon_faces={total_ngons} '
          f'tris_geo={total_tris_geo} parts={total_parts}')

    results[path.name] = {
        'objects': len(objects),
        'tri_faces': total_tris,
        'quad_faces': total_quads,
        'ngon_faces': total_ngons,
        'tris_if_triangulated': total_tris_geo,
        'loose_parts': total_parts,
        'per_object': per_object,
    }


def main():
    target, json_out = parse_args()
    files = sorted(target.glob('*.glb')) if target.is_dir() else [target]
    if not files:
        raise SystemExit(f'no .glb found under {target}')
    results = {}
    for path in files:
        analyse(path, results)
    total = sum(r['tris_if_triangulated'] for r in results.values())
    print(f'== TOTAL tris_if_triangulated={total} ==')
    if json_out:
        json_out.parent.mkdir(parents=True, exist_ok=True)
        json_out.write_text(json.dumps(results, indent=2, ensure_ascii=False), encoding='utf-8')
        print('json ->', json_out)


main()
