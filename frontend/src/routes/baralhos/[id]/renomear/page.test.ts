import '@testing-library/jest-dom/vitest';
import { cleanup, fireEvent, render, screen } from '@testing-library/svelte';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { ApiError } from '../../../../lib/api/errors';

vi.mock('$app/paths', () => ({ resolve: (path: string) => `/app${path === '/' ? '/' : path}` }));

const nav = vi.hoisted(() => ({ goto: vi.fn() }));
vi.mock('$app/navigation', () => nav);
vi.mock('$app/state', () => ({ page: { params: { id: '7' } } }));

const apiMock = vi.hoisted(() => ({ get: vi.fn(), patch: vi.fn() }));
vi.mock('../../../../lib/api/index', () => ({ api: apiMock }));

const sessionState = vi.hoisted(() => ({
	user: { email: 'ana@example.com' } as { email: string } | null
}));
vi.mock('../../../../lib/session.svelte', () => ({ session: sessionState }));

const toast = vi.hoisted(() => ({ notifySuccess: vi.fn(), notifyError: vi.fn() }));
vi.mock('../../../../lib/toasts.svelte', () => toast);

import { load } from './+page';
import Page from './+page.svelte';

describe('baralhos/[id]/renomear/+page.ts', () => {
	beforeEach(() => {
		sessionState.user = { email: 'ana@example.com' };
	});

	it('sem sessão redireciona para entrar com return_to (SDEC-03)', async () => {
		sessionState.user = null;
		const url = new URL('http://localhost/app/baralhos/7/renomear');
		await expect(load({ parent: async () => ({}), url } as never)).rejects.toMatchObject({
			status: 307,
			location: '/app/entrar?return_to=%2Fapp%2Fbaralhos%2F7%2Frenomear'
		});
	});

	it('com sessão não redireciona', async () => {
		const url = new URL('http://localhost/app/baralhos/7/renomear');
		await expect(load({ parent: async () => ({}), url } as never)).resolves.toBeUndefined();
	});
});

describe('baralhos/[id]/renomear/+page.svelte', () => {
	beforeEach(() => {
		sessionState.user = { email: 'ana@example.com' };
		apiMock.get.mockReset().mockResolvedValue({ id: 7, name: 'Red Zoro' });
		apiMock.patch.mockReset().mockResolvedValue({ id: 7, name: 'Green Law' });
		nav.goto.mockReset();
		toast.notifySuccess.mockReset();
	});
	afterEach(cleanup);

	it('título, h1 e campo com o nome atual (SDEC-10)', async () => {
		render(Page);

		expect(await screen.findByLabelText(/Nome do deck/)).toHaveValue('Red Zoro');
		expect(document.title).toBe('Renomear deck — Bindr');
		expect(screen.getByRole('heading', { level: 1, name: 'Renomear deck' })).toBeInTheDocument();
		expect(apiMock.get).toHaveBeenCalledWith('/api/decks/7');
	});

	it('404 mostra DeckNotFound (SDEC-18)', async () => {
		apiMock.get.mockRejectedValue(new ApiError(404, 'not_found', 'Deck não encontrado.', {}));
		render(Page);

		expect(await screen.findByRole('heading', { level: 1, name: 'Deck não encontrado.' })).toBeInTheDocument();
		expect(screen.queryByLabelText(/Nome do deck/)).not.toBeInTheDocument();
	});

	it('envia PATCH { name }, navega ao deck e avisa "Deck renomeado." (SDEC-12)', async () => {
		render(Page);
		const field = await screen.findByLabelText(/Nome do deck/);
		await fireEvent.input(field, { target: { value: 'Green Law' } });
		await fireEvent.click(screen.getByRole('button', { name: 'Renomear deck' }));

		await vi.waitFor(() => expect(toast.notifySuccess).toHaveBeenCalledWith('Deck renomeado.'));
		expect(apiMock.patch).toHaveBeenCalledWith('/api/decks/7', { name: 'Green Law' });
		expect(nav.goto).toHaveBeenCalledWith('/app/baralhos/7');
	});

	it('recusa da API mostra o erro e não navega', async () => {
		apiMock.patch.mockRejectedValue(
			new ApiError(422, 'validation_failed', 'Nome inválido.', { name: ['Nome já em uso'] })
		);
		render(Page);
		await screen.findByLabelText(/Nome do deck/);
		await fireEvent.click(screen.getByRole('button', { name: 'Renomear deck' }));

		expect(await screen.findByText('Nome já em uso')).toBeInTheDocument();
		expect(nav.goto).not.toHaveBeenCalled();
		expect(toast.notifySuccess).not.toHaveBeenCalled();
	});
});
