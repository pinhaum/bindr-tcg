import '@testing-library/jest-dom/vitest';
import { cleanup, fireEvent, render, screen } from '@testing-library/svelte';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { ApiError } from '../../../lib/api/errors';
import type { WishlistEntry } from '../../../lib/api/types';

vi.mock('$app/paths', () => ({ resolve: (path: string) => `/app${path === '/' ? '/' : path}` }));

const apiMock = vi.hoisted(() => ({ get: vi.fn(), delete: vi.fn() }));
vi.mock('../../../lib/api/index', () => ({ api: apiMock }));

const sessionState = vi.hoisted(() => ({
	status: 'ready',
	user: { email: 'ana@example.com' } as { email: string } | null,
	error: null
}));
vi.mock('../../../lib/session.svelte', () => ({ session: sessionState }));

const toast = vi.hoisted(() => ({ notifySuccess: vi.fn(), notifyError: vi.fn() }));
vi.mock('../../../lib/toasts.svelte', () => toast);

import { load } from './+page';
import Page from './+page.svelte';

const entry = (n: number, extra: Partial<WishlistEntry> = {}): WishlistEntry => ({
	card_number: `OP01-00${n}`,
	card_name: `Carta ${n}`,
	variant_code: `tcgplayer:${n}`,
	target_quantity: 2,
	owned_quantity: 1,
	fulfilled: false,
	...extra
});

const deferred = <T,>() => {
	let resolve!: (value: T) => void;
	const promise = new Promise<T>((res) => {
		resolve = res;
	});
	return { promise, resolve };
};

const removeButton = (n: number) =>
	screen.getByRole('button', { name: new RegExp(`^Remover Carta ${n} `) });

describe('pasta/desejos/+page.ts', () => {
	beforeEach(() => {
		sessionState.user = { email: 'ana@example.com' };
	});

	it('sem sessão redireciona sem chamar o cliente (SPAS-03)', async () => {
		sessionState.user = null;
		apiMock.get.mockReset();
		const url = new URL('http://localhost/app/pasta/desejos');

		await expect(load({ parent: async () => ({}), url } as never)).rejects.toMatchObject({
			status: 307,
			location: '/app/entrar?return_to=%2Fapp%2Fpasta%2Fdesejos'
		});
		expect(apiMock.get).not.toHaveBeenCalled();
	});

	it('com sessão não redireciona', async () => {
		const url = new URL('http://localhost/app/pasta/desejos');
		await expect(load({ parent: async () => ({}), url } as never)).resolves.toBeUndefined();
	});
});

describe('pasta/desejos/+page.svelte', () => {
	beforeEach(() => {
		apiMock.get.mockReset();
		apiMock.delete.mockReset();
		toast.notifySuccess.mockReset();
		toast.notifyError.mockReset();
		apiMock.get.mockResolvedValue([entry(1), entry(2), entry(3)]);
		apiMock.delete.mockResolvedValue({ data: {} });
		sessionState.user = { email: 'ana@example.com' };
	});
	afterEach(() => {
		cleanup();
		vi.useRealTimers();
	});

	it('título, h1 e chamada à API (SPAS-27)', async () => {
		render(Page);
		await screen.findByText('3 itens');

		expect(document.title).toBe('Lista de desejos — Bindr');
		expect(screen.getByRole('heading', { level: 1, name: 'Lista de desejos' })).toBeInTheDocument();
		expect(apiMock.get).toHaveBeenCalledWith('/api/wishlist');
	});

	it('"Carregando lista de desejos…" só após 200 ms (SPAS-06)', async () => {
		vi.useFakeTimers();
		const slow = deferred<unknown>();
		apiMock.get.mockReturnValue(slow.promise);
		const { container } = render(Page);
		const section = () => container.querySelector('section')!;

		expect(screen.queryByText('Carregando lista de desejos…')).not.toBeInTheDocument();
		expect(section()).toHaveAttribute('aria-busy', 'false');
		await vi.advanceTimersByTimeAsync(250);
		expect(screen.getByText('Carregando lista de desejos…')).toBeInTheDocument();
		expect(section()).toHaveAttribute('aria-busy', 'true');
		slow.resolve([entry(1)]);
		await vi.advanceTimersByTimeAsync(0);
		expect(section()).toHaveAttribute('aria-busy', 'false');
	});

	it('erro mostra a message e "Tentar novamente" repete (SPAS-07)', async () => {
		apiMock.get.mockRejectedValueOnce(new ApiError(500, 'internal_error', 'Algo deu errado.', {}));
		render(Page);

		expect(await screen.findByText('Algo deu errado.')).toBeInTheDocument();
		await fireEvent.click(screen.getByRole('button', { name: 'Tentar novamente' }));
		expect(await screen.findByText('3 itens')).toBeInTheDocument();
		expect(apiMock.get).toHaveBeenCalledTimes(2);
	});

	it('lista vazia com link para o catálogo (SPAS-28)', async () => {
		apiMock.get.mockResolvedValue([]);
		render(Page);

		expect(
			await screen.findByText('Você ainda não marcou nenhuma carta como desejada.')
		).toBeInTheDocument();
		expect(screen.getByRole('link', { name: 'catálogo' })).toHaveAttribute('href', '/app');
		expect(
			screen.getByText(/Abra o detalhe de uma carta no/).textContent
		).toBe('Abra o detalhe de uma carta no catálogo e escolha a impressão que quer adquirir.');
	});

	it('contagem no singular e no plural, na ordem de data (SPAS-29)', async () => {
		apiMock.get.mockResolvedValue([entry(2)]);
		render(Page);
		expect(await screen.findByText('1 item')).toBeInTheDocument();
		cleanup();

		apiMock.get.mockResolvedValue([entry(2), entry(1)]);
		render(Page);
		expect(await screen.findByText('2 itens')).toBeInTheDocument();
		const names = screen.getAllByRole('listitem').map((li) => li.textContent);
		expect(names[0]).toContain('Carta 2');
		expect(names[1]).toContain('Carta 1');
	});

	it('remoção com 200 tira o item, atualiza a contagem e avisa (SPAS-33)', async () => {
		render(Page);
		await screen.findByText('3 itens');

		await fireEvent.click(removeButton(2));

		expect(apiMock.delete).toHaveBeenCalledWith(
			'/api/cards/OP01-002/variants/tcgplayer%3A2/wishlist'
		);
		expect(await screen.findByText('2 itens')).toBeInTheDocument();
		expect(screen.queryByText('Carta 2')).not.toBeInTheDocument();
		expect(toast.notifySuccess).toHaveBeenCalledWith('Item removido da lista de desejos.');
	});

	it('foco vai ao seguinte, ao anterior e ao h1 (SPAS-34)', async () => {
		render(Page);
		await screen.findByText('3 itens');

		await fireEvent.click(removeButton(2));
		await screen.findByText('2 itens');
		await vi.waitFor(() => expect(removeButton(3)).toHaveFocus());

		await fireEvent.click(removeButton(3));
		await screen.findByText('1 item');
		await vi.waitFor(() => expect(removeButton(1)).toHaveFocus());

		await fireEvent.click(removeButton(1));
		await screen.findByText('Você ainda não marcou nenhuma carta como desejada.');
		await vi.waitFor(() =>
			expect(screen.getByRole('heading', { level: 1 })).toHaveFocus()
		);
	});

	it('pendência bloqueia só o próprio item (SPAS-35)', async () => {
		const first = deferred<unknown>();
		apiMock.delete.mockReturnValueOnce(first.promise).mockResolvedValueOnce({ data: {} });
		render(Page);
		await screen.findByText('3 itens');

		await fireEvent.click(removeButton(1));
		expect(removeButton(1)).toBeDisabled();
		removeButton(1).removeAttribute('disabled');
		await fireEvent.click(removeButton(1));
		expect(apiMock.delete).toHaveBeenCalledTimes(1);

		expect(removeButton(3)).toBeEnabled();
		await fireEvent.click(removeButton(3));
		expect(await screen.findByText('2 itens')).toBeInTheDocument();
		expect(apiMock.delete).toHaveBeenCalledTimes(2);

		first.resolve({ data: {} });
		expect(await screen.findByText('1 item')).toBeInTheDocument();
	});

	it('500 mantém o item e mostra a message (SPAS-36)', async () => {
		apiMock.delete.mockRejectedValueOnce(
			new ApiError(500, 'internal_error', 'Algo deu errado. Tente de novo.', {})
		);
		render(Page);
		await screen.findByText('3 itens');

		await fireEvent.click(removeButton(2));

		await vi.waitFor(() =>
			expect(toast.notifyError).toHaveBeenCalledWith('Algo deu errado. Tente de novo.')
		);
		expect(screen.getByText('3 itens')).toBeInTheDocument();
		expect(removeButton(2)).toBeEnabled();
		await vi.waitFor(() => expect(removeButton(2)).toHaveFocus());
		expect(toast.notifySuccess).not.toHaveBeenCalled();
	});
});
