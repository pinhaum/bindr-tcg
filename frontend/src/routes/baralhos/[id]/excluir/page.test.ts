import '@testing-library/jest-dom/vitest';
import { cleanup, fireEvent, render, screen } from '@testing-library/svelte';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { ApiError } from '../../../../lib/api/errors';

vi.mock('$app/paths', () => ({ resolve: (path: string) => `/app${path === '/' ? '/' : path}` }));

const nav = vi.hoisted(() => ({ goto: vi.fn() }));
vi.mock('$app/navigation', () => nav);
vi.mock('$app/state', () => ({ page: { params: { id: '7' } } }));

const apiMock = vi.hoisted(() => ({ get: vi.fn(), delete: vi.fn() }));
vi.mock('../../../../lib/api/index', () => ({ api: apiMock }));

const sessionState = vi.hoisted(() => ({
	user: { email: 'ana@example.com' } as { email: string } | null
}));
vi.mock('../../../../lib/session.svelte', () => ({ session: sessionState }));

const toast = vi.hoisted(() => ({ notifySuccess: vi.fn(), notifyError: vi.fn() }));
vi.mock('../../../../lib/toasts.svelte', () => toast);

import { load } from './+page';
import Page from './+page.svelte';

describe('baralhos/[id]/excluir/+page.ts', () => {
	beforeEach(() => {
		sessionState.user = { email: 'ana@example.com' };
	});

	it('sem sessão redireciona para entrar com return_to (SDEC-03)', async () => {
		sessionState.user = null;
		const url = new URL('http://localhost/app/baralhos/7/excluir');
		await expect(load({ parent: async () => ({}), url } as never)).rejects.toMatchObject({
			status: 307,
			location: '/app/entrar?return_to=%2Fapp%2Fbaralhos%2F7%2Fexcluir'
		});
	});

	it('com sessão não redireciona', async () => {
		const url = new URL('http://localhost/app/baralhos/7/excluir');
		await expect(load({ parent: async () => ({}), url } as never)).resolves.toBeUndefined();
	});
});

describe('baralhos/[id]/excluir/+page.svelte', () => {
	beforeEach(() => {
		sessionState.user = { email: 'ana@example.com' };
		apiMock.get.mockReset().mockResolvedValue({ id: 7, name: 'Red Zoro' });
		apiMock.delete.mockReset().mockResolvedValue({ id: 7 });
		nav.goto.mockReset();
		toast.notifySuccess.mockReset();
		toast.notifyError.mockReset();
	});
	afterEach(cleanup);

	it('abrir só consulta o deck e mostra a confirmação (SDEC-15)', async () => {
		render(Page);

		expect(
			await screen.findByRole('heading', { level: 1, name: 'Excluir o deck “Red Zoro”?' })
		).toBeInTheDocument();
		expect(document.title).toBe('Excluir deck — Bindr');
		expect(
			screen.getByText('O deck e as cartas dele somem. Sua coleção e sua wishlist não mudam.')
		).toBeInTheDocument();
		expect(screen.getByRole('button', { name: 'Excluir deck' })).toBeInTheDocument();
		expect(screen.getByRole('link', { name: 'Cancelar' })).toHaveAttribute('href', '/app/baralhos/7');
		expect(apiMock.get).toHaveBeenCalledWith('/api/decks/7');
		expect(apiMock.delete).not.toHaveBeenCalled();
	});

	it('confirmar envia DELETE, navega à lista e avisa (SDEC-16)', async () => {
		render(Page);
		await fireEvent.click(await screen.findByRole('button', { name: 'Excluir deck' }));

		await vi.waitFor(() =>
			expect(toast.notifySuccess).toHaveBeenCalledWith('Deck “Red Zoro” excluído.')
		);
		expect(apiMock.delete).toHaveBeenCalledWith('/api/decks/7');
		expect(nav.goto).toHaveBeenCalledWith('/app/baralhos');
		expect(nav.goto.mock.invocationCallOrder[0]).toBeLessThan(
			toast.notifySuccess.mock.invocationCallOrder[0]
		);
	});

	it('erro mantém a tela e usa notifyError (SDEC-16)', async () => {
		apiMock.delete.mockRejectedValue(new ApiError(500, 'internal_error', 'Algo deu errado.', {}));
		render(Page);
		await fireEvent.click(await screen.findByRole('button', { name: 'Excluir deck' }));

		await vi.waitFor(() => expect(toast.notifyError).toHaveBeenCalledWith('Algo deu errado.'));
		expect(nav.goto).not.toHaveBeenCalled();
		expect(toast.notifySuccess).not.toHaveBeenCalled();
		expect(screen.getByRole('button', { name: 'Excluir deck' })).toBeEnabled();
	});

	it('404 mostra DeckNotFound (SDEC-18)', async () => {
		apiMock.get.mockRejectedValue(new ApiError(404, 'not_found', 'Deck não encontrado.', {}));
		render(Page);

		expect(
			await screen.findByRole('heading', { level: 1, name: 'Deck não encontrado.' })
		).toBeInTheDocument();
		expect(screen.queryByRole('button', { name: 'Excluir deck' })).not.toBeInTheDocument();
	});
});
