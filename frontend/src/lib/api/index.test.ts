import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

// `base` saiu dos tipos do SvelteKit 3 e chega `undefined` no Vitest; `resolve` é a API tipada.
vi.mock('$app/paths', () => ({ resolve: (path: string) => `/app${path}` }));

const goto = vi.hoisted(() => vi.fn());
vi.mock('$app/navigation', () => ({ goto }));

const currentPage = vi.hoisted(() => ({ url: new URL('http://localhost/app/x?y=1') }));
vi.mock('$app/state', () => ({ page: currentPage }));

// Importa `api` antes de `session`: exercita o ciclo entre os dois módulos nessa ordem.
import { api } from './index';
import { session } from '../session.svelte';

const ana = { email: 'ana@example.com' };
const bia = { email: 'bia@example.com' };

const json = (status: number, body: unknown) =>
	new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });

const staleCsrf = () =>
	json(422, { error: { code: 'invalid_csrf_token', message: 'Token inválido.' } });

describe('api (instância ligada à sessão)', () => {
	const fetchMock = vi.fn();

	beforeEach(() => {
		vi.stubGlobal('fetch', fetchMock);
		session.status = 'ready';
		session.user = ana;
		session.error = null;
	});

	afterEach(() => {
		vi.unstubAllGlobals();
		vi.clearAllMocks();
		fetchMock.mockReset();
	});

	it('usa o fetch global', async () => {
		fetchMock.mockResolvedValue(json(200, { data: { ok: true } }));

		await api.get('/api/catalog');

		expect(fetchMock).toHaveBeenCalledOnce();
		expect(fetchMock.mock.calls[0][0]).toBe('/api/catalog');
	});

	it('401 unauthenticated limpa o usuário e vai para entrar com o caminho atual', async () => {
		fetchMock.mockResolvedValue(
			json(401, { error: { code: 'unauthenticated', message: 'Faça login para continuar.' } })
		);

		await expect(api.get('/api/catalog')).rejects.toMatchObject({ code: 'unauthenticated' });

		expect(session.user).toBeNull();
		expect(goto).toHaveBeenCalledWith('/app/entrar?return_to=%2Fapp%2Fx%3Fy%3D1');
	});

	it('CSRF desatualizado com o mesmo usuário reenvia a mutação uma vez (currentUserEmail)', async () => {
		fetchMock
			.mockResolvedValueOnce(staleCsrf())
			.mockResolvedValueOnce(json(200, { data: { user: ana, csrf_token: 'tok-novo' } }))
			.mockResolvedValueOnce(json(200, { data: { saved: true } }));

		await expect(api.post('/api/things', { a: 1 })).resolves.toEqual({ saved: true });

		expect(fetchMock).toHaveBeenCalledTimes(3);
		expect(goto).not.toHaveBeenCalled();
	});

	it('CSRF desatualizado com outro usuário troca a sessão, vai para a base e entrega session_changed', async () => {
		fetchMock
			.mockResolvedValueOnce(staleCsrf())
			.mockResolvedValueOnce(json(200, { data: { user: bia, csrf_token: 'tok-bia' } }));

		await expect(api.post('/api/things', { a: 1 })).rejects.toMatchObject({
			code: 'session_changed',
			message: 'A sessão mudou em outra aba. Confira a conta e tente de novo.'
		});

		expect(session.user).toEqual(bia);
		expect(goto).toHaveBeenCalledWith('/app');
		expect(fetchMock).toHaveBeenCalledTimes(2);
	});
});
