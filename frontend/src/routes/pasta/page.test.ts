import '@testing-library/jest-dom/vitest';
import { cleanup, fireEvent, render, screen, within } from '@testing-library/svelte';
import { tick } from 'svelte';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { ApiError } from '../../lib/api/errors';
import type { ProgressPayload } from '../../lib/api/types';

const media = vi.hoisted(() => {
	const state = { matches: false };
	vi.stubGlobal('matchMedia', () => ({
		get matches() {
			return state.matches;
		},
		addEventListener() {},
		removeEventListener() {}
	}));
	return state;
});

const nav = vi.hoisted(() => ({ goto: vi.fn() }));
vi.mock('$app/navigation', () => nav);

vi.mock('$app/state', async () => {
	const { SvelteURL } = await import('svelte/reactivity');
	return { page: { url: new SvelteURL('http://localhost/app/pasta') } };
});

vi.mock('$app/paths', () => ({ resolve: (path: string) => `/app${path === '/' ? '/' : path}` }));

const apiMock = vi.hoisted(() => ({ get: vi.fn() }));
vi.mock('../../lib/api/index', () => ({ api: apiMock }));

vi.mock('../../lib/components/DeckShortfall.svelte', () => ({ default: () => {} }));

const sessionState = vi.hoisted(() => ({
	status: 'ready',
	user: { email: 'ana@example.com' } as { email: string } | null,
	error: null
}));
vi.mock('../../lib/session.svelte', () => ({ session: sessionState }));

import { page as pageState } from '$app/state';
import { shell } from '../../lib/shell.svelte';
import { load } from './+page';
import Page from './+page.svelte';

const payload = (order: 'recent' | 'code' = 'recent'): ProgressPayload => ({
	order,
	summary: {
		total_copies: 5,
		distinct_variants: 3,
		estimated_value: { amount: '12.50', currency: 'USD' },
		unpriced_copies: 0
	},
	sets: [
		{
			code: 'OP02',
			name: 'Paramount War',
			owned_numbers: 2,
			base_size: 10,
			completion_percent: 20,
			parallel_owned: 0,
			parallel_total: 3,
			value: { amount: '1.00', currency: 'USD' }
		},
		{
			code: 'OP01',
			name: 'Romance Dawn',
			owned_numbers: 4,
			base_size: 10,
			completion_percent: 40,
			parallel_owned: 1,
			parallel_total: 3,
			value: { amount: '2.00', currency: 'USD' }
		}
	]
});

const deferred = <T,>() => {
	let resolve!: (value: T) => void;
	let reject!: (error: unknown) => void;
	const promise = new Promise<T>((res, rej) => {
		resolve = res;
		reject = rej;
	});
	return { promise, resolve, reject };
};

const setUrl = (search = '') => {
	(pageState.url as { search: string }).search = search;
};

const setWide = (wide: boolean) => {
	media.matches = wide;
};

describe('pasta/+page.ts', () => {
	beforeEach(() => {
		sessionState.user = { email: 'ana@example.com' };
	});

	it('sem sessão redireciona para entrar com return_to, sem chamar o cliente (SPAS-03)', async () => {
		sessionState.user = null;
		apiMock.get.mockReset();
		const url = new URL('http://localhost/app/pasta?order=code');

		await expect(load({ parent: async () => ({}), url } as never)).rejects.toMatchObject({
			status: 307,
			location: '/app/entrar?return_to=%2Fapp%2Fpasta%3Forder%3Dcode'
		});
		expect(apiMock.get).not.toHaveBeenCalled();
	});

	it('com sessão não redireciona', async () => {
		const url = new URL('http://localhost/app/pasta');
		await expect(load({ parent: async () => ({}), url } as never)).resolves.toBeUndefined();
	});
});

describe('pasta/+page.svelte', () => {
	beforeEach(() => {
		apiMock.get.mockReset();
		apiMock.get.mockResolvedValue(payload());
		sessionState.user = { email: 'ana@example.com' };
		shell.aside = null;
		setUrl();
		setWide(false);
	});
	afterEach(() => {
		cleanup();
		vi.useRealTimers();
	});

	it('título e h1 (SPAS-01)', async () => {
		render(Page);

		expect(screen.getByRole('heading', { level: 1, name: 'Minha pasta' })).toBeInTheDocument();
		expect(document.title).toBe('Minha pasta — Bindr');
		await screen.findByRole('heading', { level: 2, name: 'Progresso por set' });
	});

	it('chama GET /api/progress sem order quando a URL não tem (SPAS-04)', async () => {
		render(Page);
		await screen.findByRole('heading', { level: 2, name: 'Progresso por set' });

		expect(apiMock.get).toHaveBeenCalledTimes(1);
		expect(apiMock.get).toHaveBeenCalledWith('/api/progress');
	});

	it('sem sessão (logout em curso) não consulta a API', async () => {
		sessionState.user = null;
		render(Page);
		await tick();

		expect(apiMock.get).not.toHaveBeenCalled();
	});

	it('repassa o order da URL (SPAS-04)', async () => {
		setUrl('?order=code');
		render(Page);
		await screen.findByRole('heading', { level: 2, name: 'Progresso por set' });

		expect(apiMock.get).toHaveBeenCalledWith('/api/progress?order=code');
	});

	it('descarta a resposta antiga quando a URL muda (SPAS-05)', async () => {
		const first = deferred<ProgressPayload>();
		const second = deferred<ProgressPayload>();
		apiMock.get.mockReturnValueOnce(first.promise).mockReturnValueOnce(second.promise);
		render(Page);

		setUrl('?order=code');
		await tick();
		second.resolve(payload('code'));
		await screen.findByRole('link', { name: 'Por código', current: 'page' });
		first.resolve(payload('recent'));
		await Promise.resolve();

		expect(screen.getByRole('link', { name: 'Por código', current: 'page' })).toBeInTheDocument();
	});

	it('"Carregando pasta…" e aria-busy só após 200 ms (SPAS-06)', async () => {
		vi.useFakeTimers();
		apiMock.get.mockReturnValue(new Promise(() => {}));
		render(Page);

		expect(screen.queryByText('Carregando pasta…')).not.toBeInTheDocument();
		expect(document.querySelector('[aria-busy="true"]')).toBeNull();

		await vi.advanceTimersByTimeAsync(250);

		expect(screen.getByText('Carregando pasta…')).toBeInTheDocument();
		expect(document.querySelector('[aria-busy="true"]')).not.toBeNull();
	});

	it('erro mostra a message e "Tentar novamente" repete a consulta (SPAS-07)', async () => {
		apiMock.get.mockRejectedValueOnce(
			new ApiError(500, 'internal_error', 'Algo deu errado. Tente de novo.', {})
		);
		render(Page);

		expect(await screen.findByText('Algo deu errado. Tente de novo.')).toBeInTheDocument();

		await fireEvent.click(screen.getByRole('button', { name: 'Tentar novamente' }));

		await screen.findByRole('heading', { level: 2, name: 'Progresso por set' });
		expect(apiMock.get).toHaveBeenCalledTimes(2);
		expect(screen.queryByText('Algo deu errado. Tente de novo.')).not.toBeInTheDocument();
	});

	it('chips de ordem marcados por data.order, não pela query (SPAS-17)', async () => {
		setUrl('?order=xyz');
		apiMock.get.mockResolvedValue(payload('recent'));
		render(Page);

		const list = await screen.findByRole('list', { name: 'Ordenar sets' });
		const recent = within(list).getByRole('link', { name: 'Recentes' });
		const byCode = within(list).getByRole('link', { name: 'Por código' });

		expect(recent).toHaveAttribute('aria-current', 'page');
		expect(byCode).not.toHaveAttribute('aria-current');
		expect(recent).toHaveAttribute('href', '/app/pasta?order=recent');
		expect(byCode).toHaveAttribute('href', '/app/pasta?order=code');
		expect(recent).toHaveAttribute('data-sveltekit-reset', 'false');
	});

	it('lista de sets na ordem de data.sets, nomeada pelo título, sem contagem (SPAS-18)', async () => {
		render(Page);

		const list = await screen.findByRole('list', { name: 'Progresso por set' });
		const items = within(list).getAllByRole('listitem');

		expect(items).toHaveLength(2);
		expect(items[0]).toHaveTextContent('OP02');
		expect(items[1]).toHaveTextContent('OP01');
		expect(screen.queryByText(/\b2 sets\b/)).not.toBeInTheDocument();
	});

	it('ações secundárias e adicionar cartas (SPAS-24, SPAS-25)', async () => {
		render(Page);
		await screen.findByRole('heading', { level: 2, name: 'Progresso por set' });

		const csv = screen.getByRole('link', { name: 'Baixar minha coleção (CSV)' });
		const imp = screen.getByRole('link', { name: 'Importar coleção' });
		const wishlist = screen.getByRole('link', { name: 'Lista de desejos' });
		const add = screen.getByRole('link', { name: 'Adicionar cartas à pasta' });

		expect(csv).toHaveAttribute('href', '/collection/export');
		expect(csv).toHaveAttribute('data-sveltekit-reload');
		expect(imp).toHaveAttribute('href', '/collection/import');
		expect(imp).toHaveAttribute('data-sveltekit-reload');
		expect(wishlist).toHaveAttribute('href', '/app/pasta/desejos');
		expect(wishlist).not.toHaveAttribute('data-sveltekit-reload');
		expect(add).toHaveAttribute('href', '/app');
		expect(add).not.toHaveAttribute('data-sveltekit-reload');
	});

	it('com wide, shell.aside recebe "Adicionar cartas" e volta a null ao desmontar (AD-028)', async () => {
		setWide(true);
		const { unmount } = render(Page);
		await screen.findByRole('heading', { level: 2, name: 'Progresso por set' });

		expect(shell.aside).not.toBeNull();
		expect(screen.queryByRole('link', { name: 'Adicionar cartas à pasta' })).not.toBeInTheDocument();

		unmount();

		expect(shell.aside).toBeNull();
	});
});
