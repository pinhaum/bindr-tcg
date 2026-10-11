import '@testing-library/jest-dom/vitest';
import { cleanup, fireEvent, render, screen, waitFor, within } from '@testing-library/svelte';
import { createRawSnippet, tick } from 'svelte';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { ApiError, networkError } from '../../../lib/api/errors';
import type { CardDetailPayload, DetailVariant } from '../../../lib/api/types';

const wideQuery = vi.hoisted(() => {
	const listeners = new Set<(event: Event) => void>();
	const query = {
		matches: false,
		addEventListener: (_: string, listener: (event: Event) => void) => listeners.add(listener),
		removeEventListener: (_: string, listener: (event: Event) => void) => listeners.delete(listener),
		cross(matches: boolean) {
			query.matches = matches;
			for (const listener of [...listeners]) listener(new Event('change'));
		}
	};
	vi.stubGlobal('matchMedia', () => query);
	return query;
});

const nav = vi.hoisted(() => ({ goto: vi.fn() }));
vi.mock('$app/navigation', () => nav);

vi.mock('$app/state', async () => {
	const { SvelteMap, SvelteURL } = await import('svelte/reactivity');
	const params = new SvelteMap<string, string>();
	const version = new SvelteMap<string, number>();
	return {
		page: {
			url: new SvelteURL('http://localhost/app/cartas/OP01-001'),
			params: new Proxy(
				{},
				{
					get: (_, key) => {
						version.get('v');
						return params.get(String(key));
					}
				}
			),
			setParam: (value: string) => params.set('card_number', value),
			touchParams: () => version.set('v', (version.get('v') ?? 0) + 1)
		},
		navigating: { to: null }
	};
});

vi.mock('$app/paths', () => ({ resolve: (path: string) => `/app${path === '/' ? '/' : path}` }));

const client = vi.hoisted(() => ({ get: vi.fn(), post: vi.fn(), put: vi.fn() }));
vi.mock('../../../lib/api/index', () => ({ api: client }));
vi.mock('../../../lib/api', () => ({ api: client }));

import { page } from '$app/state';
import AppShell from '../../../lib/components/AppShell.svelte';
import { armArrival, awaitArrival, isMarked, markCard, signalArrival } from '../../../lib/cards/morph.svelte';
import { session } from '../../../lib/session.svelte';
import { shell } from '../../../lib/shell.svelte';
import { toasts } from '../../../lib/toasts.svelte';
import Page from './+page.svelte';

const mockPage = page as unknown as {
	url: { href: string };
	setParam: (value: string) => void;
	touchParams: () => void;
};

const variant = (code: string, overrides: Partial<DetailVariant> = {}): DetailVariant => ({
	variant_code: code,
	rarity: 'R',
	art_kind: 'base',
	set: { code: 'OP01', name: 'Romance Dawn' },
	illustrator: null,
	image_url: null,
	in_source: true,
	owned_quantity: null,
	wishlist_target: null,
	price: null,
	...overrides
});

const detail = (
	number: string,
	name: string,
	variants: DetailVariant[] = [variant(`tcgplayer:${number}`)]
): CardDetailPayload => ({
	card_number: number,
	name,
	card_type: 'character',
	colors: ['Red'],
	cost: 1,
	life: null,
	power: 5000,
	counter: null,
	block_icon: null,
	attributes: [],
	traits: [],
	effect_text: 'Efeito de teste.',
	trigger_text: null,
	set: { code: 'OP01', name: 'Romance Dawn' },
	featured_variant_code: variants[0]?.variant_code ?? null,
	variants
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

const goTo = async (number: string, search = '') => {
	mockPage.url.href = `http://localhost/app/cartas/${encodeURIComponent(number)}${search}`;
	mockPage.setParam(number);
	await tick();
};

const notFound = () => new ApiError(404, 'not_found', 'Carta não encontrada.', {});

const h1 = (name: string) => screen.findByRole('heading', { level: 1, name });

const rowOf = (code: string) =>
	screen.getByRole('link', { name: `Mostrar ${code} na imagem principal` }).closest('li')!;
const addCopy = (code: string) =>
	screen.getByRole('button', { name: new RegExp(`^Adicionar uma cópia de .* ${code}$`) });
const pick = (code: string) =>
	fireEvent.click(screen.getByRole('link', { name: `Mostrar ${code} na imagem principal` }));

describe('cartas/[card_number]/+page.svelte', () => {
	beforeEach(() => {
		client.get.mockReset();
		client.post.mockReset();
		client.put.mockReset();
		nav.goto.mockReset();
		toasts.splice(0);
		session.user = null;
		wideQuery.matches = false;
		mockPage.url.href = 'http://localhost/app/cartas/OP01-001';
		mockPage.setParam('OP01-001');
		client.get.mockResolvedValue(detail('OP01-001', 'Luffy'));
	});
	afterEach(() => {
		cleanup();
		vi.useRealTimers();
		shell.aside = null;
	});

	it('SCAR-1: título de página e cabeçalho de nível 1 com o nome', async () => {
		render(Page);

		expect(await h1('Luffy')).toBeInTheDocument();
		expect(document.title).toBe('Luffy (OP01-001) — Bindr');
	});

	it.each([
		['sem variant', '', '/api/cards/OP01-001'],
		['com variant', '?variant=tcgplayer:2', '/api/cards/OP01-001?variant=tcgplayer%3A2'],
		['com variant vazio', '?variant=', '/api/cards/OP01-001?variant=']
	])('SCAR-2: consulta a API com o card_number e repassa o variant (%s)', async (_, search, path) => {
		await goTo('OP01-001', search);
		render(Page);

		await h1('Luffy');
		expect(client.get).toHaveBeenCalledTimes(1);
		expect(client.get).toHaveBeenCalledWith(path);
	});

	it('SCAR-2: codifica o card_number com caracteres reservados', async () => {
		await goTo('P 029/x');
		render(Page);

		await waitFor(() => expect(client.get).toHaveBeenCalledWith('/api/cards/P%20029%2Fx'));
	});

	it('SCAR-5: 404 mostra a message da API, "Voltar ao catálogo" e o título próprio', async () => {
		client.get.mockRejectedValue(notFound());
		render(Page);

		expect(await screen.findByText('Carta não encontrada.')).toBeInTheDocument();
		expect(screen.getByRole('link', { name: 'Voltar ao catálogo' })).toHaveAttribute('href', '/app');
		expect(document.title).toBe('Carta não encontrada — Bindr');
		expect(screen.queryByRole('button', { name: 'Tentar novamente' })).not.toBeInTheDocument();
	});

	it('SCAR-6: outro erro mostra a message e "Tentar novamente" repete a consulta', async () => {
		client.get.mockRejectedValueOnce(networkError());
		render(Page);

		const retry = await screen.findByRole('button', { name: 'Tentar novamente' });
		expect(screen.queryByRole('heading', { level: 1, name: 'Luffy' })).not.toBeInTheDocument();
		await fireEvent.click(retry);

		expect(await h1('Luffy')).toBeInTheDocument();
		expect(client.get).toHaveBeenCalledTimes(2);
		expect(client.get).toHaveBeenLastCalledWith('/api/cards/OP01-001');
	});

	it('SCAR-7: mantém o conteúdo antes de 200 ms e depois marca aria-busy e anuncia', async () => {
		render(Page);
		await h1('Luffy');
		vi.useFakeTimers();
		const pending = deferred<CardDetailPayload>();
		client.get.mockReturnValue(pending.promise);

		await goTo('OP01-025');
		const region = document.querySelector('[aria-busy]')!;
		await vi.advanceTimersByTimeAsync(199);
		expect(region).toHaveAttribute('aria-busy', 'false');
		expect(screen.getByRole('heading', { level: 1, name: 'Luffy' })).toBeInTheDocument();
		expect(screen.queryByText('Carregando carta…')).not.toBeInTheDocument();

		await vi.advanceTimersByTimeAsync(1);
		expect(region).toHaveAttribute('aria-busy', 'true');
		expect(screen.getByText('Carregando carta…')).toBeInTheDocument();

		pending.resolve(detail('OP01-025', 'Zoro'));
		await vi.advanceTimersByTimeAsync(0);
		expect(screen.getByRole('heading', { level: 1, name: 'Zoro' })).toBeInTheDocument();
		expect(region).toHaveAttribute('aria-busy', 'false');
		expect(screen.queryByText('Carregando carta…')).not.toBeInTheDocument();
	});

	it('SCAR-5: 404 da carta B mostra a message da API e esconde a carta A já carregada', async () => {
		render(Page);
		await h1('Luffy');
		client.get.mockRejectedValueOnce(notFound());

		await goTo('OP01-025');

		expect(await h1('Carta não encontrada.')).toBeInTheDocument();
		expect(screen.queryByRole('heading', { level: 1, name: 'Luffy' })).not.toBeInTheDocument();
		expect(document.title).toBe('Carta não encontrada — Bindr');
	});

	it('SCAR-6: erro da carta B mostra a message e esconde a carta A já carregada', async () => {
		render(Page);
		await h1('Luffy');
		client.get.mockRejectedValueOnce(networkError());

		await goTo('OP01-025');

		expect(await screen.findByRole('button', { name: 'Tentar novamente' })).toBeInTheDocument();
		expect(screen.queryByRole('heading', { level: 1, name: 'Luffy' })).not.toBeInTheDocument();
	});

	it('SCAR-7: depois de 200 ms, "Tentar novamente" troca o erro pelo skeleton até a resposta', async () => {
		client.get.mockRejectedValueOnce(networkError());
		render(Page);
		const retry = await screen.findByRole('button', { name: 'Tentar novamente' });
		vi.useFakeTimers();
		const pending = deferred<CardDetailPayload>();
		client.get.mockReturnValue(pending.promise);

		await fireEvent.click(retry);
		await vi.advanceTimersByTimeAsync(199);
		expect(screen.getByRole('button', { name: 'Tentar novamente' })).toBeInTheDocument();
		expect(screen.queryByText('Carregando carta…')).not.toBeInTheDocument();

		await vi.advanceTimersByTimeAsync(1);
		expect(document.querySelector('[aria-busy]')).toHaveAttribute('aria-busy', 'true');
		expect(screen.getByText('Carregando carta…')).toBeInTheDocument();
		expect(screen.queryByRole('button', { name: 'Tentar novamente' })).not.toBeInTheDocument();

		pending.resolve(detail('OP01-001', 'Luffy'));
		await vi.advanceTimersByTimeAsync(0);
		expect(screen.getByRole('heading', { level: 1, name: 'Luffy' })).toBeInTheDocument();
	});

	it('SCAR-7: depois de 200 ms, trocar de carta vindo de 404 mostra o skeleton no lugar da mensagem', async () => {
		client.get.mockRejectedValueOnce(notFound());
		render(Page);
		await screen.findByText('Carta não encontrada.');
		vi.useFakeTimers();
		const pending = deferred<CardDetailPayload>();
		client.get.mockReturnValue(pending.promise);

		await goTo('OP01-025');
		await vi.advanceTimersByTimeAsync(200);

		expect(screen.getByText('Carregando carta…')).toBeInTheDocument();
		expect(screen.queryByText('Carta não encontrada.')).not.toBeInTheDocument();
	});

	it('SCAR-8: troca de card_number refaz a consulta e descarta resposta da carta antiga', async () => {
		const first = deferred<CardDetailPayload>();
		client.get.mockReturnValueOnce(first.promise);
		render(Page);
		client.get.mockResolvedValueOnce(detail('OP01-025', 'Zoro'));

		await goTo('OP01-025');
		await h1('Zoro');
		first.resolve(detail('OP01-001', 'Luffy'));
		await tick();
		await tick();

		expect(client.get).toHaveBeenLastCalledWith('/api/cards/OP01-025');
		expect(screen.getByRole('heading', { level: 1, name: 'Zoro' })).toBeInTheDocument();
		expect(document.title).toBe('Zoro (OP01-025) — Bindr');
	});

	it('SCAR-8: troca de carta descarta as filas de posse da carta antiga', async () => {
		session.user = { email: 'ana@example.com' };
		const pending = deferred<{ variant_code: string; owned_quantity: number }>();
		client.get.mockResolvedValueOnce(
			detail('OP01-001', 'Luffy', [variant('tcgplayer:1', { owned_quantity: 1 })])
		);
		client.post.mockReturnValue(pending.promise);
		render(Page);
		await h1('Luffy');
		await fireEvent.click(addCopy('tcgplayer:1'));
		client.get.mockResolvedValueOnce(
			detail('OP01-025', 'Zoro', [variant('tcgplayer:25', { owned_quantity: 0 })])
		);

		await goTo('OP01-025');
		await h1('Zoro');
		pending.resolve({ variant_code: 'tcgplayer:1', owned_quantity: 9 });
		await tick();

		expect(within(rowOf('tcgplayer:25')).getByText('não tenho')).toBeInTheDocument();
		expect(screen.queryByText('9 cópias')).not.toBeInTheDocument();
	});

	describe('SCAR-39: chegada para a View Transition', () => {
		const arrival = () => {
			armArrival();
			const state = { done: false };
			void awaitArrival(60_000).then(() => (state.done = true));
			return state;
		};
		afterEach(() => signalArrival());

		it('sinaliza a chegada depois de o cabeçalho da carta estar no DOM', async () => {
			const pending = deferred<CardDetailPayload>();
			client.get.mockReturnValue(pending.promise);
			const state = arrival();
			render(Page);
			await tick();
			expect(state.done).toBe(false);

			pending.resolve(detail('OP01-001', 'Luffy'));
			await h1('Luffy');

			await waitFor(() => expect(state.done).toBe(true));
		});

		it('não sinaliza enquanto a resposta falha ou a carta não existe', async () => {
			client.get.mockRejectedValue(notFound());
			const state = arrival();
			render(Page);
			await screen.findByText('Carta não encontrada.');
			await new Promise((resolve) => setTimeout(resolve, 20));

			expect(state.done).toBe(false);
		});
	});

	it('SCAR-40: com a carta carregada, marca o card_number para o morph de volta', async () => {
		markCard(null);
		render(Page);
		await h1('Luffy');

		expect(isMarked('OP01-001')).toBe(true);
	});

	it('SCAR-40: trocar de carta marca a nova e desmarca a antiga', async () => {
		render(Page);
		await h1('Luffy');
		client.get.mockResolvedValueOnce(detail('OP01-025', 'Zoro'));

		await goTo('OP01-025');
		await h1('Zoro');

		expect(isMarked('OP01-025')).toBe(true);
		expect(isMarked('OP01-001')).toBe(false);
	});

	it('SCAR-40: desmontar a página não limpa a marca', async () => {
		const { unmount } = render(Page);
		await h1('Luffy');

		unmount();

		expect(isMarked('OP01-001')).toBe(true);
	});

	it('SCAR-9: troca de sessão refaz a consulta da carta atual', async () => {
		render(Page);
		await h1('Luffy');
		expect(client.get).toHaveBeenCalledTimes(1);

		session.user = { email: 'ana@example.com' };
		await waitFor(() => expect(client.get).toHaveBeenCalledTimes(2));
		session.user = null;
		await waitFor(() => expect(client.get).toHaveBeenCalledTimes(3));

		expect(client.get).toHaveBeenLastCalledWith('/api/cards/OP01-001');
	});

	it('trocar só o variant na URL não refaz a consulta', async () => {
		render(Page);
		await h1('Luffy');

		mockPage.url.href = 'http://localhost/app/cartas/OP01-001?variant=tcgplayer:2';
		await tick();

		expect(client.get).toHaveBeenCalledTimes(1);
	});

	describe('SCAR-4: Voltar ao catálogo', () => {
		it('abaixo de 64rem fica no topo da página, sem seta, e vai para /app', async () => {
			const { container } = render(Page);
			await h1('Luffy');

			const back = within(container).getByRole('link', { name: 'Voltar ao catálogo' });
			expect(back).toHaveAttribute('href', '/app');
			expect(back).toHaveTextContent(/^Voltar ao catálogo$/);
			expect(shell.aside).toBeNull();
		});

		it('a partir de 64rem sai da página e vai para shell.aside', async () => {
			wideQuery.matches = true;
			const { container } = render(Page);
			await h1('Luffy');

			expect(within(container).queryByRole('link', { name: 'Voltar ao catálogo' })).toBeNull();
			expect(shell.aside).not.toBeNull();
			const children = createRawSnippet(() => ({ render: () => '<span></span>' }));
			const frame = render(AppShell, { children });
			const asideBack = within(frame.container.querySelector('.aside') as HTMLElement).getByRole(
				'link',
				{ name: 'Voltar ao catálogo' }
			);
			expect(asideBack).toHaveAttribute('href', '/app');
		});

		it('cruzar 64rem troca o lugar do botão sem refazer a consulta', async () => {
			const { container } = render(Page);
			await h1('Luffy');

			wideQuery.cross(true);
			await tick();
			expect(shell.aside).not.toBeNull();
			expect(within(container).queryByRole('link', { name: 'Voltar ao catálogo' })).toBeNull();

			wideQuery.cross(false);
			await tick();
			expect(shell.aside).toBeNull();
			expect(within(container).getByRole('link', { name: 'Voltar ao catálogo' })).toBeInTheDocument();
			expect(client.get).toHaveBeenCalledTimes(1);
		});

		it('também aparece no estado de erro', async () => {
			client.get.mockRejectedValueOnce(networkError());
			render(Page);

			await screen.findByRole('button', { name: 'Tentar novamente' });
			expect(screen.getByRole('link', { name: 'Voltar ao catálogo' })).toBeInTheDocument();
		});
	});

	describe('variante em destaque', () => {
		const variants = [
			variant('tcgplayer:1', { rarity: 'R', owned_quantity: 2, illustrator: 'Autor Um' }),
			variant('tcgplayer:2', {
				rarity: 'SEC',
				art_kind: 'parallel',
				owned_quantity: 0,
				illustrator: 'Autor Dois',
				set: { code: 'OP02', name: 'Paramount War' }
			})
		];

		beforeEach(() => {
			session.user = { email: 'ana@example.com' };
			client.get.mockResolvedValue(detail('OP01-001', 'Luffy', variants));
		});

		const chips = () => within(document.querySelector('.chips') as HTMLElement);

		it('SCAR-23: clicar na miniatura muda destaque, selo, ilustração, raridade e set sem nova consulta', async () => {
			render(Page);
			await h1('Luffy');
			expect(screen.getByRole('img', { name: '2 cópias' })).toBeInTheDocument();
			expect(chips().getByText('R')).toBeInTheDocument();
			expect(screen.getByText('Ilustração: Autor Um')).toBeInTheDocument();

			await pick('tcgplayer:2');

			expect(screen.queryByRole('img', { name: /cópia/ })).not.toBeInTheDocument();
			expect(chips().getByText('SEC')).toBeInTheDocument();
			expect(chips().queryByText('R')).not.toBeInTheDocument();
			expect(screen.getByText('Ilustração: Autor Dois')).toBeInTheDocument();
			expect(screen.getByText('Paramount War · OP02')).toBeInTheDocument();
			expect(nav.goto).toHaveBeenCalledTimes(1);
			expect(nav.goto).toHaveBeenCalledWith('/app/cartas/OP01-001?variant=tcgplayer%3A2', {
				replace: true,
				reset: false
			});
			expect(client.get).toHaveBeenCalledTimes(1);
		});

		it('SCAR-23: voltar para a primeira variante restaura o selo', async () => {
			render(Page);
			await h1('Luffy');

			await pick('tcgplayer:2');
			await pick('tcgplayer:1');

			expect(screen.getByRole('img', { name: '2 cópias' })).toBeInTheDocument();
			expect(nav.goto).toHaveBeenLastCalledWith('/app/cartas/OP01-001?variant=tcgplayer%3A1', {
				replace: true,
				reset: false
			});
		});

		it('SCAR-23: o goto da troca renova page.params e mesmo assim não refaz a consulta', async () => {
			nav.goto.mockImplementation(async (url: string) => {
				mockPage.url.href = `http://localhost${url}`;
				mockPage.touchParams();
			});
			render(Page);
			await h1('Luffy');

			await pick('tcgplayer:2');
			await tick();

			expect(client.get).toHaveBeenCalledTimes(1);
		});

		it('SCAR-23: a variante escolhida sobrevive à troca de sessão e vai na nova consulta', async () => {
			nav.goto.mockImplementation(async (url: string) => {
				mockPage.url.href = `http://localhost${url}`;
			});
			render(Page);
			await h1('Luffy');
			await pick('tcgplayer:2');

			client.get.mockResolvedValue(detail('OP01-001', 'Luffy', variants));
			session.user = { email: 'bia@example.com' };
			await waitFor(() => expect(client.get).toHaveBeenCalledTimes(2));
			await h1('Luffy');

			expect(client.get).toHaveBeenLastCalledWith('/api/cards/OP01-001?variant=tcgplayer%3A2');
			expect(screen.getByRole('link', { name: 'Mostrar tcgplayer:2 na imagem principal' })).toHaveAttribute(
				'aria-current',
				'true'
			);
		});

		it('SCAR-23: Tentar novamente pede a variante escolhida', async () => {
			nav.goto.mockImplementation(async (url: string) => {
				mockPage.url.href = `http://localhost${url}`;
			});
			render(Page);
			await h1('Luffy');
			await pick('tcgplayer:2');

			client.get.mockRejectedValueOnce(networkError());
			session.user = { email: 'bia@example.com' };
			await screen.findByRole('alert');
			await fireEvent.click(screen.getByRole('button', { name: 'Tentar novamente' }));
			await h1('Luffy');

			expect(client.get).toHaveBeenLastCalledWith('/api/cards/OP01-001?variant=tcgplayer%3A2');
			expect(screen.getByRole('link', { name: 'Mostrar tcgplayer:2 na imagem principal' })).toHaveAttribute(
				'aria-current',
				'true'
			);
		});

		it('SCAR-8: troca de sessão não mostra nem aceita posse do usuário anterior até a resposta nova', async () => {
			render(Page);
			await h1('Luffy');
			expect(screen.getByRole('img', { name: '2 cópias' })).toBeInTheDocument();
			const removeName = 'Remover uma cópia de Luffy tcgplayer:1';
			const addName = 'Adicionar uma cópia de Luffy tcgplayer:1';
			expect(screen.getByRole('button', { name: removeName })).toBeInTheDocument();

			const pending = deferred<CardDetailPayload>();
			client.get.mockReturnValue(pending.promise);
			session.user = { email: 'bia@example.com' };
			await tick();

			expect(screen.queryByRole('img', { name: /cópia/ })).not.toBeInTheDocument();
			expect(screen.queryByRole('button', { name: addName })).not.toBeInTheDocument();
			expect(screen.queryByRole('button', { name: removeName })).not.toBeInTheDocument();

			pending.resolve(detail('OP01-001', 'Luffy', [variant('tcgplayer:1', { owned_quantity: 0 }), variants[1]]));
			await h1('Luffy');
			expect(screen.queryByRole('img', { name: /cópia/ })).not.toBeInTheDocument();
			expect(addCopy('tcgplayer:1')).toBeInTheDocument();
		});

		it('SCAR-24: variant da URL que existe vira o destaque', async () => {
			await goTo('OP01-001', '?variant=tcgplayer:2');
			render(Page);

			await h1('Luffy');
			expect(chips().getByText('SEC')).toBeInTheDocument();
			expect(screen.getByRole('link', { name: 'Mostrar tcgplayer:2 na imagem principal' })).toHaveAttribute(
				'aria-current',
				'true'
			);
		});

		it.each([
			['ausente', ''],
			['desconhecido', '?variant=tcgplayer:999']
		])('SCAR-24: variant %s usa a primeira in_source, sem erro', async (_, search) => {
			client.get.mockResolvedValue(
				detail('OP01-001', 'Luffy', [
					variant('tcgplayer:1', { in_source: false, rarity: 'L' }),
					variants[1],
					variant('tcgplayer:3')
				])
			);
			await goTo('OP01-001', search);
			render(Page);

			await h1('Luffy');
			expect(chips().getByText('SEC')).toBeInTheDocument();
			expect(screen.queryByRole('alert')).not.toBeInTheDocument();
		});

		it('SCAR-24: sem nenhuma in_source usa a primeira listada', async () => {
			client.get.mockResolvedValue(
				detail('OP01-001', 'Luffy', [
					variant('tcgplayer:1', { in_source: false, rarity: 'L' }),
					variant('tcgplayer:2', { in_source: false, rarity: 'SEC' })
				])
			);
			render(Page);

			await h1('Luffy');
			expect(chips().getByText('L')).toBeInTheDocument();
			expect(screen.getAllByText('Variante fora da fonte').length).toBeGreaterThan(0);
		});

		it('SCAR-15: o selo segue o valor exibido da fila da variante em destaque', async () => {
			const pending = deferred<{ variant_code: string; owned_quantity: number }>();
			client.post.mockReturnValue(pending.promise);
			render(Page);
			await h1('Luffy');

			await fireEvent.click(addCopy('tcgplayer:1'));
			expect(screen.getByRole('img', { name: '3 cópias' })).toBeInTheDocument();

			pending.resolve({ variant_code: 'tcgplayer:1', owned_quantity: 4 });
			expect(await screen.findByRole('img', { name: '4 cópias' })).toBeInTheDocument();
		});

		it('SCAR-15: variante em destaque que passa de 0 para 1 ganha o selo "1 cópia"', async () => {
			client.post.mockReturnValue(new Promise(() => {}));
			render(Page);
			await h1('Luffy');
			await pick('tcgplayer:2');
			expect(screen.queryByRole('img', { name: /cópia/ })).not.toBeInTheDocument();

			await fireEvent.click(addCopy('tcgplayer:2'));

			expect(screen.getByRole('img', { name: '1 cópia' })).toBeInTheDocument();
		});

		it('trocar de variante não interrompe a fila de outra', async () => {
			const pending = deferred<{ variant_code: string; owned_quantity: number }>();
			client.post.mockReturnValue(pending.promise);
			render(Page);
			await h1('Luffy');
			await fireEvent.click(addCopy('tcgplayer:1'));

			await pick('tcgplayer:2');
			pending.resolve({ variant_code: 'tcgplayer:1', owned_quantity: 7 });

			expect(await within(rowOf('tcgplayer:1')).findByText('7 cópias')).toBeInTheDocument();
			expect(within(rowOf('tcgplayer:2')).getByText('não tenho')).toBeInTheDocument();
			expect(client.post).toHaveBeenCalledTimes(1);
		});

		it('sair com operações pendentes descarta as filas, mostra o convite e oculta o selo', async () => {
			const pending = deferred<{ variant_code: string; owned_quantity: number }>();
			client.post.mockReturnValue(pending.promise);
			render(Page);
			await h1('Luffy');
			await fireEvent.click(addCopy('tcgplayer:1'));
			expect(screen.getByRole('img', { name: '3 cópias' })).toBeInTheDocument();

			session.user = null;
			await tick();

			expect(screen.queryByRole('img', { name: /cópia/ })).not.toBeInTheDocument();
			expect(screen.queryByRole('button', { name: /Adicionar uma cópia/ })).not.toBeInTheDocument();
			expect(screen.getAllByRole('link', { name: 'Entrar para registrar posse' })).toHaveLength(2);

			pending.resolve({ variant_code: 'tcgplayer:1', owned_quantity: 9 });
			await waitFor(() => expect(client.get).toHaveBeenCalledTimes(2));
			await tick();
			expect(screen.queryByRole('img', { name: /cópia/ })).not.toBeInTheDocument();
			expect(screen.queryByText('9 cópias')).not.toBeInTheDocument();
		});

		it('SCAR-9: troca direta de A para B descarta a fila de A e exibe o owned_quantity de B', async () => {
			session.user = { email: 'ana@example.com' };
			const pending = deferred<{ variant_code: string; owned_quantity: number }>();
			client.post.mockReturnValue(pending.promise);
			render(Page);
			await h1('Luffy');
			await fireEvent.click(addCopy('tcgplayer:1'));

			session.user = { email: 'bia@example.com' };
			await waitFor(() => expect(client.get).toHaveBeenCalledTimes(2));
			await tick();
			pending.resolve({ variant_code: 'tcgplayer:1', owned_quantity: 9 });
			await tick();
			await tick();

			expect(within(rowOf('tcgplayer:1')).getByText('2 cópias')).toBeInTheDocument();
			expect(screen.queryByText('9 cópias')).not.toBeInTheDocument();
		});

		it('cruzar 64rem com "+" pendente mantém a fila, aplica a resposta e mantém uma só imagem', async () => {
			const withImage = variants.map((v) => ({ ...v, image_url: `/card_images/${v.variant_code}` }));
			client.get.mockResolvedValue(detail('OP01-001', 'Luffy', withImage));
			const pending = deferred<{ variant_code: string; owned_quantity: number }>();
			client.post.mockReturnValue(pending.promise);
			const { container } = render(Page);
			await h1('Luffy');
			const artIn = (selector: string) =>
				container.querySelectorAll(`${selector} img[alt="Luffy tcgplayer:1"]`).length;
			const total = () => container.querySelectorAll('img[alt="Luffy tcgplayer:1"]').length;
			const expectNarrowArt = () => {
				expect([artIn('.thumb'), artIn('.expand'), artIn('.media'), total()]).toEqual([1, 1, 0, 2]);
			};
			const expectWideArt = () => {
				expect([artIn('.thumb'), artIn('.expand'), artIn('.media'), total()]).toEqual([0, 0, 1, 1]);
			};
			expectNarrowArt();
			await fireEvent.click(addCopy('tcgplayer:1'));
			expect(within(rowOf('tcgplayer:1')).getByText('3 cópias')).toBeInTheDocument();

			wideQuery.cross(true);
			await tick();
			expect(within(rowOf('tcgplayer:1')).getByText('3 cópias')).toBeInTheDocument();
			expectWideArt();

			pending.resolve({ variant_code: 'tcgplayer:1', owned_quantity: 4 });
			expect(await within(rowOf('tcgplayer:1')).findByText('4 cópias')).toBeInTheDocument();

			wideQuery.cross(false);
			await tick();
			expect(within(rowOf('tcgplayer:1')).getByText('4 cópias')).toBeInTheDocument();
			expectNarrowArt();
			expect(client.get).toHaveBeenCalledTimes(1);
			expect(client.post).toHaveBeenCalledTimes(1);
		});

		it('sem sessão não há selo nem steppers, mesmo com owned_quantity na resposta', async () => {
			session.user = null;
			render(Page);
			await h1('Luffy');

			expect(screen.queryByRole('img', { name: /cópia/ })).not.toBeInTheDocument();
			expect(screen.getAllByRole('link', { name: 'Entrar para registrar posse' })).toHaveLength(2);
		});
	});

	it('carta sem variantes: cabeçalho, campos e efeito, sem imagem nem "Variantes na pasta"', async () => {
		client.get.mockResolvedValue(detail('OP01-001', 'Luffy', []));
		const { container } = render(Page);

		expect(await h1('Luffy')).toBeInTheDocument();
		expect(screen.getAllByText('OP01-001').length).toBeGreaterThan(0);
		expect(screen.getByText('Efeito de teste.')).toBeInTheDocument();
		expect(screen.queryByRole('heading', { name: 'Variantes na pasta' })).not.toBeInTheDocument();
		expect(container.querySelector('img')).toBeNull();
	});

	it('com variantes lista a seção "Variantes na pasta" na ordem devolvida', async () => {
		client.get.mockResolvedValue(
			detail('OP01-001', 'Luffy', [variant('tcgplayer:2'), variant('tcgplayer:1')])
		);
		render(Page);

		const heading = await screen.findByRole('heading', { level: 2, name: 'Variantes na pasta' });
		const labels = within(heading.closest('section')!)
			.getAllByRole('link', { name: /^Mostrar / })
			.map((link) => link.getAttribute('aria-label'));
		expect(labels).toEqual([
			'Mostrar tcgplayer:2 na imagem principal',
			'Mostrar tcgplayer:1 na imagem principal'
		]);
	});
});
