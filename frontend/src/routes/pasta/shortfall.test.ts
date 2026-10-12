import '@testing-library/jest-dom/vitest';
import { cleanup, render, screen } from '@testing-library/svelte';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { ApiError } from '../../lib/api/errors';
import type { ProgressPayload, ShortfallCard } from '../../lib/api/types';

vi.hoisted(() => {
	vi.stubGlobal('matchMedia', () => ({
		matches: false,
		addEventListener() {},
		removeEventListener() {}
	}));
});

vi.mock('$app/navigation', () => ({ goto: vi.fn() }));
vi.mock('$app/state', async () => {
	const { SvelteURL } = await import('svelte/reactivity');
	return { page: { url: new SvelteURL('http://localhost/app/pasta') } };
});
vi.mock('$app/paths', () => ({ resolve: (path: string) => `/app${path === '/' ? '/' : path}` }));

const apiMock = vi.hoisted(() => ({ get: vi.fn() }));
vi.mock('../../lib/api/index', () => ({ api: apiMock }));
vi.mock('../../lib/session.svelte', () => ({
	session: { status: 'ready', user: { email: 'ana@example.com' }, error: null }
}));

import Page from './+page.svelte';

const progress: ProgressPayload = {
	order: 'recent',
	summary: {
		total_copies: 5,
		distinct_variants: 3,
		estimated_value: { amount: '12.50', currency: 'USD' },
		unpriced_copies: 0
	},
	sets: []
};

const cards: ShortfallCard[] = [
	{ card_number: 'OP01-001', name: 'Zoro', missing: 2, decks: [{ id: 1, name: 'Verde' }] }
];

const deferred = <T,>() => {
	let resolve!: (value: T) => void;
	let reject!: (error: unknown) => void;
	const promise = new Promise<T>((res, rej) => {
		resolve = res;
		reject = rej;
	});
	return { promise, resolve, reject };
};

const route = (progressResult: Promise<unknown>, shortfallResult: Promise<unknown>) =>
	apiMock.get.mockImplementation((path: string) =>
		path === '/api/decks/shortfall' ? shortfallResult : progressResult
	);

describe('pasta/+page.svelte: falta dos decks (SDEC-40..42)', () => {
	beforeEach(() => apiMock.get.mockReset());
	afterEach(cleanup);

	it('cada parte aparece quando a sua chega, em qualquer ordem', async () => {
		const progressD = deferred<ProgressPayload>();
		const shortfallD = deferred<ShortfallCard[]>();
		route(progressD.promise, shortfallD.promise);
		render(Page);

		shortfallD.resolve(cards);
		await screen.findByRole('heading', { level: 2, name: 'Faltando para os baralhos' });
		expect(screen.queryByRole('heading', { name: 'Progresso por set' })).not.toBeInTheDocument();

		progressD.resolve(progress);
		await screen.findByRole('heading', { level: 2, name: 'Progresso por set' });
		expect(screen.getByRole('heading', { name: 'Faltando para os baralhos' })).toBeInTheDocument();
	});

	it('o bloco vem antes do primeiro link de ação (SDEC-40)', async () => {
		route(Promise.resolve(progress), Promise.resolve(cards));
		render(Page);

		const block = await screen.findByRole('heading', { name: 'Faltando para os baralhos' });
		const csv = await screen.findByRole('link', { name: 'Baixar minha coleção (CSV)' });
		expect(block.compareDocumentPosition(csv) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy();
	});

	it('sem cartas faltando, nada é mostrado (SDEC-41)', async () => {
		route(Promise.resolve(progress), Promise.resolve([]));
		render(Page);

		await screen.findByRole('link', { name: 'Lista de desejos' });
		expect(screen.queryByRole('heading', { name: 'Faltando para os baralhos' })).not.toBeInTheDocument();
	});

	it('falha do shortfall não altera indicadores nem sets (SDEC-42)', async () => {
		route(
			Promise.resolve(progress),
			Promise.reject(new ApiError(500, 'internal_error', 'Falha no shortfall.', {}))
		);
		render(Page);

		await screen.findByText('Falha no shortfall.');
		expect(screen.getByRole('heading', { level: 2, name: 'Progresso por set' })).toBeInTheDocument();
		expect(screen.getByRole('link', { name: 'Lista de desejos' })).toBeInTheDocument();
	});
});
