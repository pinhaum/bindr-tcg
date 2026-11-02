import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { afterEach, describe, expect, it, vi } from 'vitest';

const tokensCss = readFileSync(
	join(dirname(fileURLToPath(import.meta.url)), 'styles', 'tokens.css'),
	'utf8'
);

async function loadMotion(reduce: boolean) {
	vi.resetModules();
	vi.stubGlobal(
		'matchMedia',
		vi.fn((query: string) => ({
			matches: reduce && query === '(prefers-reduced-motion: reduce)',
			media: query,
			addEventListener: vi.fn(),
			removeEventListener: vi.fn()
		}))
	);
	return import('./motion');
}

async function loadDuration(reduce: boolean) {
	return (await loadMotion(reduce)).duration;
}

describe('duration', () => {
	afterEach(() => {
		vi.unstubAllGlobals();
	});

	it('devolve a duração informada sem prefers-reduced-motion', async () => {
		const duration = await loadDuration(false);

		expect(duration(200)).toBe(200);
	});

	it('devolve 0 com prefers-reduced-motion: reduce', async () => {
		const duration = await loadDuration(true);

		expect(duration(200)).toBe(0);
	});
});

function referenceBezier(x1: number, y1: number, x2: number, y2: number, x: number): number {
	const point = (t: number, a: number, b: number) =>
		3 * (1 - t) ** 2 * t * a + 3 * (1 - t) * t ** 2 * b + t ** 3;
	const steps = 200000;
	let best = 0;
	let bestGap = Infinity;
	for (let i = 0; i <= steps; i++) {
		const t = i / steps;
		const gap = Math.abs(point(t, x1, x2) - x);
		if (gap < bestGap) {
			bestGap = gap;
			best = t;
		}
	}
	return point(best, y1, y2);
}

describe('easeStandard', () => {
	afterEach(() => {
		vi.unstubAllGlobals();
	});

	it('mantém os extremos em 0 e 1', async () => {
		const { easeStandard } = await loadMotion(false);
		expect(easeStandard(0)).toBe(0);
		expect(easeStandard(1)).toBe(1);
	});

	it('é monotônica em 0..1', async () => {
		const { easeStandard } = await loadMotion(false);
		let previous = easeStandard(0);
		for (let i = 1; i <= 20; i++) {
			const current = easeStandard(i * 0.05);
			expect(current).toBeGreaterThanOrEqual(previous);
			previous = current;
		}
	});

	it.each([0.25, 0.5])('bate com cubic-bezier(0.2, 0, 0, 1) em %s', async (x) => {
		const { easeStandard } = await loadMotion(false);
		expect(easeStandard(x)).toBeCloseTo(referenceBezier(0.2, 0, 0, 1, x), 3);
	});

	it('usa os quatro números de --ease-standard em tokens.css', () => {
		const match = tokensCss.match(/--ease-standard:\s*cubic-bezier\(([^)]*)\)/);

		expect(match?.[1].split(',').map(Number)).toEqual([0.2, 0, 0, 1]);
	});
});

describe('cubicBezier', () => {
	afterEach(() => {
		vi.unstubAllGlobals();
	});

	it('com pontos de controle na diagonal é linear', async () => {
		const { cubicBezier } = await loadMotion(false);
		const linear = cubicBezier(1 / 3, 1 / 3, 2 / 3, 2 / 3);

		expect(linear(0.3)).toBeCloseTo(0.3, 5);
	});
});
