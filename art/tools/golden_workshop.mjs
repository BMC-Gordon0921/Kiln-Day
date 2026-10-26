// 生成经营/烧窑公式的对照 golden：node art/tools/golden_workshop.mjs
// 输出：game/tests/data/workshop_golden.json
import { writeFileSync, mkdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import {
	fireBand, createFireDrift, fireGrade, fireRatio, orderIncome, formatElapsed, clockPolicy,
} from '../../legacy/web-demo/src/workshop.js';

const here = dirname(fileURLToPath(import.meta.url));
const out = resolve(here, '../../game/tests/data/workshop_golden.json');

const cases = { bands: {}, drift: [], grades: [], incomes: [], elapsed: [], clocks: [] };

for (const level of [1, 2, 3, 4]) cases.bands[level] = fireBand(level);

for (const seed of [1, 2, 12345, 4294967295]) {
	const drift = createFireDrift(seed);
	const samples = [];
	for (let t = 0; t <= 12.0001; t += 0.25) samples.push([Number(t.toFixed(2)), Number(drift(t).toFixed(6))]);
	cases.drift.push({ seed, samples });
}

const secondSets = [
	{ perfect: 12, good: 0, fair: 0 },
	{ perfect: 9, good: 2, fair: 1 },
	{ perfect: 6, good: 3, fair: 3 },
	{ perfect: 4, good: 4, fair: 4 },
	{ perfect: 0, good: 0, fair: 12 },
	{ perfect: 0.0000001, good: 0, fair: 0 },
];
for (const seconds of secondSets) {
	cases.grades.push({ seconds, grade: fireGrade(seconds), ratio: Number(fireRatio(seconds).toFixed(6)) });
}

const incomeCases = [
	{ base: 60, options: {} },
	{ base: 60, options: { kiln: 2, serve: 3, passed: true, elapsedMs: 120000, eligible: true } },
	{ base: 100, options: { kiln: 3, serve: 2, passed: true, elapsedMs: 300000, eligible: true, firstPass: true } },
	{ base: 100, options: { kiln: 2, serve: 1, passed: true, elapsedMs: 300001, eligible: true } },
	{ base: 70, options: { kiln: 1, serve: 1, passed: false, elapsedMs: 1000, eligible: true, firstPass: true } },
];
for (const entry of incomeCases) {
	cases.incomes.push({ base: entry.base, options: entry.options, result: orderIncome(entry.base, entry.options) });
}

for (const ms of [0, 999, 65000, 300000, 3599999]) cases.elapsed.push({ ms, text: formatElapsed(ms) });

const clockCases = [
	{ started: true, helpOpen: false, hidden: false, focused: true, hasClay: true, canWork: true, kind: 'clay' },
	{ started: true, helpOpen: true, hidden: false, focused: true, hasClay: true, canWork: true, kind: 'clay' },
	{ started: true, helpOpen: false, hidden: false, focused: true, hasClay: true, canWork: true, kind: 'kiln' },
	{ started: true, helpOpen: false, hidden: false, focused: false, hasClay: true, canWork: true, kind: 'kiln' },
	{ started: false, helpOpen: false, hidden: false, focused: true, hasClay: true, canWork: true, kind: 'clay' },
	{ started: true, helpOpen: false, hidden: false, focused: true, hasClay: false, canWork: true, kind: 'clay' },
	{ started: true, helpOpen: false, hidden: false, focused: true, hasClay: true, canWork: true, kind: 'citymap' },
];
for (const flags of clockCases) cases.clocks.push({ flags, result: clockPolicy(flags) });

mkdirSync(dirname(out), { recursive: true });
writeFileSync(out, JSON.stringify(cases, null, '\t') + '\n', 'utf8');
console.log(`golden 写入 ${out}`);
console.log(JSON.stringify(cases.bands));
console.log(JSON.stringify(cases.incomes[1].result));
