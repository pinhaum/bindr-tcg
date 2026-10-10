import { afterEach, describe, expect, it, vi } from 'vitest';
import { ApiError } from './errors';
import { createApiClient } from './client';
import type { SessionUser } from './types';

const json = (body: unknown, status = 200): Response =>
	new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });

const setup = (respond: () => Response | Promise<Response> = () => json({ data: null }), timeoutMs?: number) => {
	const fetch = vi.fn<typeof globalThis.fetch>(async () => respond());
	const onUnauthenticated = vi.fn<() => void>();
	const onSessionChanged = vi.fn<(user: SessionUser) => void>();
	const currentUserEmail = vi.fn<() => string | null>(() => null);
	const client = createApiClient({ fetch, onUnauthenticated, currentUserEmail, onSessionChanged, timeoutMs });
	return { fetch, client, onUnauthenticated, onSessionChanged, currentUserEmail };
};

const lastCall = (fetch: ReturnType<typeof setup>['fetch']) => {
	const [url, init] = fetch.mock.calls.at(-1)!;
	return { url: String(url), init: init!, headers: new Headers(init!.headers) };
};

const caught = async (promise: Promise<unknown>): Promise<ApiError> => {
	const error = await promise.then(
		() => null,
		(e: unknown) => e
	);
	expect(error).toBeInstanceOf(ApiError);
	return error as ApiError;
};

afterEach(() => {
	vi.restoreAllMocks();
});

describe('createApiClient request shape', () => {
	it('sends same-origin credentials and the JSON Accept header on every verb', async () => {
		const { fetch, client } = setup();

		await client.get('/api/catalog');
		expect(lastCall(fetch).init.credentials).toBe('same-origin');
		expect(lastCall(fetch).headers.get('Accept')).toBe('application/json');

		await client.post('/api/session', { email: 'a@b.c' });
		expect(lastCall(fetch).init.credentials).toBe('same-origin');
		expect(lastCall(fetch).headers.get('Accept')).toBe('application/json');
	});

	it('uses the right method and JSON-encodes the body with Content-Type', async () => {
		const { fetch, client } = setup();

		await client.post('/api/session', { email: 'a@b.c', password: 'x' });
		let call = lastCall(fetch);
		expect(call.url).toBe('/api/session');
		expect(call.init.method).toBe('POST');
		expect(call.headers.get('Content-Type')).toBe('application/json');
		expect(call.init.body).toBe('{"email":"a@b.c","password":"x"}');

		await client.patch('/api/x', { a: 1 });
		expect(lastCall(fetch).init.method).toBe('PATCH');
		await client.put('/api/x', { a: 1 });
		expect(lastCall(fetch).init.method).toBe('PUT');
		await client.delete('/api/session');
		call = lastCall(fetch);
		expect(call.init.method).toBe('DELETE');
		expect(call.init.body).toBeUndefined();
	});

	it('sends no body and no Content-Type on GET', async () => {
		const { fetch, client } = setup();

		await client.get('/api/catalog');

		const call = lastCall(fetch);
		expect(call.init.method).toBe('GET');
		expect(call.init.body).toBeUndefined();
		expect(call.headers.has('Content-Type')).toBe(false);
	});

	it('appends the query string, skipping undefined values and encoding the rest', async () => {
		const { fetch, client } = setup();

		await client.get('/api/catalog', { q: 'monkey d luffy', page: 2, owned: true, set: undefined });

		expect(lastCall(fetch).url).toBe('/api/catalog?q=monkey+d+luffy&page=2&owned=true');
	});

	it('adds no question mark when the query is empty', async () => {
		const { fetch, client } = setup();

		await client.get('/api/catalog', { set: undefined });

		expect(lastCall(fetch).url).toBe('/api/catalog');
	});

	it('passes AbortSignal.timeout(15000) by default and the custom value when given', async () => {
		const timeout = vi.spyOn(AbortSignal, 'timeout');
		const first = setup();
		await first.client.get('/api/x');
		expect(timeout).toHaveBeenLastCalledWith(15000);
		expect(lastCall(first.fetch).init.signal).toBeInstanceOf(AbortSignal);

		const second = setup(undefined, 250);
		await second.client.get('/api/x');
		expect(timeout).toHaveBeenLastCalledWith(250);
	});
});

describe('createApiClient CSRF token', () => {
	it.each(['post', 'patch', 'put', 'delete'] as const)('sends X-CSRF-Token on %s', async (verb) => {
		const { fetch, client } = setup();
		client.setCsrfToken('tok-1');

		await client[verb]('/api/x');

		expect(lastCall(fetch).headers.get('X-CSRF-Token')).toBe('tok-1');
	});

	it('does not send X-CSRF-Token on GET even with a token', async () => {
		const { fetch, client } = setup();
		client.setCsrfToken('tok-1');

		await client.get('/api/x');

		expect(lastCall(fetch).headers.has('X-CSRF-Token')).toBe(false);
	});

	it('sends no X-CSRF-Token on a mutation while there is no token', async () => {
		const { fetch, client } = setup();

		await client.post('/api/x');
		expect(lastCall(fetch).headers.has('X-CSRF-Token')).toBe(false);

		client.setCsrfToken('tok-1');
		client.setCsrfToken(null);
		await client.post('/api/x');
		expect(lastCall(fetch).headers.has('X-CSRF-Token')).toBe(false);
	});

	it('swaps the token after a response carrying data.csrf_token, on any route', async () => {
		let body: unknown = { data: { user: null, csrf_token: 'tok-2' } };
		const { fetch, client } = setup(() => json(body));
		client.setCsrfToken('tok-1');

		await client.get('/api/session');
		await client.post('/api/x');

		expect(lastCall(fetch).headers.get('X-CSRF-Token')).toBe('tok-2');
		body = { data: { csrf_token: 'tok-3' } };
		await client.post('/api/x');
		await client.post('/api/x');
		expect(lastCall(fetch).headers.get('X-CSRF-Token')).toBe('tok-3');
	});

	it('keeps the token after responses without a string csrf_token', async () => {
		const bodies: unknown[] = [{ data: { ok: true } }, { data: null }, { data: [1] }, { data: { csrf_token: 42 } }];
		const { fetch, client } = setup(() => json(bodies.shift() ?? { data: null }));
		client.setCsrfToken('tok-1');

		for (let i = 0; i < 4; i++) await client.post('/api/x');
		await client.post('/api/x');

		expect(lastCall(fetch).headers.get('X-CSRF-Token')).toBe('tok-1');
	});
});

describe('createApiClient envelope', () => {
	it('returns the data of the envelope', async () => {
		const { client } = setup(() => json({ data: { user: { email: 'a@b.c' } }, meta: { page: 1 } }));

		await expect(client.get('/api/session')).resolves.toEqual({ user: { email: 'a@b.c' } });
	});

	it('accepts falsy data values', async () => {
		const { client } = setup(() => json({ data: null }));

		await expect(client.delete('/api/session')).resolves.toBeNull();
	});

	it('turns an error envelope into an ApiError with the exact fields', async () => {
		const { client } = setup(() =>
			json(
				{
					error: {
						code: 'validation_failed',
						message: 'Dados inválidos.',
						fields: { email: ['não pode ficar em branco'] }
					}
				},
				422
			)
		);

		const error = await caught(client.post('/api/registration', {}));

		expect(error.status).toBe(422);
		expect(error.code).toBe('validation_failed');
		expect(error.message).toBe('Dados inválidos.');
		expect(error.fields).toEqual({ email: ['não pode ficar em branco'] });
	});

	it('keeps the API message untouched for errors without fields', async () => {
		const { client } = setup(() =>
			json({ error: { code: 'unauthenticated', message: 'Faça login para continuar.', fields: {} } }, 401)
		);

		const error = await caught(client.get('/api/cards/OP01-001'));

		expect(error.status).toBe(401);
		expect(error.code).toBe('unauthenticated');
		expect(error.message).toBe('Faça login para continuar.');
		expect(error.fields).toEqual({});
	});
});

describe('createApiClient network failures', () => {
	const networkMessage = 'Sem conexão com o servidor. Tente novamente.';

	it('turns a fetch TypeError into network_error', async () => {
		const { client } = setup(() => {
			throw new TypeError('Failed to fetch');
		});

		const error = await caught(client.get('/api/x'));

		expect(error.status).toBe(0);
		expect(error.code).toBe('network_error');
		expect(error.message).toBe(networkMessage);
	});

	it.each(['TimeoutError', 'AbortError'])('turns a %s into network_error', async (name) => {
		const { client } = setup(() => Promise.reject(new DOMException('aborted', name)));

		const error = await caught(client.get('/api/x'));

		expect(error.code).toBe('network_error');
		expect(error.message).toBe(networkMessage);
	});

	it('turns the timeout signal firing into network_error', async () => {
		vi.useFakeTimers();
		try {
			const controller = new AbortController();
			vi.spyOn(AbortSignal, 'timeout').mockImplementation((ms) => {
				setTimeout(() => controller.abort(new DOMException('timed out', 'TimeoutError')), ms);
				return controller.signal;
			});
			const fetch = vi.fn<typeof globalThis.fetch>(
				(_url, init) =>
					new Promise((_resolve, reject) => {
						init!.signal!.addEventListener('abort', () => reject(init!.signal!.reason));
					})
			);
			const client = createApiClient({
				fetch,
				onUnauthenticated: vi.fn(),
				currentUserEmail: () => null,
				onSessionChanged: vi.fn(),
				timeoutMs: 15000
			});

			const pending = caught(client.get('/api/x'));
			await vi.advanceTimersByTimeAsync(15000);
			const error = await pending;

			expect(error.code).toBe('network_error');
			expect(error.message).toBe(networkMessage);
		} finally {
			vi.useRealTimers();
		}
	});

	it('turns an abort while reading the body into network_error', async () => {
		const response = json({ data: null });
		vi.spyOn(response, 'json').mockRejectedValue(new DOMException('timed out', 'TimeoutError'));
		const { client } = setup(() => response);

		const error = await caught(client.get('/api/x'));

		expect(error.code).toBe('network_error');
	});

	it('does not swallow unrelated errors', async () => {
		const { client } = setup(() => {
			throw new RangeError('boom');
		});

		await expect(client.get('/api/x')).rejects.toBeInstanceOf(RangeError);
	});
});

describe('createApiClient unexpected responses', () => {
	const unexpectedMessage = 'Erro inesperado. Tente novamente.';

	const expectUnexpected = async (response: Response) => {
		const { client } = setup(() => response);
		const error = await caught(client.get('/api/x'));
		expect(error.status).toBe(0);
		expect(error.code).toBe('unexpected_response');
		expect(error.message).toBe(unexpectedMessage);
	};

	it('HTML body', () =>
		expectUnexpected(new Response('<html><body>Bad gateway</body></html>', { status: 502, headers: { 'Content-Type': 'text/html' } })));

	it('invalid JSON on success', () => expectUnexpected(new Response('{nope', { status: 200 })));

	it('empty body', () => expectUnexpected(new Response('', { status: 200 })));

	it('JSON without data or error', () => expectUnexpected(json({ ok: true })));

	it('JSON that is not an object', () => expectUnexpected(json([1, 2])));

	it('JSON null', () => expectUnexpected(json(null)));

	it('success status carrying only an error envelope', () =>
		expectUnexpected(json({ error: { code: 'x', message: 'y', fields: {} } }, 200)));

	it('error status carrying only data', () => expectUnexpected(json({ data: {} }, 500)));

	it('error envelope with a malformed error', () => expectUnexpected(json({ error: 'boom' }, 500)));
});

const apiError = (status: number, code: string, message: string): Response =>
	json({ error: { code, message, fields: {} } }, status);

const unauthenticated = () => apiError(401, 'unauthenticated', 'Faça login para continuar.');
const csrfInvalid = () => apiError(422, 'invalid_csrf_token', 'Token de segurança inválido.');
const sessionOf = (email: string | null, csrf_token: string) =>
	json({ data: { user: email === null ? null : { email }, csrf_token } });

const scripted = (currentEmail: string | null, ...responses: Response[]) => {
	const queue = [...responses];
	const ctx = setup(() => {
		const next = queue.shift();
		if (!next) throw new Error('unexpected extra request');
		return next;
	});
	ctx.currentUserEmail.mockReturnValue(currentEmail);
	const calls = () =>
		ctx.fetch.mock.calls.map(([url, init]) => ({
			method: init!.method,
			url: String(url),
			csrf: new Headers(init!.headers).get('X-CSRF-Token')
		}));
	return { ...ctx, calls };
};

describe('createApiClient 401 handling', () => {
	it.each([
		['GET', (c: ReturnType<typeof setup>['client']) => c.get('/api/cards/OP01-001')],
		['POST', (c: ReturnType<typeof setup>['client']) => c.post('/api/decks', {})]
	])('calls onUnauthenticated once and throws on 401 unauthenticated in a %s', async (_verb, call) => {
		const { client, onUnauthenticated } = scripted('a@b.c', unauthenticated());

		const error = await caught(call(client));

		expect(onUnauthenticated).toHaveBeenCalledTimes(1);
		expect(error.status).toBe(401);
		expect(error.code).toBe('unauthenticated');
		expect(error.message).toBe('Faça login para continuar.');
	});

	it('does not call onUnauthenticated on DELETE /api/session but still throws unauthenticated', async () => {
		const { client, onUnauthenticated } = scripted('a@b.c', unauthenticated());

		const error = await caught(client.delete('/api/session'));

		expect(onUnauthenticated).not.toHaveBeenCalled();
		expect(error.code).toBe('unauthenticated');
	});

	it('does not call onUnauthenticated on 401 invalid_credentials and throws it', async () => {
		const { client, onUnauthenticated } = scripted(
			null,
			apiError(401, 'invalid_credentials', 'E-mail ou senha inválidos.')
		);

		const error = await caught(client.post('/api/session', { email: 'a@b.c', password: 'x' }));

		expect(onUnauthenticated).not.toHaveBeenCalled();
		expect(error.status).toBe(401);
		expect(error.code).toBe('invalid_credentials');
		expect(error.message).toBe('E-mail ou senha inválidos.');
	});
});

describe('createApiClient CSRF renewal', () => {
	const csrfMessage = 'Token de segurança inválido.';

	it('with the same user, does exactly one GET /api/session and one resend with the new token', async () => {
		const { client, calls, onUnauthenticated, onSessionChanged } = scripted(
			'a@b.c',
			csrfInvalid(),
			sessionOf('a@b.c', 'tok-new'),
			json({ data: { id: 1 } })
		);
		client.setCsrfToken('tok-old');

		await expect(client.post('/api/decks', { name: 'x' })).resolves.toEqual({ id: 1 });

		expect(calls()).toEqual([
			{ method: 'POST', url: '/api/decks', csrf: 'tok-old' },
			{ method: 'GET', url: '/api/session', csrf: null },
			{ method: 'POST', url: '/api/decks', csrf: 'tok-new' }
		]);
		expect(onUnauthenticated).not.toHaveBeenCalled();
		expect(onSessionChanged).not.toHaveBeenCalled();
	});

	it('resends the same body', async () => {
		const { client, fetch } = scripted('a@b.c', csrfInvalid(), sessionOf('a@b.c', 't2'), json({ data: null }));

		await client.patch('/api/decks/1', { name: 'novo' });

		expect(fetch.mock.calls[2][1]!.method).toBe('PATCH');
		expect(fetch.mock.calls[2][1]!.body).toBe('{"name":"novo"}');
	});

	it('resends when anonymous on both sides', async () => {
		const { client, calls } = scripted(null, csrfInvalid(), sessionOf(null, 'tok-new'), json({ data: null }));

		await client.post('/api/registration', {});

		expect(calls().map((c) => `${c.method} ${c.url}`)).toEqual([
			'POST /api/registration',
			'GET /api/session',
			'POST /api/registration'
		]);
		expect(calls()[2].csrf).toBe('tok-new');
	});

	it('throws the second 422 without a third send', async () => {
		const { client, calls } = scripted('a@b.c', csrfInvalid(), sessionOf('a@b.c', 'tok-new'), csrfInvalid());

		const error = await caught(client.post('/api/decks', {}));

		expect(error.status).toBe(422);
		expect(error.code).toBe('invalid_csrf_token');
		expect(error.message).toBe(csrfMessage);
		expect(calls()).toHaveLength(3);
	});

	it('does not renew on a 422 in a GET', async () => {
		const { client, calls } = scripted('a@b.c', csrfInvalid());

		const error = await caught(client.get('/api/catalog'));

		expect(error.code).toBe('invalid_csrf_token');
		expect(calls()).toHaveLength(1);
	});

	it('with null user where there was one: calls onUnauthenticated, does not resend, throws unauthenticated', async () => {
		const { client, calls, onUnauthenticated, onSessionChanged } = scripted(
			'a@b.c',
			csrfInvalid(),
			sessionOf(null, 'tok-new')
		);

		const error = await caught(client.post('/api/decks', {}));

		expect(onUnauthenticated).toHaveBeenCalledTimes(1);
		expect(onSessionChanged).not.toHaveBeenCalled();
		expect(error.status).toBe(401);
		expect(error.code).toBe('unauthenticated');
		expect(error.message).toBe('Faça login para continuar.');
		expect(calls()).toHaveLength(2);
	});

	it('with null user on DELETE /api/session: no onUnauthenticated, no resend, throws unauthenticated', async () => {
		const { client, calls, onUnauthenticated } = scripted('a@b.c', csrfInvalid(), sessionOf(null, 'tok-new'));

		const error = await caught(client.delete('/api/session'));

		expect(onUnauthenticated).not.toHaveBeenCalled();
		expect(error.status).toBe(401);
		expect(error.code).toBe('unauthenticated');
		expect(error.message).toBe('Faça login para continuar.');
		expect(calls()).toHaveLength(2);
	});

	it('with another e-mail: calls onSessionChanged with the new user, does not resend, throws session_changed', async () => {
		const { client, calls, onUnauthenticated, onSessionChanged } = scripted(
			'a@b.c',
			csrfInvalid(),
			sessionOf('outro@b.c', 'tok-new')
		);

		const error = await caught(client.post('/api/decks', {}));

		expect(onSessionChanged).toHaveBeenCalledTimes(1);
		expect(onSessionChanged).toHaveBeenCalledWith({ email: 'outro@b.c' });
		expect(onUnauthenticated).not.toHaveBeenCalled();
		expect(error.status).toBe(422);
		expect(error.code).toBe('session_changed');
		expect(error.message).toBe('A sessão mudou em outra aba. Confira a conta e tente de novo.');
		expect(calls()).toHaveLength(2);
	});

	it('with a user appearing where there was none: treats it as another user', async () => {
		const { client, onSessionChanged } = scripted(null, csrfInvalid(), sessionOf('novo@b.c', 'tok-new'));

		const error = await caught(client.post('/api/decks', {}));

		expect(onSessionChanged).toHaveBeenCalledWith({ email: 'novo@b.c' });
		expect(error.code).toBe('session_changed');
	});

	it('keeps the renewed token after a recovery that does not resend', async () => {
		const { client, calls } = scripted('a@b.c', csrfInvalid(), sessionOf('outro@b.c', 'tok-new'), json({ data: null }));

		await caught(client.post('/api/decks', {}));
		await client.post('/api/x');

		expect(calls()[2].csrf).toBe('tok-new');
	});

	it('propagates a failure of the renewal GET without resending', async () => {
		const { client, calls } = scripted('a@b.c', csrfInvalid(), apiError(500, 'internal_error', 'Erro inesperado. Tente novamente.'));

		const error = await caught(client.post('/api/decks', {}));

		expect(error.code).toBe('internal_error');
		expect(calls()).toHaveLength(2);
	});
});
