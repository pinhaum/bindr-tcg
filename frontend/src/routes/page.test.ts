import '@testing-library/jest-dom/vitest';
import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/svelte';
import { tick } from 'svelte';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { ApiError, networkError } from '../lib/api/errors';
import type { CatalogCard, CatalogMeta } from '../lib/api/types';

const nav = vi.hoisted(() => ({ goto: vi.fn() }));
vi.mock('$app/navigation', () => nav);

vi.mock('$app/state', async () => {
	const { SvelteURL } = await import('svelte/reactivity');
	return { page: { url: new SvelteURL('http://localhost/app') }, navigating: { to: null } };
});

vi.mock('$app/paths', () => ({ resolve: (path: string) => `/app${path === '/' ? '/' : path}` }));

const getEnvelope = vi.hoisted(() => vi.fn());
vi.mock('../lib/api/index', () => ({ api: { getEnvelope } }));

import { page } from '$app/state';
import { session } from '../lib/session.svelte';
import Page from './+page.svelte';

const card = (number: string, name: string): CatalogCard => ({
	card_number: number,
	name,
	card_type: 'Character',
	colors: ['Red'],
	cost: 1,
	life: null,
	power: null,
	counter: null,
	block_icon: null,
	attributes: [],
	traits: [],
	effect_text: null,
	trigger_text: null,
	set: { code: 'OP01', name: 'Romance Dawn' },
	variants: [
		{
			variant_code: `tcgplayer:${number}`,
			rarity: 'C',
			art_kind: 'base',
			set: { code: 'OP01', name: 'Romance Dawn' },
			illustrator: null,
			image_url: null,
			in_source: true,
			owned_quantity: null,
			wishlist_target: null,
			price: null
		}
	]
});

const envelope = (cards: CatalogCard[], filters: CatalogMeta['active_filters'] = {}, total = cards.length) => ({
	data: cards,
	meta: { page: 1, per_page: 24, total_count: total, total_pages: 1, active_filters: filters }
});

const pagedEnvelope = (meta: Partial<CatalogMeta>) => ({
	data: [] as CatalogCard[],
	meta: { page: 1, per_page: 24, total_count: 0, total_pages: 1, active_filters: {}, ...meta }
});

const deferred = <T>() => {
	let resolve!: (value: T) => void;
	let reject!: (reason: unknown) => void;
	const promise = new Promise<T>((res, rej) => {
		resolve = res;
		reject = rej;
	});
	return { promise, resolve, reject };
};

const mockUrl = page.url as { href: string };

const goTo = async (href: string) => {
	mockUrl.href = `http://localhost${href}`;
	await tick();
};

const tileName = (name: string) => ({ name: new RegExp(`^${name} OP`) });
const findTile = (name: string) => screen.findByRole('link', tileName(name));
const getTile = (name: string) => screen.getByRole('link', tileName(name));
const queryTile = (name: string) => screen.queryByRole('link', tileName(name));

const skeletons = (container: HTMLElement) => container.querySelectorAll('ul li[aria-hidden="true"]');

describe('+page.svelte (/app, catálogo)', () => {
	beforeEach(() => {
		getEnvelope.mockReset();
		getEnvelope.mockResolvedValue(envelope([card('OP01-001', 'Zoro')]));
		nav.goto.mockReset();
		mockUrl.href = 'http://localhost/app';
		session.user = null;
	});
	afterEach(() => {
		cleanup();
		vi.useRealTimers();
	});

	it.each([
		['com sessão', { email: 'ana@example.com' }],
		['sem sessão', null]
	])('define o título e o cabeçalho de nível 1 do catálogo, sem resto do início (%s)', async (_, user) => {
		session.user = user;
		render(Page);

		expect(document.title).toBe('Catálogo — Bindr');
		expect(screen.getByRole('heading', { level: 1, name: 'Catálogo' })).toBeInTheDocument();
		await findTile('Zoro');
		expect(screen.queryByText('ana@example.com')).not.toBeInTheDocument();
		expect(screen.queryByRole('link', { name: 'Entrar' })).not.toBeInTheDocument();
		expect(screen.queryByRole('link', { name: 'Criar conta' })).not.toBeInTheDocument();
	});

	it.each([
		['/app?colors%5B%5D=Red', '?colors%5B%5D=Red'],
		['/app?colors=Red', '?colors=Red'],
		['/app?q=a+b%20c', '?q=a+b%20c'],
		['/app?zzz=1', '?zzz=1']
	])('repassa a query crua de %s para /api/catalog, sem normalizar', async (href, search) => {
		await goTo(href);
		render(Page);

		await findTile('Zoro');
		expect(getEnvelope).toHaveBeenCalledTimes(1);
		expect(getEnvelope).toHaveBeenCalledWith('/api/catalog' + search);
	});

	it('refaz a consulta quando a URL muda e mostra o termo novo no campo', async () => {
		render(Page);
		await findTile('Zoro');
		getEnvelope.mockResolvedValue(envelope([card('OP01-025', 'Roronoa Zoro')], { q: 'zoro' }));

		await goTo('/app?q=zoro');

		await findTile('Roronoa Zoro');
		expect(getEnvelope).toHaveBeenLastCalledWith('/api/catalog?q=zoro');
		expect(screen.getByLabelText('Buscar por nome ou card_number')).toHaveValue('zoro');
	});

	it('refaz a consulta quando a sessão muda com a URL igual', async () => {
		render(Page);
		await findTile('Zoro');
		expect(getEnvelope).toHaveBeenCalledTimes(1);

		session.user = { email: 'ana@example.com' };
		await tick();

		await waitFor(() => expect(getEnvelope).toHaveBeenCalledTimes(2));
		expect(getEnvelope).toHaveBeenLastCalledWith('/api/catalog');
	});

	it('refaz a consulta na saída da sessão e o convite para entrar reaparece', async () => {
		session.user = { email: 'ana@example.com' };
		render(Page);
		await findTile('Zoro');
		expect(getEnvelope).toHaveBeenCalledTimes(1);
		expect(screen.queryByRole('link', { name: 'Entrar para registrar posse' })).not.toBeInTheDocument();

		session.user = null;
		await tick();

		await waitFor(() => expect(getEnvelope).toHaveBeenCalledTimes(2));
		expect(getEnvelope).toHaveBeenLastCalledWith('/api/catalog');
		expect(await screen.findByRole('link', { name: 'Entrar para registrar posse' })).toBeInTheDocument();
	});

	it('mostra a grade de cartas e a linha de status', async () => {
		getEnvelope.mockResolvedValue(envelope([card('OP01-001', 'Zoro'), card('OP01-002', 'Luffy')]));
		render(Page);

		await findTile('Zoro');
		expect(screen.getAllByRole('listitem')).toHaveLength(2);
		expect(screen.getByText('2 cartas')).toBeInTheDocument();
	});

	it('a busca navega por goto sem reiniciar o scroll', async () => {
		getEnvelope.mockResolvedValue(envelope([card('OP01-001', 'Zoro')], { colors: ['Red'] }));
		render(Page);
		await findTile('Zoro');

		await fireEvent.input(screen.getByLabelText('Buscar por nome ou card_number'), {
			target: { value: 'luffy' }
		});
		await fireEvent.click(screen.getByRole('button', { name: 'Buscar' }));

		expect(nav.goto).toHaveBeenCalledWith('/app?q=luffy&colors%5B%5D=Red', { reset: false });
	});

	describe('vazio', () => {
		it('com busca destaca o termo e oferece limpar os filtros', async () => {
			getEnvelope.mockResolvedValue(envelope([], { q: 'zoro' }));
			render(Page);

			const term = await screen.findByText('zoro', { selector: 'strong' });
			expect(term.parentElement).toHaveTextContent('Nenhuma carta encontrada para zoro.');
			expect(screen.getAllByRole('link', { name: 'Limpar filtros' })).toHaveLength(1);
		});

		it('sem busca e sem filtro não oferece limpar', async () => {
			getEnvelope.mockResolvedValue(envelope([]));
			render(Page);

			expect(await screen.findByText('Nenhuma carta corresponde aos filtros aplicados.')).toBeInTheDocument();
			expect(screen.queryByRole('link', { name: 'Limpar filtros' })).not.toBeInTheDocument();
		});

		it('com filtro e sem busca oferece limpar, mantendo sort e dir', async () => {
			getEnvelope.mockResolvedValue(envelope([], { colors: ['Red'], sort: 'name', dir: 'desc' }));
			render(Page);

			expect(await screen.findByText('Nenhuma carta corresponde aos filtros aplicados.')).toBeInTheDocument();
			const clear = screen.getAllByRole('link', { name: 'Limpar filtros' });
			expect(clear).toHaveLength(1);
			expect(clear[0]).toHaveAttribute('href', '/app?sort=name&dir=desc');
		});

		it('com page além de total_pages mostra o vazio, o total e a paginação com "Anterior"', async () => {
			getEnvelope.mockResolvedValue(pagedEnvelope({ page: 5, total_count: 60, total_pages: 3 }));
			render(Page);

			expect(await screen.findByText('Nenhuma carta corresponde aos filtros aplicados.')).toBeInTheDocument();
			expect(screen.getByText('60 cartas')).toBeInTheDocument();
			expect(screen.getByRole('navigation', { name: 'Paginação do catálogo' })).toBeInTheDocument();
			expect(screen.getByRole('link', { name: 'Anterior' })).toHaveAttribute('href', '/app?page=4');
		});

		it('com uma só página não mostra a paginação', async () => {
			getEnvelope.mockResolvedValue(pagedEnvelope({ total_pages: 1 }));
			render(Page);

			expect(await screen.findByText('Nenhuma carta corresponde aos filtros aplicados.')).toBeInTheDocument();
			expect(screen.queryByRole('navigation', { name: 'Paginação do catálogo' })).not.toBeInTheDocument();
		});
	});

	describe('espera e erro', () => {
		it('mantém o conteúdo anterior por 200 ms e depois mostra dez tiles esqueleto', async () => {
			vi.useFakeTimers();
			const { container } = render(Page);
			await vi.advanceTimersByTimeAsync(0);
			expect(getTile('Zoro')).toBeInTheDocument();

			const second = deferred<ReturnType<typeof envelope>>();
			getEnvelope.mockReturnValue(second.promise);
			await goTo('/app?page=2');

			await vi.advanceTimersByTimeAsync(199);
			expect(getTile('Zoro')).toBeInTheDocument();
			expect(skeletons(container)).toHaveLength(0);
			expect(screen.queryByText('Carregando cartas…')).not.toBeInTheDocument();
			expect(container.querySelector('section')).toHaveAttribute('aria-busy', 'false');

			await vi.advanceTimersByTimeAsync(1);
			expect(skeletons(container)).toHaveLength(10);
			expect(container.querySelector('section')).toHaveAttribute('aria-busy', 'true');
			expect(screen.getByText('Carregando cartas…')).toBeInTheDocument();
			expect(queryTile('Zoro')).not.toBeInTheDocument();
		});

		it('na primeira carga mostra o esqueleto após 200 ms e a grade quando a resposta chega', async () => {
			vi.useFakeTimers();
			const first = deferred<ReturnType<typeof envelope>>();
			getEnvelope.mockReturnValue(first.promise);
			const { container } = render(Page);
			await vi.advanceTimersByTimeAsync(199);
			expect(skeletons(container)).toHaveLength(0);
			expect(screen.queryByText('Carregando cartas…')).not.toBeInTheDocument();

			await vi.advanceTimersByTimeAsync(1);
			expect(skeletons(container)).toHaveLength(10);
			expect(screen.getByText('Carregando cartas…')).toBeInTheDocument();

			first.resolve(envelope([card('OP01-001', 'Zoro')]));
			await vi.advanceTimersByTimeAsync(0);

			expect(getTile('Zoro')).toBeInTheDocument();
			expect(skeletons(container)).toHaveLength(0);
			expect(screen.queryByText('Carregando cartas…')).not.toBeInTheDocument();
			expect(container.querySelector('section')).toHaveAttribute('aria-busy', 'false');
		});

		it('em erro mostra a message e "Tentar novamente" refaz a consulta, com busca e filtros', async () => {
			getEnvelope.mockResolvedValueOnce(envelope([card('OP01-001', 'Zoro')], { colors: ['Red'] }));
			await goTo('/app?colors%5B%5D=Red');
			render(Page);
			await findTile('Zoro');

			getEnvelope.mockRejectedValueOnce(networkError());
			await goTo('/app?colors%5B%5D=Red&page=2');

			expect(await screen.findByText(networkError().message, { selector: 'section *' })).toBeInTheDocument();
			expect(queryTile('Zoro')).not.toBeInTheDocument();
			expect(screen.getByLabelText('Buscar por nome ou card_number')).toBeInTheDocument();
			expect(screen.getByRole('list', { name: 'Filtros ativos' })).toBeInTheDocument();

			getEnvelope.mockResolvedValueOnce(envelope([card('OP01-009', 'Nami')], { colors: ['Red'] }));
			await fireEvent.click(screen.getByRole('button', { name: 'Tentar novamente' }));

			expect(await findTile('Nami')).toBeInTheDocument();
			expect(getEnvelope).toHaveBeenLastCalledWith('/api/catalog?colors%5B%5D=Red&page=2');
			expect(screen.queryByRole('button', { name: 'Tentar novamente' })).not.toBeInTheDocument();
		});

		it('em erro oculta a linha de status e o convite; "Tentar novamente" faz uma só chamada com a mesma query', async () => {
			getEnvelope.mockResolvedValueOnce(envelope([card('OP01-001', 'Zoro')], { colors: ['Red'] }));
			await goTo('/app?colors%5B%5D=Red');
			render(Page);
			await findTile('Zoro');
			expect(screen.getByText('1 carta · 1 filtro ativo')).toBeInTheDocument();
			expect(screen.getByRole('link', { name: 'Entrar para registrar posse' })).toBeInTheDocument();

			getEnvelope.mockRejectedValueOnce(networkError());
			await goTo('/app?colors%5B%5D=Red&page=2');
			await screen.findByRole('button', { name: 'Tentar novamente' });

			expect(screen.queryByText('1 carta · 1 filtro ativo')).not.toBeInTheDocument();
			expect(screen.queryByRole('link', { name: 'Entrar para registrar posse' })).not.toBeInTheDocument();

			const before = getEnvelope.mock.calls.length;
			getEnvelope.mockResolvedValueOnce(envelope([card('OP01-009', 'Nami')], { colors: ['Red'] }));
			await fireEvent.click(screen.getByRole('button', { name: 'Tentar novamente' }));
			await findTile('Nami');

			expect(getEnvelope.mock.calls.length).toBe(before + 1);
			expect(getEnvelope).toHaveBeenLastCalledWith('/api/catalog?colors%5B%5D=Red&page=2');
		});

		it('mostra a message de um erro da API como veio', async () => {
			getEnvelope.mockRejectedValue(new ApiError(500, 'internal_error', 'Algo deu errado.'));
			render(Page);

			expect(await screen.findByText('Algo deu errado.', { selector: 'section *' })).toBeInTheDocument();
			expect(screen.getByRole('button', { name: 'Tentar novamente' })).toBeInTheDocument();
		});
	});

	describe('convite para entrar', () => {
		it('sem sessão leva a /app/entrar com o caminho e a query atuais', async () => {
			await goTo('/app?colors%5B%5D=Red');
			render(Page);
			await findTile('Zoro');

			const link = screen.getByRole('link', { name: 'Entrar para registrar posse' });
			expect(link).toHaveAttribute(
				'href',
				`/app/entrar?return_to=${encodeURIComponent('/app?colors%5B%5D=Red')}`
			);
		});

		it('acompanha a troca de page.url, inclusive para /app sem query', async () => {
			await goTo('/app?q=zoro');
			render(Page);
			const link = await screen.findByRole('link', { name: 'Entrar para registrar posse' });
			expect(link).toHaveAttribute('href', `/app/entrar?return_to=${encodeURIComponent('/app?q=zoro')}`);

			await goTo('/app?colors%5B%5D=Red');
			await waitFor(() =>
				expect(screen.getByRole('link', { name: 'Entrar para registrar posse' })).toHaveAttribute(
					'href',
					`/app/entrar?return_to=${encodeURIComponent('/app?colors%5B%5D=Red')}`
				)
			);

			await goTo('/app');
			await waitFor(() =>
				expect(screen.getByRole('link', { name: 'Entrar para registrar posse' })).toHaveAttribute(
					'href',
					`/app/entrar?return_to=${encodeURIComponent('/app')}`
				)
			);
		});

		it('com sessão não mostra o convite', async () => {
			session.user = { email: 'ana@example.com' };
			render(Page);
			await findTile('Zoro');

			expect(screen.queryByRole('link', { name: 'Entrar para registrar posse' })).not.toBeInTheDocument();
		});
	});

	describe('anúncio', () => {
		it('anuncia a frase da linha de status a cada resposta', async () => {
			getEnvelope.mockResolvedValue(envelope([card('OP01-001', 'Zoro')], { colors: ['Red'] }, 1));
			render(Page);

			await waitFor(() =>
				expect(screen.getByRole('status')).toHaveTextContent('1 carta · 1 filtro ativo')
			);
		});

		it.each([
			['sem filtro', envelope([card('OP01-001', 'Zoro')]), '1 carta'],
			['sem resultado', envelope([]), '0 cartas'],
			[
				'com filtros no plural',
				envelope([card('OP01-001', 'Zoro')], { colors: ['Red', 'Blue'], sets: ['OP01'] }, 30),
				'30 cartas · 3 filtros ativos'
			]
		])('anuncia a mesma frase da linha de status (%s)', async (_, response, sentence) => {
			getEnvelope.mockResolvedValue(response);
			render(Page);

			await waitFor(() => expect(screen.getByRole('status')).toHaveTextContent(sentence));
			expect(screen.getByText(sentence, { selector: 'p:not([role])' })).toBeInTheDocument();
		});

		it('regrava a região mesmo quando a frase é igual à anterior', async () => {
			render(Page);
			const region = screen.getByRole('status');
			await waitFor(() => expect(region).toHaveTextContent('1 carta'));

			const seen: string[] = [];
			const observer = new MutationObserver(() => seen.push(region.textContent ?? ''));
			observer.observe(region, { childList: true, characterData: true, subtree: true });
			await goTo('/app?page=2');
			await waitFor(() => expect(seen).toContain('1 carta'));
			observer.disconnect();

			expect(seen).toContain('');
			expect(seen.lastIndexOf('1 carta')).toBeGreaterThan(seen.indexOf(''));
			expect(region).toHaveTextContent('1 carta');
		});

		it('em erro anuncia a message', async () => {
			getEnvelope.mockRejectedValue(networkError());
			render(Page);

			await waitFor(() => expect(screen.getByRole('status')).toHaveTextContent(networkError().message));
		});
	});
});
