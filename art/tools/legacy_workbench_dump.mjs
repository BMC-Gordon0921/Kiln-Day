// Dump the *actual* three.js geometry of the six web-demo workbenches.
//
// This is the oracle for art/export/build-workbenches.py: whatever the old demo
// puts on screen is exactly what this script measures, so a rebuilt Blender mesh
// can be diffed against it part by part (colour + triangle count + centroid).
//
// Usage (from the workspace root):
//   node art/tools/legacy_workbench_dump.mjs [--out DIR]

import { writeFileSync, mkdirSync } from 'node:fs';
import { resolve } from 'node:path';
import * as THREE from '../../legacy/web-demo/node_modules/three/build/three.module.js';
import { createWorkbenchModel } from '../../legacy/web-demo/src/workbench-model.js';

const IDS = ['clay', 'wheel', 'carve', 'paint', 'serve', 'kiln'];
const LEVELS = [1, 2, 3];

const argOut = process.argv.indexOf('--out');
const OUT = resolve(
  argOut > -1 ? process.argv[argOut + 1] : '.local/tmp/legacy-wb',
);

mkdirSync(OUT, { recursive: true });

function centroidOf(geometry, matrixWorld) {
  // Area weighted *in world space*: independent of triangulation, and equal to
  // what a Blender-side measurement of the exported GLB produces even when the
  // mesh carries a non-uniform scale.
  const pos = geometry.getAttribute('position');
  const index = geometry.getIndex();
  const count = index ? index.count : pos.count;
  const a = new THREE.Vector3();
  const b = new THREE.Vector3();
  const c = new THREE.Vector3();
  const cross = new THREE.Vector3();
  const tri = new THREE.Vector3();
  const sum = new THREE.Vector3();
  let area = 0;
  for (let i = 0; i < count; i += 3) {
    const i0 = index ? index.getX(i) : i;
    const i1 = index ? index.getX(i + 1) : i + 1;
    const i2 = index ? index.getX(i + 2) : i + 2;
    a.fromBufferAttribute(pos, i0).applyMatrix4(matrixWorld);
    b.fromBufferAttribute(pos, i1).applyMatrix4(matrixWorld);
    c.fromBufferAttribute(pos, i2).applyMatrix4(matrixWorld);
    const weight = cross.subVectors(b, a).cross(c.clone().sub(a)).length() / 2;
    tri.copy(a).add(b).add(c).multiplyScalar(1 / 3);
    sum.addScaledVector(tri, weight);
    area += weight;
  }
  return area > 1e-12 ? sum.multiplyScalar(1 / area) : new THREE.Vector3();
}

function objFor(meshes) {
  const lines = ['# legacy three.js workbench geometry (world space, Y up)'];
  let offset = 1;
  const v = new THREE.Vector3();
  for (const mesh of meshes) {
    const geometry = mesh.geometry;
    const pos = geometry.getAttribute('position');
    const index = geometry.getIndex();
    const color = `#${mesh.material.color.getHexString()}`;
    lines.push(`o ${mesh.userData.part}`);
    lines.push(`usemtl ${color}`);
    for (let i = 0; i < pos.count; i += 1) {
      v.fromBufferAttribute(pos, i).applyMatrix4(mesh.matrixWorld);
      lines.push(`v ${v.x.toFixed(6)} ${v.y.toFixed(6)} ${v.z.toFixed(6)}`);
    }
    const count = index ? index.count : pos.count;
    for (let i = 0; i < count; i += 3) {
      const i0 = (index ? index.getX(i) : i) + offset;
      const i1 = (index ? index.getX(i + 1) : i + 1) + offset;
      const i2 = (index ? index.getX(i + 2) : i + 2) + offset;
      lines.push(`f ${i0} ${i1} ${i2}`);
    }
    offset += pos.count;
  }
  return `${lines.join('\n')}\n`;
}

const report = {};

for (const id of IDS) {
  for (const level of LEVELS) {
    const model = createWorkbenchModel({ id, level });
    model.update(0, { level, reduced: true });
    const group = model.group;
    group.updateMatrixWorld(true);

    // Only meshes that are actually visible at this level (three.js hides the
    // upgrade groups), so the dump matches what the player sees.
    const meshes = [];
    group.traverse((node) => {
      if (!node.isMesh) return;
      let visible = true;
      let walker = node;
      while (walker) {
        if (!walker.visible) visible = false;
        walker = walker.parent;
      }
      if (!visible) return;
      node.userData.part = `part${String(meshes.length).padStart(3, '0')}`;
      meshes.push(node);
    });

    const box = new THREE.Box3();
    const parts = [];
    for (const mesh of meshes) {
      const geometry = mesh.geometry;
      const index = geometry.getIndex();
      const tris = (index ? index.count : geometry.getAttribute('position').count) / 3;
      const centroid = centroidOf(geometry, mesh.matrixWorld);
      geometry.computeBoundingBox();
      const local = geometry.boundingBox.clone().applyMatrix4(mesh.matrixWorld);
      box.union(local);
      parts.push({
        color: `#${mesh.material.color.getHexString()}`,
        tris,
        centroid: [centroid.x, centroid.y, centroid.z].map((n) => +n.toFixed(4)),
        size: local.getSize(new THREE.Vector3()).toArray().map((n) => +n.toFixed(4)),
      });
    }

    const key = `${id}-L${level}`;
    report[key] = {
      parts: parts.length,
      triangles: parts.reduce((sum, p) => sum + p.tris, 0),
      bounds: {
        min: box.min.toArray().map((n) => +n.toFixed(4)),
        max: box.max.toArray().map((n) => +n.toFixed(4)),
      },
      partList: parts,
    };
    writeFileSync(resolve(OUT, `${key}.obj`), objFor(meshes), 'utf8');
    console.log(
      `${key.padEnd(12)} parts=${String(parts.length).padStart(3)} ` +
        `tris=${String(report[key].triangles).padStart(6)} ` +
        `bounds=${report[key].bounds.min}..${report[key].bounds.max}`,
    );
    model.dispose();
  }
}

writeFileSync(resolve(OUT, 'legacy-workbenches.json'), `${JSON.stringify(report, null, 2)}\n`, 'utf8');
console.log(`WROTE ${resolve(OUT, 'legacy-workbenches.json')}`);
