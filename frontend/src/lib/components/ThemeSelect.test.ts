import '@testing-library/jest-dom/vitest';
import { cleanup, fireEvent, render, screen } from '@testing-library/svelte';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

vi.hoisted(() => {
	vi.stubGlobal('matchMedia', () => ({ matches: false, addEventListener() {}, removeEventListener() {} }));
});

const mocks = vi.hoisted(() => ({ setPreference: vi.fn() }));
vi.mock('../theme.svelte', async (importOriginal) => ({
	...(await importOriginal<typeof import('../theme.svelte')>()),
	setPreference: mocks.setPreference
}));

import { theme } from '../theme.svelte';
import ThemeSelect from './ThemeSelect.svelte';

describe('ThemeSelect', () => {
	beforeEach(() => {
		mocks.setPreference.mockReset();
		theme.preference = 'system';
	});
	afterEach(cleanup);

	it('tem o rótulo "Tema" e as três opções na ordem', () => {
		render(ThemeSelect);

		const select = screen.getByLabelText('Tema');
		expect(select.tagName).toBe('SELECT');
		const options = screen.getAllByRole('option');
		expect(options.map((o) => o.textContent)).toEqual(['Sistema', 'Claro', 'Escuro']);
		expect(options.map((o) => (o as HTMLOptionElement).value)).toEqual(['system', 'light', 'dark']);
	});

	it('começa com o valor de theme.preference', () => {
		theme.preference = 'dark';
		render(ThemeSelect);

		expect(screen.getByLabelText('Tema')).toHaveValue('dark');
	});

	it('ao trocar chama setPreference com o valor escolhido', async () => {
		render(ThemeSelect);

		await fireEvent.change(screen.getByLabelText('Tema'), { target: { value: 'light' } });

		expect(mocks.setPreference).toHaveBeenCalledExactlyOnceWith('light');
	});
});
