// 生成 GDScript 移植对照用 golden：直接跑旧版 three.js 的算法，把结果固化成 JSON。
// 用法：node art/tools/golden_sculpture.mjs
// 输出：game/tests/data/sculpture_golden.json
import { writeFileSync, mkdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import {
	SIZE, PRESETS, createTarget, makeBlank, suppliedClay, applyBrush, pushClay,
	compareSculpture, clayEdge,
} from '../../legacy/web-demo/src/sculpture.js';

const here = dirname(fileURLToPath(import.meta.url));
const out = resolve(here, '../../game/tests/data/sculpture_golden.json');

/** FNV-1a 32 位，和 GDScript 侧的实现逐字节可比。 */
function hash(pixels) {
	let h = 0x811c9dc5;
	for (let i = 0; i < pixels.length; i++) {
		h = (h ^ pixels[i]) >>> 0;
		h = Math.imul(h, 16777619) >>> 0;
	}
	return h.toString(16).padStart(8, '0');
}

function counts(pixels) {
	const c = [0, 0, 0];
	for (let i = 0; i < pixels.length; i++) if (pixels[i] < 3) c[pixels[i]]++;
	return c;
}

const cases = { targets: {}, supplied: {}, strokes: [], compares: [], edges: [] };

for (const preset of PRESETS) {
	const target = createTarget(preset.id);
	cases.targets[preset.id] = { hash: hash(target), counts: counts(target) };
	cases.supplied[preset.id] = {};
	for (const level of [1, 2, 3]) {
		cases.supplied[preset.id][level] = hash(suppliedClay(target, level));
	}
}

cases.blank = { hash: hash(makeBlank()), counts: counts(makeBlank()) };

// 笔刷路径：每条都记录 changed 与结果 hash
const brushCases = [
	{ name: 'cut-diagonal', tool: 'cut', radius: 7, color: 2, path: [[30, 30], [80, 80]] },
	{ name: 'cut-wide', tool: 'cut', radius: 14, color: 2, path: [[56, 20], [56, 90]] },
	{ name: 'add-arc', tool: 'add', radius: 6, color: 2, path: [[40, 60], [50, 40], [60, 60]] },
	{ name: 'paint-band', tool: 'paint', radius: 5, color: 2, path: [[20, 56], [92, 56]] },
	{ name: 'paint-white', tool: 'paint', radius: 9, color: 1, path: [[50, 30], [50, 80]] },
];
for (const design of ['band-pot', 'dot-jar']) {
	for (const c of brushCases) {
		const pixels = suppliedClay(createTarget(design), 2);
		let changed = false;
		for (let i = 1; i < c.path.length; i++) {
			const [x0, y0] = c.path[i - 1];
			const [x1, y1] = c.path[i];
			changed = applyBrush(pixels, x0, y0, x1, y1, c.radius, c.tool, c.color) || changed;
		}
		cases.strokes.push({
			name: `${design}/${c.name}`, design, tool: c.tool, radius: c.radius,
			color: c.color, path: c.path, changed, hash: hash(pixels), counts: counts(pixels),
		});
	}
}

// 拉坯：grab 自动寻找 + 连续推拉
// 玩家会先按在泥边上；这里从一侧向内扫，找到第一个能抓住边缘的位置再推。
const pushCases = [
	{ name: 'out-right', design: 'band-pot', level: 2, axis: 'x', fromLeft: false, at: 56, drag: 9 },
	{ name: 'in-left', design: 'band-pot', level: 2, axis: 'x', fromLeft: true, at: 56, drag: 8 },
	{ name: 'up-shoulder', design: 'band-pot', level: 3, axis: 'y', fromLeft: true, at: 30, drag: 6 },
	{ name: 'pinch-neck', design: 'tall-pot', level: 3, axis: 'x', fromLeft: false, at: 40, drag: -7 },
	{ name: 'flat-top', design: 'moon-jar', level: 3, axis: 'y', fromLeft: true, at: 56, drag: -6 },
];
for (const c of pushCases) {
	const target = createTarget(c.design);
	const pixels = suppliedClay(target, c.level);
	let grab = null;
	let start = null;
	for (let step = 0; step < SIZE && !grab; step++) {
		const along = c.fromLeft ? step : SIZE - 1 - step;
		const x = c.axis === 'x' ? along : c.at;
		const y = c.axis === 'x' ? c.at : along;
		grab = clayEdge(pixels, x, y, 18);
		if (grab) start = [x, y];
	}
	if (!start) { console.warn(`找不到可抓取的边缘：${c.name}`); continue; }
	const path = [start, [start[0] + (c.axis === 'x' ? c.drag : 0), start[1] + (c.axis === 'y' ? c.drag : 0)]];
	const firstGrab = grab;
	const changedFlags = [];
	for (let i = 1; i < path.length; i++) {
		const [x0, y0] = path[i - 1];
		const [x1, y1] = path[i];
		changedFlags.push(pushClay(pixels, x0, y0, x1, y1, 18, grab, {
			target, level: c.level, symmetric: true,
		}));
		grab = clayEdge(pixels, x1, y1, 18);
	}
	cases.strokes.push({
		name: `push/${c.name}`, design: c.design, kind: 'push', level: c.level,
		start, path, firstGrab, changed: changedFlags, hash: hash(pixels), counts: counts(pixels),
	});
}

// clayEdge：若干采样点的抓取结果
for (const design of ['band-pot', 'tall-pot']) {
	for (const [x, y] of [[30, 56], [70, 56], [56, 30], [56, 80], [5, 5]]) {
		const pixels = suppliedClay(createTarget(design), 3);
		cases.edges.push({ design, x, y, radius: 18, result: clayEdge(pixels, x, y, 18) });
	}
}

// 评分：几组有代表性的对比
const compareCases = [
	{ name: 'target-vs-target', design: 'band-pot', actual: (t) => t },
	{ name: 'blank-vs-target', design: 'band-pot', actual: () => makeBlank() },
	{ name: 'supplied2-vs-target', design: 'band-pot', actual: (t) => suppliedClay(t, 2) },
	{ name: 'supplied3-vs-target', design: 'tall-pot', actual: (t) => suppliedClay(t, 3) },
	{ name: 'blank-vs-dot-jar', design: 'dot-jar', actual: () => makeBlank() },
	{
		name: 'painted-vs-band-pot', design: 'band-pot',
		actual: (t) => {
			const p = suppliedClay(t, 3);
			applyBrush(p, 20, 60, 92, 60, 6, 'paint', 2);
			applyBrush(p, 20, 40, 92, 40, 6, 'paint', 2);
			return p;
		},
	},
	{
		name: 'carved-vs-moon-jar', design: 'moon-jar',
		actual: (t) => {
			const p = suppliedClay(t, 3);
			applyBrush(p, 10, 10, 10, 100, 10, 'cut', 2);
			return p;
		},
	},
];
for (const c of compareCases) {
	const target = createTarget(c.design);
	const result = compareSculpture(c.actual(target), target);
	cases.compares.push({
		name: c.name, design: c.design,
		score: result.score, shape: result.shape ?? result.shapeScore, paint: result.paint ?? result.color ?? result.paintScore,
		passed: result.passed, missing: result.missing, excess: result.excess,
		raw: result,
	});
}

mkdirSync(dirname(out), { recursive: true });
writeFileSync(out, JSON.stringify(cases, null, '\t') + '\n', 'utf8');
console.log(`golden 写入 ${out}`);
console.log(`目标 ${Object.keys(cases.targets).length} 个，笔画 ${cases.strokes.length} 条，评分 ${cases.compares.length} 组`);
console.log(JSON.stringify(cases.compares[0], null, 2));
