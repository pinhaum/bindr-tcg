import '@testing-library/jest-dom/vitest';
import { cleanup, fireEvent, render, screen } from '@testing-library/svelte';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { ApiError } from '../../../lib/api/errors';

vi.mock('$app/paths', () => ({ resolve: (path: string) => `/app${path === '/' ? '/' : path}` }));

const nav = vi.hoisted(() => ({ goto: vi.fn() }));
vi.mock('$app/navigation', () => nav);

const apiMock = vi.hoisted(() => ({ post: vi.fn() }));
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

describe('baralhos/novo/+page.ts', () => {
	beforeEach(() => {
		sessionState.user = { email: 'ana@example.com' };
	});

	it('sem sessão redireciona para entrar com return_to (SDEC-03)', async () => {
		sessionState.user = null;
		const url = new URL('http://localhost/app/baralhos/novo');
		await expect(load({ parent: async () => ({}), url } as never)).rejects.toMatchObject({
			status: 307,
			location: '/app/entrar?return_to=%2Fapp%2Fbaralhos%2Fnovo'
		});
	});

	it('com sessão não redireciona', async () => {
		const url = new URL('http://localhost/app/baralhos/novo');
		await expect(load({ parent: async () => ({}), url } as never)).resolves.toBeUndefined();
	});
});

describe('baralhos/novo/+page.svelte', () => {
	beforeEach(() => {
		apiMock.post.mockReset();
		nav.goto.mockReset();
		toast.notifySuccess.mockReset();
		apiMock.post.mockResolvedValue({ id: 12, name: 'Red Zoro' });
	});
	afterEach(cleanup);

	it('título, h1 e campo vazio (SDEC-10)', () => {
		render(Page);

		expect(document.title).toBe('Novo deck — Bindr');
		expect(screen.getByRole('heading', { level: 1, name: 'Novo deck' })).toBeInTheDocument();
		expect(screen.getByLabelText(/Nome do deck/)).toHaveValue('');
	});

	it('envia { name }, navega ao deck e avisa "Deck criado." (SDEC-11)', async () => {
		render(Page);
		await fireEvent.input(screen.getByLabelText(/Nome do deck/), { target: { value: 'Red Zoro' } });
		await fireEvent.click(screen.getByRole('button', { name: 'Criar deck' }));

		await vi.waitFor(() => expect(toast.notifySuccess).toHaveBeenCalledWith('Deck criado.'));
		expect(apiMock.post).toHaveBeenCalledWith('/api/decks', { name: 'Red Zoro' });
		expect(nav.goto).toHaveBeenCalledWith('/app/baralhos/12');
	});

	it('recusa da API mostra o erro e não navega', async () => {
		apiMock.post.mockRejectedValue(
			new ApiError(422, 'validation_failed', 'Nome inválido.', { name: ['Nome não pode ficar em branco'] })
		);
		render(Page);
		await fireEvent.input(screen.getByLabelText(/Nome do deck/), { target: { value: ' ' } });
		await fireEvent.click(screen.getByRole('button', { name: 'Criar deck' }));

		expect(await screen.findByText('Nome não pode ficar em branco')).toBeInTheDocument();
		expect(nav.goto).not.toHaveBeenCalled();
		expect(toast.notifySuccess).not.toHaveBeenCalled();
	});
});
