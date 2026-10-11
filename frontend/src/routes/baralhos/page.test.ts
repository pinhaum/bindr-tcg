import '@testing-library/jest-dom/vitest';
import { cleanup, fireEvent, render, screen, within } from '@testing-library/svelte';
import { tick } from 'svelte';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { ApiError } from '../../lib/api/errors';
import type { DeckSummary } from '../../lib/api/types';

vi.mock('$app/paths', () => ({ resolve: (path: string) => `/app${path === '/' ? '/' : path}` }));

const apiMock = vi.hoisted(() => ({ get: vi.fn() }));
vi.mock('../../lib/api/index', () => ({ api: apiMock }));

type SessionUser = { email: string } | null;
const sessionState = vi.hoisted(() => ({ user: null as SessionUser }));
vi.mock('../../lib/session.svelte', async () => {
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

import { session } from '../../lib/session.svelte';
Object.defineProperty(sessionState, 'user', {
	get: () => (session as unknown as { user: SessionUser }).user,
	set: (value: SessionUser) => {
		(session as unknown as { user: SessionUser }).user = value;
	}
});

import { load } from './+page';
import Page from './+page.svelte';

const decks = (): DeckSummary[] => [
	{
		id: 7,
		name: 'Red Zoro',
		leader: { card_number: 'OP01-001', name: 'Roronoa Zoro' },
		main_total: 50,
		status: 'valid'
	},
	{ id: 3, name: 'Rascunho', leader: null, main_total: 12, status: 'incomplete' },
	{
		id: 9,
		name: 'Quebrado',
		leader: { card_number: 'OP02-001', name: 'Edward Newgate' },
		main_total: 51,
		status: 'invalid'
	}
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

describe('baralhos/+page.ts', () => {
	beforeEach(() => {
		sessionState.user = { email: 'ana@example.com' };
	});

	it('sem sessão redireciona para entrar com return_to, sem chamar o cliente (SDEC-03)', async () => {
		sessionState.user = null;
		apiMock.get.mockReset();
		const url = new URL('http://localhost/app/baralhos');

		await expect(load({ parent: async () => ({}), url } as never)).rejects.toMatchObject({
			status: 307,
			location: '/app/entrar?return_to=%2Fapp%2Fbaralhos'
		});
		expect(apiMock.get).not.toHaveBeenCalled();
	});

	it('com sessão não redireciona', async () => {
		const url = new URL('http://localhost/app/baralhos');
		await expect(load({ parent: async () => ({}), url } as never)).resolves.toBeUndefined();
	});
});

describe('baralhos/+page.svelte', () => {
	beforeEach(() => {
		apiMock.get.mockReset();
		apiMock.get.mockResolvedValue(decks());
		sessionState.user = { email: 'ana@example.com' };
	});
	afterEach(() => {
		cleanup();
		vi.useRealTimers();
	});

	it('título e h1 (SDEC-01)', async () => {
		render(Page);

		expect(screen.getByRole('heading', { level: 1, name: 'Baralhos' })).toBeInTheDocument();
		expect(document.title).toBe('Baralhos — Bindr');
		await screen.findByRole('heading', { level: 2, name: 'Red Zoro' });
		expect(apiMock.get).toHaveBeenCalledWith('/api/decks');
	});

	it('mostra cada deck na ordem da API com Leader, N / 50, status e link (SDEC-07)', async () => {
		render(Page);

		const headings = await screen.findAllByRole('heading', { level: 2 });
		expect(headings.map((h) => h.textContent?.trim())).toEqual(['Red Zoro', 'Rascunho', 'Quebrado']);

		const [first, second, third] = screen.getAllByRole('listitem').filter((li) => li.querySelector('h2'));
		expect(within(first).getByRole('link', { name: 'Red Zoro' })).toHaveAttribute('href', '/app/baralhos/7');
		expect(within(first).getByText('Roronoa Zoro (OP01-001)')).toBeInTheDocument();
		expect(within(first).getByText('50 / 50')).toBeInTheDocument();
		expect(within(first).getByText('válido')).toBeInTheDocument();

		expect(within(second).getByText('Sem Leader')).toBeInTheDocument();
		expect(within(second).getByText('12 / 50')).toBeInTheDocument();
		expect(within(second).getByText('incompleto')).toBeInTheDocument();

		expect(within(third).getByText('51 / 50')).toBeInTheDocument();
		expect(within(third).getByText('inválido')).toBeInTheDocument();
	});

	it('lista vazia (SDEC-08)', async () => {
		apiMock.get.mockResolvedValue([]);
		render(Page);

		expect(await screen.findByText('Você ainda não tem decks.')).toBeInTheDocument();
		expect(screen.queryByRole('heading', { level: 2 })).not.toBeInTheDocument();
	});

	it('oferece Novo deck e Importar lista, também com a lista vazia (SDEC-09)', async () => {
		apiMock.get.mockResolvedValue([]);
		render(Page);

		expect(screen.getByRole('link', { name: 'Novo deck' })).toHaveAttribute('href', '/app/baralhos/novo');
		expect(screen.getByRole('link', { name: 'Importar lista' })).toHaveAttribute(
			'href',
			'/app/baralhos/importar'
		);
		await screen.findByText('Você ainda não tem decks.');
	});

	it('antes de 200 ms nada muda; depois marca aria-busy e anuncia (SDEC-04)', async () => {
		vi.useFakeTimers();
		const pending = deferred<DeckSummary[]>();
		apiMock.get.mockReturnValue(pending.promise);
		const { container } = render(Page);
		const section = container.querySelector('section')!;

		await vi.advanceTimersByTimeAsync(199);
		expect(section).toHaveAttribute('aria-busy', 'false');
		expect(screen.queryByText('Carregando baralhos…')).not.toBeInTheDocument();

		await vi.advanceTimersByTimeAsync(1);
		expect(section).toHaveAttribute('aria-busy', 'true');
		expect(screen.getByText('Carregando baralhos…')).toBeInTheDocument();

		pending.resolve(decks());
		await vi.advanceTimersByTimeAsync(0);
		expect(section).toHaveAttribute('aria-busy', 'false');
		expect(screen.queryByText('Carregando baralhos…')).not.toBeInTheDocument();
	});

	it('descarta a resposta antiga quando a sessão troca de conta (SDEC-05)', async () => {
		const first = deferred<DeckSummary[]>();
		const second = deferred<DeckSummary[]>();
		apiMock.get.mockReturnValueOnce(first.promise).mockReturnValueOnce(second.promise);
		render(Page);
		await tick();

		sessionState.user = { email: 'bia@example.com' };
		await tick();
		expect(apiMock.get).toHaveBeenCalledTimes(2);

		second.resolve([{ id: 1, name: 'Da Bia', leader: null, main_total: 0, status: 'incomplete' }]);
		await screen.findByRole('heading', { level: 2, name: 'Da Bia' });

		first.resolve(decks());
		await tick();
		expect(screen.queryByRole('heading', { level: 2, name: 'Red Zoro' })).not.toBeInTheDocument();
		expect(screen.getByRole('heading', { level: 2, name: 'Da Bia' })).toBeInTheDocument();
	});

	it('erro mostra a mensagem e "Tentar novamente" repete a consulta (SDEC-06)', async () => {
		apiMock.get.mockRejectedValueOnce(new ApiError(500, 'internal_error', 'Algo deu errado.'));
		render(Page);

		expect(await screen.findByText('Algo deu errado.')).toBeInTheDocument();

		apiMock.get.mockResolvedValueOnce(decks());
		await fireEvent.click(screen.getByRole('button', { name: 'Tentar novamente' }));

		expect(await screen.findByRole('heading', { level: 2, name: 'Red Zoro' })).toBeInTheDocument();
		expect(screen.queryByText('Algo deu errado.')).not.toBeInTheDocument();
		expect(apiMock.get).toHaveBeenCalledTimes(2);
	});
});
