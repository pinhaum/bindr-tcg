import '@testing-library/jest-dom/vitest';
import { cleanup, fireEvent, render, screen } from '@testing-library/svelte';
import { tick } from 'svelte';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { ApiError } from '../../../lib/api/errors';
import type { DeckPayload } from '../../../lib/api/types';

vi.mock('$app/paths', () => ({ resolve: (path: string) => `/app${path === '/' ? '/' : path}` }));

const apiMock = vi.hoisted(() => ({ get: vi.fn(), post: vi.fn() }));
const pageState = vi.hoisted(() => ({ params: { id: '7' } }));
vi.mock('$app/state', async () => {
	const { SvelteMap } = await import('svelte/reactivity');
	const store = new SvelteMap<string, { id: string }>();
	Object.defineProperty(pageState, 'params', {
		get: () => store.get('params') ?? { id: '7' },
		set: (value: { id: string }) => store.set('params', value)
	});
	return { page: pageState };
});
vi.mock('../../../lib/api/index', () => ({ api: apiMock }));

type SessionUser = { email: string } | null;
const sessionState = vi.hoisted(() => ({ user: null as SessionUser }));
vi.mock('../../../lib/session.svelte', async () => {
	const { SvelteMap } = await import('svelte/reactivity');
	const store = new SvelteMap<string, SessionUser>();
	return {
		session: {
			get user() {
				return store.get('user') ?? null;
			},
			set user(value: SessionUser) {
				store.set('user', value);
			}
		}
	};
});

import { session } from '../../../lib/session.svelte';
Object.defineProperty(sessionState, 'user', {
	get: () => (session as unknown as { user: SessionUser }).user,
	set: (value: SessionUser) => {
		(session as unknown as { user: SessionUser }).user = value;
	}
});

import { load } from './+page';
import Page from './+page.svelte';

const line = (over: Partial<DeckPayload['entries'][number]> = {}) => ({
	card_number: 'OP01-004',
	name: 'Usopp',
	card_type: 'character',
	cost: 2,
	in_source: true,
	required: 4,
	owned: 3,
	missing: 1,
	quantity: 4,
	...over
});

const deck = (over: Partial<DeckPayload> = {}): DeckPayload => ({
	id: 7,
	name: 'Red Zoro',
	editing: false,
	status: 'incomplete',
	reasons: ['O deck principal tem 5 cartas; precisa de 50'],
	warnings: [],
	main_total: 5,
	missing_total: 2,
	leader: { card_number: 'OP01-001', name: 'Roronoa Zoro', card_type: 'leader', cost: null, in_source: true, required: 1, owned: 0, missing: 1 },
	entries: [
		line(),
		line({ card_number: 'OP01-020', name: 'Gum-Gum', card_type: 'event', cost: null, in_source: false, quantity: 1, required: 1, owned: 1, missing: 0 })
	],
	...over
});

const deferred = <T,>() => {
	let resolve!: (value: T) => void;
	const promise = new Promise<T>((res) => (resolve = res));
	return { promise, resolve };
};

describe('baralhos/[id]/+page.ts', () => {
	it('sem sessão redireciona para entrar', async () => {
		sessionState.user = null;
		const url = new URL('http://localhost/app/baralhos/7');
		await expect(load({ parent: async () => ({}), url } as never)).rejects.toMatchObject({
			status: 307,
			location: '/app/entrar?return_to=%2Fapp%2Fbaralhos%2F7'
		});
	});
});

describe('baralhos/[id]/+page.svelte', () => {
	beforeEach(() => {
		apiMock.get.mockReset();
		apiMock.post.mockReset();
		apiMock.get.mockResolvedValue(deck());
		pageState.params = { id: '7' };
		sessionState.user = { email: 'ana@example.com' };
	});
	afterEach(() => {
		cleanup();
		vi.useRealTimers();
	});

	it('título, h1 e consulta (SDEC-17)', async () => {
		render(Page);
		expect(await screen.findByRole('heading', { level: 1, name: 'Red Zoro' })).toBeInTheDocument();
		expect(document.title).toBe('Red Zoro — Bindr');
		expect(apiMock.get).toHaveBeenCalledWith('/api/decks/7');
	});

	it('404 mostra DeckNotFound (SDEC-18)', async () => {
		apiMock.get.mockRejectedValue(new ApiError(404, 'not_found', 'Deck não encontrado.'));
		render(Page);
		expect(await screen.findByRole('heading', { level: 1, name: 'Deck não encontrado.' })).toBeInTheDocument();
		expect(screen.getByRole('link', { name: 'Voltar aos baralhos' })).toHaveAttribute('href', '/app/baralhos');
		expect(document.title).toBe('Deck não encontrado — Bindr');
	});

	it('outro erro oferece "Tentar novamente" (SDEC-06)', async () => {
		apiMock.get.mockRejectedValueOnce(new ApiError(500, 'internal_error', 'Algo deu errado.'));
		render(Page);
		expect(await screen.findByText('Algo deu errado.')).toBeInTheDocument();
		await fireEvent.click(screen.getByRole('button', { name: 'Tentar novamente' }));
		expect(await screen.findByRole('heading', { level: 1, name: 'Red Zoro' })).toBeInTheDocument();
	});

	it('carga lenta anuncia "Carregando deck…" (SDEC-04)', async () => {
		vi.useFakeTimers();
		const pending = deferred<DeckPayload>();
		apiMock.get.mockReturnValue(pending.promise);
		render(Page);
		await vi.advanceTimersByTimeAsync(199);
		expect(screen.queryByText('Carregando deck…')).not.toBeInTheDocument();
		await vi.advanceTimersByTimeAsync(1);
		expect(screen.getByText('Carregando deck…')).toBeInTheDocument();
		pending.resolve(deck());
		await vi.advanceTimersByTimeAsync(0);
		expect(screen.queryByText('Carregando deck…')).not.toBeInTheDocument();
	});

	it('descarta a resposta de outro id (SDEC-05)', async () => {
		const first = deferred<DeckPayload>();
		const second = deferred<DeckPayload>();
		apiMock.get.mockReturnValueOnce(first.promise).mockReturnValueOnce(second.promise);
		render(Page);
		await tick();
		pageState.params = { id: '8' };
		sessionState.user = { email: 'bia@example.com' };
		await tick();
		second.resolve(deck({ id: 8, name: 'Oito' }));
		await screen.findByRole('heading', { level: 1, name: 'Oito' });
		first.resolve(deck());
		await tick();
		expect(screen.queryByRole('heading', { level: 1, name: 'Red Zoro' })).not.toBeInTheDocument();
	});

	it('editing: true mostra "Em edição" sem botão (SDEC-19)', async () => {
		apiMock.get.mockResolvedValue(deck({ editing: true }));
		render(Page);
		expect(await screen.findByText('Em edição')).toBeInTheDocument();
		expect(screen.queryByRole('button', { name: 'Editar este deck' })).not.toBeInTheDocument();
	});

	it('"Editar este deck" envia select e troca para "Em edição" (SDEC-20)', async () => {
		apiMock.post.mockResolvedValue({ id: 7, name: 'Red Zoro' });
		render(Page);
		await fireEvent.click(await screen.findByRole('button', { name: 'Editar este deck' }));
		expect(await screen.findByText('Em edição')).toBeInTheDocument();
		expect(apiMock.post).toHaveBeenCalledWith('/api/decks/7/select', {});
		expect(screen.getByRole('status')).toHaveTextContent('Agora as cartas vão para o deck “Red Zoro”.');
	});

	it('falha no select mantém o botão e mostra o erro (SDEC-20)', async () => {
		apiMock.post.mockRejectedValue(new ApiError(500, 'internal_error', 'Algo deu errado.'));
		render(Page);
		await fireEvent.click(await screen.findByRole('button', { name: 'Editar este deck' }));
		expect(await screen.findByRole('alert')).toHaveTextContent('Algo deu errado.');
		expect(screen.getByRole('button', { name: 'Editar este deck' })).toBeEnabled();
	});

	it('status com motivos fora de valid e nota de banidas sempre (SDEC-21, SDEC-23)', async () => {
		render(Page);
		expect(await screen.findByRole('heading', { level: 2, name: 'Status: incompleto' })).toBeInTheDocument();
		expect(screen.getByText('O deck principal tem 5 cartas; precisa de 50')).toBeInTheDocument();
		expect(screen.getByText('A lista de banidas não é verificada')).toBeInTheDocument();
	});

	it('deck válido não lista motivos (SDEC-21)', async () => {
		apiMock.get.mockResolvedValue(deck({ status: 'valid', reasons: ['não deve aparecer'] }));
		render(Page);
		await screen.findByRole('heading', { level: 2, name: 'Status: válido' });
		expect(screen.queryByText('não deve aparecer')).not.toBeInTheDocument();
		expect(screen.getByText('A lista de banidas não é verificada')).toBeInTheDocument();
	});

	it('aviso de Leader com cabeçalho e blockquote (SDEC-22)', async () => {
		apiMock.get.mockResolvedValue(deck({ warnings: ['Pode ter qualquer número de cópias.'] }));
		const { container } = render(Page);
		expect(await screen.findByText('Este Leader tem regra de montagem própria, não verificada')).toBeInTheDocument();
		expect(container.querySelector('blockquote')).toHaveTextContent('Pode ter qualquer número de cópias.');
	});

	it.each([
		[{ leader: null, entries: [], missing_total: 0 }, 'Este deck ainda não tem cartas'],
		[{ missing_total: 0 }, 'Você tem todas as cartas deste deck'],
		[{ missing_total: 1 }, 'Falta 1 cópia para montar este deck'],
		[{ missing_total: 5 }, 'Faltam 5 cópias para montar este deck']
	])('"Na sua pasta" %# (SDEC-24)', async (over, sentence) => {
		apiMock.get.mockResolvedValue(deck(over));
		render(Page);
		expect(await screen.findByText(sentence)).toBeInTheDocument();
		expect(screen.getByRole('heading', { level: 2, name: 'Na sua pasta' })).toBeInTheDocument();
	});

	it('Leader com link e sem Leader (SDEC-25)', async () => {
		const { unmount } = render(Page);
		expect(await screen.findByRole('link', { name: 'Roronoa Zoro (OP01-001)' })).toHaveAttribute('href', '/app/cartas/OP01-001');
		unmount();
		apiMock.get.mockResolvedValue(deck({ leader: null }));
		render(Page);
		expect(await screen.findByText('Sem Leader')).toBeInTheDocument();
	});

	it('deck principal em grupos, quantidade, link, custo e contagens (SDEC-26, SDEC-28)', async () => {
		render(Page);
		expect(await screen.findByRole('heading', { level: 2, name: 'Deck principal: 5 / 50' })).toBeInTheDocument();
		expect(screen.getAllByRole('heading', { level: 3 }).map((h) => h.textContent)).toEqual(['Personagens', 'Eventos']);
		const usopp = screen.getByRole('link', { name: 'Usopp (OP01-004)' }).closest('li')!;
		expect(usopp).toHaveTextContent('4×');
		expect(usopp).toHaveTextContent('custo 2');
		expect(usopp).toHaveTextContent('pedida 4, possuída 3, falta 1');
		const event = screen.getByRole('link', { name: 'Gum-Gum (OP01-020)' }).closest('li')!;
		expect(event).not.toHaveTextContent('custo');
		expect(event).toHaveTextContent('pedida 1, possuída 1, falta 0');
	});

	it('marca carta fora da fonte (SDEC-27)', async () => {
		render(Page);
		await screen.findByRole('heading', { level: 1 });
		expect(screen.getAllByText('carta fora da fonte')).toHaveLength(1);
	});

	it('ações (SDEC-29)', async () => {
		render(Page);
		const exportLink = await screen.findByRole('link', { name: 'Exportar lista' });
		expect(exportLink).toHaveAttribute('href', '/decks/7.txt');
		expect(exportLink).toHaveAttribute('data-sveltekit-reload');
		expect(screen.getByRole('link', { name: 'Renomear' })).toHaveAttribute('href', '/app/baralhos/7/renomear');
		expect(screen.getByRole('link', { name: 'Excluir' })).toHaveAttribute('href', '/app/baralhos/7/excluir');
		expect(screen.getByRole('link', { name: 'Voltar aos baralhos' })).toHaveAttribute('href', '/app/baralhos');
	});
});
