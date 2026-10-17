import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

const dir = dirname(fileURLToPath(import.meta.url));
const appHtml = readFileSync(join(dir, '..', 'app.html'), 'utf8');
const script = /<script>([\s\S]*?)<\/script>/.exec(appHtml)?.[1] ?? '';

function run({ stored, dark = false, throws = false }: { stored?: string; dark?: boolean; throws?: boolean }) {
	vi.stubGlobal('localStorage', {
		getItem: vi.fn(() => {
			if (throws) throw new Error('SecurityError');
			return stored ?? null;
		})
	});
	vi.stubGlobal(
		'matchMedia',
		vi.fn((query: string) => ({ matches: dark && query === '(prefers-color-scheme: dark)' }))
	);
	new Function(script)();
	const root = document.documentElement;
	return { theme: root.getAttribute('data-theme'), preference: root.getAttribute('data-theme-preference') };
}

describe('script inline de tema em app.html', () => {
	beforeEach(() => {
		document.documentElement.removeAttribute('data-theme');
		document.documentElement.removeAttribute('data-theme-preference');
	});
	afterEach(() => {
		vi.unstubAllGlobals();
		vi.restoreAllMocks();
	});

	it('fica antes de %sveltekit.head%', () => {
		expect(script).not.toBe('');
		expect(appHtml.indexOf('<script>')).toBeLessThan(appHtml.indexOf('%sveltekit.head%'));
	});

	it('aplica light guardado', () => {
		expect(run({ stored: 'light', dark: true })).toEqual({ theme: 'light', preference: 'light' });
	});

	it('aplica dark guardado', () => {
		expect(run({ stored: 'dark' })).toEqual({ theme: 'dark', preference: 'dark' });
	});

	it('resolve system para claro', () => {
		expect(run({ stored: 'system', dark: false })).toEqual({ theme: 'light', preference: 'system' });
	});

	it('resolve system para escuro', () => {
		expect(run({ stored: 'system', dark: true })).toEqual({ theme: 'dark', preference: 'system' });
	});

	it('sem valor guardado vira system', () => {
		expect(run({ dark: true })).toEqual({ theme: 'dark', preference: 'system' });
	});

	it('valor desconhecido vira system', () => {
		expect(run({ stored: 'sepia', dark: false })).toEqual({ theme: 'light', preference: 'system' });
	});

	it('localStorage que lança vira system sem console.error', () => {
		const error = vi.spyOn(console, 'error').mockImplementation(() => {});
		expect(run({ throws: true, dark: true })).toEqual({ theme: 'dark', preference: 'system' });
		expect(error).not.toHaveBeenCalled();
	});
});
