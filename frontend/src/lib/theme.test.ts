import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

const QUERY = '(prefers-color-scheme: dark)';

function setup({ preference = 'system', dark = false, setItemThrows = false } = {}) {
	vi.resetModules();
	const root = document.documentElement;
	root.setAttribute('data-theme-preference', preference);
	root.setAttribute('data-theme', preference === 'system' ? (dark ? 'dark' : 'light') : preference);

	const mql = {
		matches: dark,
		addEventListener: vi.fn(),
		removeEventListener: vi.fn()
	};
	vi.stubGlobal('matchMedia', vi.fn((q: string) => (q === QUERY ? mql : { matches: false })));
	const setItem = vi.fn(() => {
		if (setItemThrows) throw new Error('QuotaExceededError');
	});
	vi.stubGlobal('localStorage', { getItem: vi.fn(), setItem });
	return { root, mql, setItem };
}

const changeListener = (mql: ReturnType<typeof setup>['mql']) =>
	mql.addEventListener.mock.calls.at(-1)?.[1] as () => void;

describe('theme', () => {
	beforeEach(() => {
		document.documentElement.removeAttribute('data-theme');
		document.documentElement.removeAttribute('data-theme-preference');
	});
	afterEach(() => {
		vi.unstubAllGlobals();
	});

	it('inicia a preferência de data-theme-preference', async () => {
		setup({ preference: 'dark' });
		const { theme } = await import('./theme.svelte');

		expect(theme.preference).toBe('dark');
	});

	it('valor ausente ou desconhecido inicia como system', async () => {
		setup({ preference: 'sepia' });
		const { theme } = await import('./theme.svelte');

		expect(theme.preference).toBe('system');
	});

	it('setPreference("light") grava e aplica data-theme="light"', async () => {
		const { root, setItem } = setup({ dark: true });
		const { theme, setPreference } = await import('./theme.svelte');

		setPreference('light');

		expect(setItem).toHaveBeenCalledWith('bindr-theme', 'light');
		expect(root.getAttribute('data-theme')).toBe('light');
		expect(root.getAttribute('data-theme-preference')).toBe('light');
		expect(theme.preference).toBe('light');
	});

	it('localStorage.setItem que lança não quebra a troca', async () => {
		const { root } = setup({ setItemThrows: true });
		const { theme, setPreference } = await import('./theme.svelte');

		expect(() => setPreference('dark')).not.toThrow();
		expect(root.getAttribute('data-theme')).toBe('dark');
		expect(theme.preference).toBe('dark');
	});

	it('com system, o evento change do matchMedia reaplica', async () => {
		const { root, mql } = setup({ dark: false });
		await import('./theme.svelte');
		expect(root.getAttribute('data-theme')).toBe('light');

		mql.matches = true;
		changeListener(mql)();

		expect(root.getAttribute('data-theme')).toBe('dark');
	});

	it('ao sair de system, o ouvinte é removido', async () => {
		const { mql } = setup();
		const { setPreference } = await import('./theme.svelte');
		const listener = changeListener(mql);

		setPreference('dark');

		expect(mql.removeEventListener).toHaveBeenCalledWith('change', listener);
	});

	it('ao voltar para system, resolve pelo matchMedia e volta a ouvir', async () => {
		const { root, mql } = setup({ preference: 'light', dark: true });
		const { setPreference } = await import('./theme.svelte');
		expect(mql.addEventListener).not.toHaveBeenCalled();

		setPreference('system');

		expect(root.getAttribute('data-theme')).toBe('dark');
		expect(mql.addEventListener).toHaveBeenCalledTimes(1);
	});
});
