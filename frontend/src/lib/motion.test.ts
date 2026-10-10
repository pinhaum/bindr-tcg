import { afterEach, describe, expect, it, vi } from 'vitest';

async function loadDuration(reduce: boolean) {
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
	return (await import('./motion')).duration;
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
