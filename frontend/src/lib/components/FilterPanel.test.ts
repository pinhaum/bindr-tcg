import '@testing-library/jest-dom/vitest';
import { cleanup, fireEvent, render, screen, waitFor, within } from '@testing-library/svelte';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { ActiveFilters, FilterOptions } from '../api/types';
import { ApiError } from '../api/errors';

const mocks = vi.hoisted(() => ({
	goto: vi.fn(),
	ensureFilterOptions: vi.fn(),
	retryFilterOptions: vi.fn()
}));

vi.mock('$app/paths', () => ({ resolve: (path: string) => path }));
vi.mock('$app/navigation', () => ({ goto: mocks.goto }));
vi.mock('../catalog/filter-options.svelte', async (importActual) => ({
	...(await importActual<typeof import('../catalog/filter-options.svelte')>()),
	ensureFilterOptions: mocks.ensureFilterOptions,
	retryFilterOptions: mocks.retryFilterOptions
}));

import { filterOptions } from '../catalog/filter-options.svelte';
import FilterPanel from './FilterPanel.svelte';

const options: FilterOptions = {
	colors: ['Red', 'Green', 'Blue'],
	card_types: ['CHARACTER', 'EVENT'],
	rarities: ['C', 'SR'],
	sets: [
		{ code: 'OP01', name: 'Romance Dawn' },
		{ code: 'OP02', name: 'Paramount War' }
	]
};

const enc = (s: string) => s.replace(/\[\]/g, '%5B%5D');

const setup = (filters: ActiveFilters = {}, signedIn = false) =>
	render(FilterPanel, { filters, signedIn });

beforeEach(() => {
	mocks.goto.mockReset();
	mocks.ensureFilterOptions.mockReset();
	mocks.retryFilterOptions.mockReset();
	filterOptions.value = options;
	filterOptions.error = null;
	filterOptions.loading = false;
});

afterEach(cleanup);

describe('FilterPanel', () => {
	it('chama ensureFilterOptions ao montar', () => {
		setup();
		expect(mocks.ensureFilterOptions).toHaveBeenCalledTimes(1);
	});

	it('cor, tipo e raridade na ordem das opções, com o tipo em inicial maiúscula e valor cru no href', () => {
		setup();
		const colors = within(screen.getByRole('group', { name: 'Cor' })).getAllByRole('link');
		expect(colors.map((a) => a.textContent?.trim())).toEqual(['Red', 'Green', 'Blue']);
		const types = within(screen.getByRole('group', { name: 'Tipo' })).getAllByRole('link');
		expect(types.map((a) => a.textContent?.trim())).toEqual(['Character', 'Event']);
		expect(types[0]).toHaveAttribute('href', `/?${enc('card_types[]')}=CHARACTER`);
		const rarities = within(screen.getByRole('group', { name: 'Raridade' })).getAllByRole('link');
		expect(rarities.map((a) => a.textContent?.trim())).toEqual(['C', 'SR']);
	});

	it('chips de cor levam o quadrado neutro', () => {
		setup();
		const red = within(screen.getByRole('group', { name: 'Cor' })).getByRole('link', { name: 'Red' });
		expect(red.querySelector('.swatch')).not.toBeNull();
		const c = within(screen.getByRole('group', { name: 'Raridade' })).getByRole('link', { name: 'C' });
		expect(c.querySelector('.swatch')).toBeNull();
	});

	it('chip ativo leva ao href sem o valor; inativo, com o valor acrescentado', () => {
		setup({ colors: ['Red'] });
		const group = within(screen.getByRole('group', { name: 'Cor' }));
		expect(group.getByRole('link', { name: 'Remover filtro Cor: Red' })).toHaveAttribute('href', '/');
		expect(group.getByRole('link', { name: 'Green' })).toHaveAttribute(
			'href',
			`/?${enc('colors[]')}=Red&${enc('colors[]')}=Green`
		);
	});

	describe('seletor de set', () => {
		const select = () => screen.getByRole('combobox', { name: 'Set' }) as HTMLSelectElement;
		const selectedText = () => select().selectedOptions[0].textContent?.trim();

		it('oferece "Todos os sets" e os sets pelo nome, com "Todos os sets" por padrão', () => {
			setup();
			const texts = Array.from(select().options).map((o) => o.textContent?.trim());
			expect(texts).toEqual(['Todos os sets', 'Romance Dawn', 'Paramount War']);
			expect(selectedText()).toBe('Todos os sets');
		});

		it('um set ativo vem selecionado', () => {
			setup({ sets: ['OP02'] });
			expect(selectedText()).toBe('Paramount War');
		});

		it('"Aplicar" com outro set navega só com ele, mantendo os demais filtros e sem page', async () => {
			setup({ sets: ['OP01'], colors: ['Red'], sort: 'name' } as ActiveFilters);
			await fireEvent.change(select(), { target: { value: 'OP02' } });
			await fireEvent.click(screen.getByRole('button', { name: 'Aplicar' }));
			expect(mocks.goto).toHaveBeenCalledTimes(1);
			const [href, opts] = mocks.goto.mock.calls[0];
			expect(href).toBe(`/?${enc('sets[]')}=OP02&${enc('colors[]')}=Red&sort=name`);
			expect(href).not.toContain('page');
			expect(opts).toEqual({ reset: false });
		});

		it('"Todos os sets" remove sets', async () => {
			setup({ sets: ['OP01'], colors: ['Red'] });
			await fireEvent.change(select(), { target: { value: '' } });
			await fireEvent.click(screen.getByRole('button', { name: 'Aplicar' }));
			expect(mocks.goto).toHaveBeenCalledWith(`/?${enc('colors[]')}=Red`, { reset: false });
		});

		it('dois sets ativos mostram "2 sets selecionados" e "Aplicar" os mantém, sem page', async () => {
			setup({ sets: ['OP01', 'OP02'], page: 3 } as ActiveFilters);
			expect(selectedText()).toBe('2 sets selecionados');
			await fireEvent.click(screen.getByRole('button', { name: 'Aplicar' }));
			expect(mocks.goto).toHaveBeenCalledWith(
				`/?${enc('sets[]')}=OP01&${enc('sets[]')}=OP02`,
				{ reset: false }
			);
		});

		it('set ativo fora das opções ganha uma opção com o próprio código, selecionada', () => {
			setup({ sets: ['ZZ99'] });
			const texts = Array.from(select().options).map((o) => o.textContent?.trim());
			expect(texts).toEqual(['Todos os sets', 'ZZ99', 'Romance Dawn', 'Paramount War']);
			expect(selectedText()).toBe('ZZ99');
		});

		it('sem mais de um set ativo, a opção "N sets selecionados" não existe', () => {
			setup({ sets: ['OP01'] });
			expect(screen.queryByRole('option', { name: /sets selecionados/ })).toBeNull();
		});
	});

	describe('posse', () => {
		it('com sessão, três chips, "Todas" com aria-current="true" sem filtro', () => {
			setup({}, true);
			const group = within(screen.getByRole('group', { name: 'Posse' }));
			expect(group.getAllByRole('link').map((a) => a.textContent?.trim())).toEqual([
				'Todas',
				'Tenho',
				'Não tenho'
			]);
			const all = group.getByRole('link', { name: 'Todas' });
			expect(all).toHaveAttribute('aria-current', 'true');
			expect(all.textContent).not.toContain('×');
			expect(group.getByRole('link', { name: 'Tenho' })).toHaveAttribute('href', '/?owned=owned');
			expect(group.getByRole('link', { name: 'Não tenho' })).toHaveAttribute('href', '/?owned=missing');
		});

		it('com filtro, o chip ativo remove owned e "Todas" também', () => {
			setup({ owned: 'owned' }, true);
			const group = within(screen.getByRole('group', { name: 'Posse' }));
			expect(group.getByRole('link', { name: 'Remover filtro Posse: Tenho' })).toHaveAttribute('href', '/');
			const all = group.getByRole('link', { name: 'Todas' });
			expect(all).toHaveAttribute('href', '/');
			expect(all).not.toHaveAttribute('aria-current');
		});

		it('sem sessão, nenhum controle de posse, mesmo com owned na URL', () => {
			setup({ owned: 'owned' }, false);
			expect(screen.queryByRole('group', { name: 'Posse' })).toBeNull();
			expect(screen.queryByRole('link', { name: /Tenho|Todas/ })).toBeNull();
		});
	});

	describe('falha das opções', () => {
		beforeEach(() => {
			filterOptions.value = null;
			filterOptions.error = new ApiError(500, 'internal_error', 'Erro interno. Tente novamente.');
		});

		it('mostra a message e "Tentar novamente" no lugar dos grupos', () => {
			setup({}, true);
			expect(screen.getByText('Erro interno. Tente novamente.')).toBeInTheDocument();
			expect(screen.getByRole('button', { name: 'Tentar novamente' })).toBeInTheDocument();
			expect(screen.queryByRole('group')).toBeNull();
			expect(screen.queryByRole('combobox')).toBeNull();
		});

		it('anuncia a message com role="alert"', () => {
			setup();
			expect(screen.getByRole('alert')).toHaveTextContent('Erro interno. Tente novamente.');
		});

		it('"Tentar novamente" chama retryFilterOptions', async () => {
			setup();
			await fireEvent.click(screen.getByRole('button', { name: 'Tentar novamente' }));
			expect(mocks.retryFilterOptions).toHaveBeenCalledTimes(1);
		});
	});

	it('sem valor nem erro (carregando), mostra "Carregando filtros…" em status, sem grupos nem erro', () => {
		filterOptions.value = null;
		filterOptions.loading = true;
		setup();
		expect(screen.getByRole('status')).toHaveTextContent('Carregando filtros…');
		expect(screen.queryByRole('group')).toBeNull();
		expect(screen.queryByRole('button', { name: 'Tentar novamente' })).toBeNull();
	});

	it('chip de tipo remove com o nome do valor exibido', () => {
		setup({ card_types: ['CHARACTER'] });
		const group = within(screen.getByRole('group', { name: 'Tipo' }));
		expect(group.getByRole('link', { name: 'Remover filtro Tipo: Character' })).toBeInTheDocument();
	});

	describe('transições reativas', () => {
		it('carregando → valor troca o status pelos grupos', async () => {
			filterOptions.value = null;
			filterOptions.loading = true;
			setup();
			expect(screen.getByRole('status')).toBeInTheDocument();
			filterOptions.value = options;
			filterOptions.loading = false;
			await waitFor(() => expect(screen.getByRole('group', { name: 'Cor' })).toBeInTheDocument());
			expect(screen.queryByRole('status')).toBeNull();
		});

		it('erro → valor troca o alerta pelos grupos', async () => {
			filterOptions.value = null;
			filterOptions.error = new ApiError(500, 'internal_error', 'Erro interno. Tente novamente.');
			setup();
			expect(screen.getByRole('alert')).toBeInTheDocument();
			filterOptions.value = options;
			filterOptions.error = null;
			await waitFor(() => expect(screen.getByRole('group', { name: 'Cor' })).toBeInTheDocument());
			expect(screen.queryByRole('alert')).toBeNull();
		});
	});
});
