"""Inspect .blend source files: objects, poly counts, modifiers, materials.

Usage:
    blender -b --factory-startup --disable-autoexec \
        --python art/tools/blend_stats.py -- <file.blend> [<file.blend> ...]

Read-only: opens each file, prints a table, never saves.
"""
import sys
from pathlib import Path

import bpy

BLENDER_VERSION_TAG = None


def report(path):
    bpy.ops.wm.open_mainfile(filepath=str(path))
    scene = bpy.context.scene
    meshes = [o for o in scene.objects if o.type == 'MESH']
    tri = quad = ngon = 0
    for obj in meshes:
        for poly in obj.data.polygons:
            n = len(poly.vertices)
            tri += n == 3
            quad += n == 4
            ngon += n > 4
    total = tri + quad + ngon
    print(f'== {path.name} == scene.frame_end={scene.frame_end} objects={len(scene.objects)} meshes={len(meshes)}')
    print(f'  FACES total={total} tri={tri} quad={quad} ngon={ngon} '
          f'quad%={100.0 * quad / max(1, total):.1f}')
    total = 0
    for obj in sorted(meshes, key=lambda o: len(o.data.polygons), reverse=True):
        me = obj.data
        tris = sum(len(p.vertices) - 2 for p in me.polygons)
        total += tris
        mods = ','.join(f'{m.type}{"(" + m.name + ")" if m.type != "NODES" else ""}' for m in obj.modifiers) or '-'
        gn = [m for m in obj.modifiers if m.type == 'NODES' and m.node_group]
        gninfo = ''
        if gn:
            gninfo = ' GN=' + ';'.join(m.node_group.name for m in gn)
        print(f'  {obj.name:<36} polys={len(me.polygons):<6} tris={tris:<7} '
              f'mat={len(me.materials)} mods={mods}{gninfo}')
    print(f'  TOTAL tris={total}')
    # Materials summary: any textures?
    textured = []
    for mat in bpy.data.materials:
        if mat.node_tree is None:
            continue
        for node in mat.node_tree.nodes:
            if node.type in {'TEX_IMAGE', 'TEX_ENVIRONMENT'}:
                img = getattr(node, 'image', None)
                textured.append(f'{mat.name}->{img.name if img else "?"}')
    print(f'  materials={len(bpy.data.materials)} textured={len(textured)} {textured[:6]}')


def main():
    argv = sys.argv
    rest = argv[argv.index('--') + 1:] if '--' in argv else []
    files = [Path(p).resolve() for p in rest]
    if not files:
        raise SystemExit('usage: -- <file.blend> ...')
    for path in files:
        report(path)


main()
