import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { ApiError } from './api/errors';
import { toasts } from './toasts.svelte';

// `base` saiu dos tipos do SvelteKit 3 e chega `undefined` no Vitest; `resolve` é a API tipada.
vi.mock('$app/paths', () => ({ resolve: (path: string) => path }));

const goto = vi.hoisted(() => vi.fn());
vi.mock('$app/navigation', () => ({ goto }));

const currentPage = vi.hoisted(() => ({ url: new URL('http://localhost/') }));
const navigation = vi.hoisted(() => ({ navigating: { to: null as { url: URL } | null } }));
vi.mock('$app/state', () => ({ page: currentPage, navigating: navigation.navigating }));

const api = vi.hoisted(() => ({
	get: vi.fn(),
	post: vi.fn(),
	patch: vi.fn(),
	put: vi.fn(),
	delete: vi.fn(),
	setCsrfToken: vi.fn()
}));
vi.mock('./api/index', () => ({ api }));

import { handleSessionChanged, handleUnauthenticated, loadSession, session, signIn, signOut, signUp } from './session.svelte';

const ana = { email: 'ana@example.com' };

const visit = (path: string) => {
	currentPage.url = new URL(`http://localhost${path}`);
};

describe('session', () => {
	beforeEach(() => {
		vi.useFakeTimers();
		session.status = 'loading';
		session.user = null;
		session.error = null;
		visit('/');
		navigation.navigating.to = null;
	});

	afterEach(() => {
		toasts.splice(0);
		vi.useRealTimers();
		vi.clearAllMocks();
	});

	describe('loadSession', () => {
		it('guarda o usuário e deixa o estado pronto', async () => {
			api.get.mockResolvedValue({ user: ana, csrf_token: 'tok-1' });

			await loadSession();

			expect(api.get).toHaveBeenCalledWith('/api/session');
			expect(session.user).toEqual(ana);
			expect(session.status).toBe('ready');
			expect(session.error).toBeNull();
		});

		it('guarda user nulo quando a sessão é anônima', async () => {
			api.get.mockResolvedValue({ user: null, csrf_token: 'tok-1' });

			await loadSession();

			expect(session.user).toBeNull();
			expect(session.status).toBe('ready');
		});

		it('relança o erro sem mexer no estado', async () => {
			const failure = new ApiError(0, 'network_error', 'Sem conexão com o servidor. Tente novamente.');
			api.get.mockRejectedValue(failure);

			await expect(loadSession()).rejects.toBe(failure);

			expect(session.status).toBe('loading');
			expect(session.user).toBeNull();
		});
	});

	describe('signIn', () => {
		it('envia e-mail e senha no topo do corpo e guarda o usuário', async () => {
			api.post.mockResolvedValue({ user: ana, csrf_token: 'tok-2' });

			await signIn('ana@example.com', 'segredo123');

			expect(api.post).toHaveBeenCalledWith('/api/session', { email: 'ana@example.com', password: 'segredo123' });
			expect(session.user).toEqual(ana);
		});

		it('relança o erro e mantém o usuário', async () => {
			const failure = new ApiError(401, 'invalid_credentials', 'E-mail ou senha inválidos.');
			api.post.mockRejectedValue(failure);

			await expect(signIn('ana@example.com', 'errada')).rejects.toBe(failure);

			expect(session.user).toBeNull();
		});
	});

	describe('signUp', () => {
		it('envia os campos dentro do envelope user e guarda o usuário', async () => {
			api.post.mockResolvedValue({ user: ana, csrf_token: 'tok-3' });

			await signUp({ email: 'ana@example.com', password: 'segredo123', password_confirmation: 'segredo123' });

			expect(api.post).toHaveBeenCalledWith('/api/registration', {
				user: { email: 'ana@example.com', password: 'segredo123', password_confirmation: 'segredo123' }
			});
			expect(session.user).toEqual(ana);
		});

		it('relança o erro e mantém o usuário', async () => {
			const failure = new ApiError(422, 'validation_failed', 'Dados inválidos.', { email: ['já está em uso'] });
			api.post.mockRejectedValue(failure);

			await expect(
				signUp({ email: 'ana@example.com', password: 'x', password_confirmation: 'x' })
			).rejects.toBe(failure);

			expect(session.user).toBeNull();
		});
	});

	describe('signOut', () => {
		beforeEach(() => {
			session.user = ana;
		});

		const expectSignedOut = () => {
			expect(api.delete).toHaveBeenCalledWith('/api/session');
			expect(session.user).toBeNull();
			expect(goto).toHaveBeenCalledTimes(1);
			expect(goto).toHaveBeenCalledWith('/');
			expect(toasts).toHaveLength(1);
			expect(toasts[0]).toMatchObject({ kind: 'success', message: 'Sessão encerrada.' });
		};

		it('com 200 limpa o usuário, vai para a base e avisa', async () => {
			api.delete.mockResolvedValue({ user: null, csrf_token: 'tok-4' });

			await signOut();

			expectSignedOut();
		});

		it('com unauthenticated conclui a saída do mesmo jeito', async () => {
			api.delete.mockRejectedValue(new ApiError(401, 'unauthenticated', 'Faça login para continuar.'));

			await signOut();

			expectSignedOut();
		});

		it('com outro erro relança sem mudar o usuário nem navegar', async () => {
			const failure = new ApiError(0, 'network_error', 'Sem conexão com o servidor. Tente novamente.');
			api.delete.mockRejectedValue(failure);

			await expect(signOut()).rejects.toBe(failure);

			expect(session.user).toEqual(ana);
			expect(goto).not.toHaveBeenCalled();
			expect(toasts).toHaveLength(0);
		});
	});

	describe('signOut com sessão trocada', () => {
		it('relança session_changed sem toast nem navegação própria', async () => {
			session.user = ana;
			const novo = { email: 'bia@example.com' };
			const failure = new ApiError(409, 'session_changed', 'Sessão alterada.');
			api.delete.mockImplementation(async () => {
				handleSessionChanged(novo);
				throw failure;
			});

			await expect(signOut()).rejects.toBe(failure);

			expect(session.user).toEqual(novo);
			expect(goto).toHaveBeenCalledTimes(1);
			expect(toasts).toHaveLength(0);
		});
	});

	describe('handleSessionChanged', () => {
		it('troca o usuário e navega para a base uma vez', () => {
			handleSessionChanged(ana);

			expect(session.user).toEqual(ana);
			expect(goto).toHaveBeenCalledTimes(1);
			expect(goto).toHaveBeenCalledWith('/');
		});
	});

	describe('handleUnauthenticated', () => {
		beforeEach(() => {
			session.user = ana;
		});

		it('limpa o usuário e vai para entrar com o caminho atual codificado', () => {
			visit('/x?y=1');

			handleUnauthenticated();

			expect(session.user).toBeNull();
			expect(goto).toHaveBeenCalledWith('/entrar?return_to=%2Fx%3Fy%3D1');
		});

		it.each([['/entrar'], ['/entrar?return_to=%2Fx'], ['/criar-conta'], ['/criar-conta?x=1']])('não navega a partir de %s, mas limpa o usuário', (path) => {
			visit(path);

			handleUnauthenticated();

			expect(session.user).toBeNull();
			expect(goto).not.toHaveBeenCalled();
		});
	});
});
