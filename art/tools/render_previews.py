"""Render preview images of the exported workbench GLBs.

Imports every .glb in a directory, lines them up along X, lights them, and
renders one overview image plus one image per asset.  Tiers are toggled through
the ``tier`` custom property written by build-workbenches.py.

Usage:
    blender -b --factory-startup --disable-autoexec \
        --python art/tools/render_previews.py -- \
        --in game/assets/models/workbenches --out .local/tmp/previews \
        [--level 3] [--width 1600] [--height 900]
"""
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]


def parse_args():
    argv = sys.argv
    rest = argv[argv.index('--') + 1:] if '--' in argv else []
    opts = {'in': None, 'out': None, 'level': 3, 'width': 1600, 'height': 900}
    for i, token in enumerate(rest):
        if token == '--overview-only':
            opts['overview_only'] = True
        elif token == '--each':
            opts['each'] = True
        elif token.startswith('--') and i + 1 < len(rest):
            key = token[2:]
            if key in opts:
                opts[key] = rest[i + 1]
    if not opts['in'] or not opts['out']:
        raise SystemExit('need --in <glb dir> --out <png dir>')
    opts['in'] = Path(opts['in']).resolve()
    opts['out'] = Path(opts['out']).resolve()
    opts['level'] = int(opts['level'])
    opts['width'] = int(opts['width'])
    opts['height'] = int(opts['height'])
    return opts


def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def setup_world():
    world = bpy.data.worlds.new('preview')
    bpy.context.scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes['Background']
    bg.inputs['Color'].default_value = (0.045, 0.05, 0.06, 1.0)
    bg.inputs['Strength'].default_value = 1.0

    sun = bpy.data.objects.new('sun', bpy.data.lights.new('sun', 'SUN'))
    sun.data.energy = 3.5
    sun.rotation_euler = (math.radians(55), math.radians(8), math.radians(35))
    bpy.context.scene.collection.objects.link(sun)

    fill = bpy.data.objects.new('fill', bpy.data.lights.new('fill', 'AREA'))
    fill.data.energy = 300
    fill.data.size = 8
    fill.location = (-6, -7, 5)
    fill.rotation_euler = (math.radians(60), 0, math.radians(-40))
    bpy.context.scene.collection.objects.link(fill)

    ground = bpy.data.meshes.new('ground')
    ground.from_pydata([(-60, -60, 0), (60, -60, 0), (60, 60, 0), (-60, 60, 0)],
                       [], [(0, 1, 2, 3)])
    ground.update()
    canvas = bpy.data.materials.new('ground')
    canvas.use_nodes = True
    canvas.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = (0.10, 0.10, 0.11, 1)
    canvas.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value = 0.9
    ground.materials.append(canvas)
    obj = bpy.data.objects.new('ground', ground)
    bpy.context.scene.collection.objects.link(obj)


def import_glb(path, offset_x=0.0):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    added = [o for o in bpy.data.objects if o not in before]
    for obj in added:
        obj.location.x += offset_x
    return added


def apply_level(level):
    for obj in bpy.data.objects:
        tier = obj.get('tier')
        if tier is None:
            continue
        need = {'base': 1, 'upgrade1': 2, 'upgrade2': 3}[tier]
        obj.hide_render = level < need
        obj.hide_viewport = level < need


def camera_for(targets, width, height, direction=(1.0, -1.0, 0.62), fit=1.55):
    corners = []
    for obj in targets:
        for corner in obj.bound_box:
            corners.append(obj.matrix_world @ Vector(corner))
    lo = Vector((min(c.x for c in corners), min(c.y for c in corners), min(c.z for c in corners)))
    hi = Vector((max(c.x for c in corners), max(c.y for c in corners), max(c.z for c in corners)))
    centre = (lo + hi) / 2
    radius = max((hi - lo).length / 2, 1e-3)
    cam_data = bpy.data.cameras.new('cam')
    cam_data.lens = 50
    cam = bpy.data.objects.new('cam', cam_data)
    bpy.context.scene.collection.objects.link(cam)
    dist = radius * 2.6 * fit
    vec = Vector(direction).normalized() * dist
    cam.location = centre + vec
    look = (centre - cam.location).normalized()
    cam.rotation_euler = look.to_track_quat('-Z', 'Y').to_euler()
    bpy.context.scene.camera = cam
    return cam


def configure(width, height):
    scene = bpy.context.scene
    scene.render.resolution_x = width
    scene.render.resolution_y = height
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = False
    try:
        scene.render.engine = 'BLENDER_EEVEE_NEXT'
    except TypeError:
        try:
            scene.render.engine = 'BLENDER_EEVEE'
        except TypeError:
            scene.render.engine = 'BLENDER_WORKBENCH'
    scene.view_settings.view_transform = 'Standard'
    scene.render.image_settings.file_format = 'PNG'


def render(path):
    bpy.context.scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    print('RENDERED', path)


def main():
    opts = parse_args()
    opts['out'].mkdir(parents=True, exist_ok=True)
    files = sorted(opts['in'].glob('*.glb'))

    # One framed image per asset (used for the site scenes).
    if opts.get('each'):
        for path in files:
            clear()
            setup_world()
            configure(opts['width'], opts['height'])
            added = import_glb(path)
            camera_for([o for o in added if o.type == 'MESH'],
                       opts['width'], opts['height'],
                       direction=(0.9, -1.0, 0.55), fit=1.15)
            render(opts['out'] / f'{path.stem}.png')
        print('DONE')
        return

    # Overview: all assets in a row, everything visible.
    clear()
    setup_world()
    configure(opts['width'], opts['height'])
    placed = []
    for index, path in enumerate(files):
        added = import_glb(path, offset_x=index * 3.4)
        placed.extend(added)
    apply_level(opts['level'])
    camera_for([o for o in placed if o.type == 'MESH'], opts['width'], opts['height'])
    render(opts['out'] / 'overview.png')

    # One image per asset: base tier and full tier.
    if opts.get('overview_only'):
        print('DONE')
        return
    for path in files:
        for level in (1, 3):
            clear()
            setup_world()
            configure(opts['width'] // 2, opts['height'] // 2)
            added = import_glb(path)
            apply_level(level)
            camera_for([o for o in added if o.type == 'MESH'],
                       opts['width'] // 2, opts['height'] // 2,
                       direction=(1.0, -1.2, 0.55), fit=1.35)
            render(opts['out'] / f'{path.stem}-l{level}.png')
    print('DONE')


main()
