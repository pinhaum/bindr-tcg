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

describe('createApiClient caller mistakes', () => {
	it('propagates the original error when the body cannot be serialized, without calling fetch', async () => {
		const { fetch, client } = setup();
		const circular: Record<string, unknown> = {};
		circular.self = circular;

		await expect(client.post('/api/x', circular)).rejects.toThrow(/circular/i);
		await expect(client.post('/api/x', { n: 1n })).rejects.toThrow(/BigInt/);
		expect(fetch).not.toHaveBeenCalled();
	});

	it.each(['api/x', '//evil.example/x', '/\\evil.example/x', 'https://evil.example/x', 'javascript:alert(1)', ''])(
		'rejects the path %j before calling fetch',
		async (path) => {
			const { fetch, client } = setup();

			for (const call of [
				() => client.get(path),
				() => client.post(path),
				() => client.patch(path),
				() => client.put(path),
				() => client.delete(path)
			]) {
				const error = await call().then(
					() => null,
					(e: unknown) => e
				);
				expect(error).toBeInstanceOf(Error);
				expect(error).not.toBeInstanceOf(ApiError);
			}
			expect(fetch).not.toHaveBeenCalled();
		}
	);

	it('rejects a path that is not a string', async () => {
		const { fetch, client } = setup();

		await expect(client.get(undefined as unknown as string)).rejects.toBeInstanceOf(Error);
		expect(fetch).not.toHaveBeenCalled();
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

	it.each([
		['absent', undefined],
		['null', null],
		['a string', 'boom'],
		['an array', ['x']]
	])('gives an empty fields object when fields is %s', async (_label, fields) => {
		const { client } = setup(() => json({ error: { code: 'bad_request', message: 'Requisição inválida.', fields } }, 400));

		const error = await caught(client.post('/api/x', {}));

		expect(error.code).toBe('bad_request');
		expect(error.message).toBe('Requisição inválida.');
		expect(error.fields).toEqual({});
	});

	it('drops fields entries whose value is not an array of strings', async () => {
		const { client } = setup(() =>
			json(
				{
					error: {
						code: 'validation_failed',
						message: 'Dados inválidos.',
						fields: { email: ['é inválido', 3], name: 'em branco', age: null, ok: ['a'] }
					}
				},
				422
			)
		);

		const error = await caught(client.post('/api/registration', {}));

		expect(error.fields).toEqual({ email: ['é inválido'], ok: ['a'] });
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

		expect(error.status).toBe(0);
		expect(error.code).toBe('network_error');
		expect(error.message).toBe(networkMessage);
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

const scripted = (currentEmail: string | null, ...responses: (Response | Error)[]) => {
	const queue = [...responses];
	const ctx = setup(() => {
		const next = queue.shift();
		if (!next) throw new Error('unexpected extra request');
		if (next instanceof Error) throw next;
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

	it.each([
		['PATCH', (c: ReturnType<typeof setup>['client']) => c.patch('/api/decks/1', { name: 'x' })],
		['PUT', (c: ReturnType<typeof setup>['client']) => c.put('/api/decks/1', { name: 'x' })],
		['DELETE', (c: ReturnType<typeof setup>['client']) => c.delete('/api/decks/1')]
	])('renews and resends once in a %s', async (method, call) => {
		const { client, calls } = scripted('a@b.c', csrfInvalid(), sessionOf('a@b.c', 'tok-new'), json({ data: null }));
		client.setCsrfToken('tok-old');

		await call(client);

		expect(calls()).toEqual([
			{ method, url: '/api/decks/1', csrf: 'tok-old' },
			{ method: 'GET', url: '/api/session', csrf: null },
			{ method, url: '/api/decks/1', csrf: 'tok-new' }
		]);
	});

	it('throws a 401 unauthenticated on the resend without a third send, calling onUnauthenticated once', async () => {
		const { client, calls, onUnauthenticated } = scripted(
			'a@b.c',
			csrfInvalid(),
			sessionOf('a@b.c', 'tok-new'),
			unauthenticated()
		);

		const error = await caught(client.post('/api/decks', {}));

		expect(error.status).toBe(401);
		expect(error.code).toBe('unauthenticated');
		expect(error.message).toBe('Faça login para continuar.');
		expect(onUnauthenticated).toHaveBeenCalledTimes(1);
		expect(calls()).toHaveLength(3);
	});

	it('turns a network failure of the renewal GET into network_error without resending', async () => {
		const { client, calls, onUnauthenticated } = scripted('a@b.c', csrfInvalid(), new TypeError('Failed to fetch'));

		const error = await caught(client.post('/api/decks', {}));

		expect(error.status).toBe(0);
		expect(error.code).toBe('network_error');
		expect(error.message).toBe('Sem conexão com o servidor. Tente novamente.');
		expect(onUnauthenticated).not.toHaveBeenCalled();
		expect(calls()).toHaveLength(2);
	});

	it.each([
		['data null', json({ data: null })],
		['data without user', json({ data: { csrf_token: 'tok-new' } })],
		['data as array', json({ data: [] })],
		['user as string', json({ data: { user: 'a@b.c', csrf_token: 'tok-new' } })],
		['user without e-mail', json({ data: { user: {}, csrf_token: 'tok-new' } })]
	])('throws unexpected_response when the renewal GET carries %s, without resending', async (_label, session) => {
		const { client, calls, onUnauthenticated, onSessionChanged } = scripted(null, csrfInvalid(), session);

		const error = await caught(client.post('/api/registration', {}));

		expect(error.status).toBe(0);
		expect(error.code).toBe('unexpected_response');
		expect(error.message).toBe('Erro inesperado. Tente novamente.');
		expect(onUnauthenticated).not.toHaveBeenCalled();
		expect(onSessionChanged).not.toHaveBeenCalled();
		expect(calls()).toHaveLength(2);
	});
});

describe('createApiClient getEnvelope', () => {
	it('calls fetch with the exact path, keeping the raw query untouched', async () => {
		const { fetch, client } = setup(() => json({ data: [], meta: { page: 1 } }));

		await client.getEnvelope('/api/catalog?colors%5B%5D=Red&q=zoro');

		const call = lastCall(fetch);
		expect(call.url).toBe('/api/catalog?colors%5B%5D=Red&q=zoro');
		expect(call.init.method).toBe('GET');
		expect(call.init.body).toBeUndefined();
	});

	it('returns data and meta as they came', async () => {
		const meta = { page: 2, total_count: 10, active_filters: { q: 'zoro' } };
		const { client } = setup(() => json({ data: [{ card_number: 'OP01-001' }], meta }));

		await expect(client.getEnvelope('/api/catalog')).resolves.toEqual({ data: [{ card_number: 'OP01-001' }], meta });
	});

	it('accepts falsy data when meta is an object', async () => {
		const { client } = setup(() => json({ data: null, meta: {} }));

		await expect(client.getEnvelope('/api/x')).resolves.toEqual({ data: null, meta: {} });
	});

	it.each([
		['without meta', { data: [] }],
		['with null meta', { data: [], meta: null }],
		['with array meta', { data: [], meta: [] }],
		['with string meta', { data: [], meta: 'x' }],
		['without data', { meta: {} }]
	])('throws unexpected_response on an envelope %s', async (_name, body) => {
		const { client } = setup(() => json(body));

		const error = await caught(client.getEnvelope('/api/x'));

		expect(error.status).toBe(0);
		expect(error.code).toBe('unexpected_response');
	});

	it('calls onUnauthenticated and throws on 401 unauthenticated', async () => {
		const { client, onUnauthenticated } = setup(() => apiError(401, 'unauthenticated', 'Faça login para continuar.'));

		const error = await caught(client.getEnvelope('/api/x'));

		expect(onUnauthenticated).toHaveBeenCalledTimes(1);
		expect(error.code).toBe('unauthenticated');
	});

	it('keeps the API error code and message for other errors', async () => {
		const { client } = setup(() => apiError(400, 'bad_request', 'Parâmetro inválido.'));

		const error = await caught(client.getEnvelope('/api/x'));

		expect(error.status).toBe(400);
		expect(error.code).toBe('bad_request');
		expect(error.message).toBe('Parâmetro inválido.');
	});

	it.each(['TimeoutError', 'AbortError'])('turns a %s into network_error', async (name) => {
		const { client } = setup(() => Promise.reject(new DOMException('aborted', name)));

		expect((await caught(client.getEnvelope('/api/x'))).code).toBe('network_error');
	});

	it('turns a fetch TypeError into network_error', async () => {
		const { client } = setup(() => {
			throw new TypeError('Failed to fetch');
		});

		expect((await caught(client.getEnvelope('/api/x'))).code).toBe('network_error');
	});

	it('rejects a path that does not start with a single slash', async () => {
		const { client, fetch } = setup();

		await expect(client.getEnvelope('//evil.test/api')).rejects.toThrow();
		expect(fetch).not.toHaveBeenCalled();
	});
});

describe('createApiClient FormData uploads', () => {
	const upload = () => {
		const form = new FormData();
		form.append('file', new File(['a,b'], 'colecao.csv', { type: 'text/csv' }));
		return form;
	};

	it('sends FormData as-is, without Content-Type, with the CSRF token', async () => {
		const { fetch, client } = setup();
		client.setCsrfToken('tok');
		const form = upload();

		await client.post('/api/collection/import', form);

		const call = lastCall(fetch);
		expect(call.init.body).toBe(form);
		expect(call.headers.has('Content-Type')).toBe(false);
		expect(call.headers.get('X-CSRF-Token')).toBe('tok');
	});

	it('keeps Content-Type application/json for plain objects', async () => {
		const { fetch, client } = setup();

		await client.post('/api/x', { a: 1 });

		expect(lastCall(fetch).headers.get('Content-Type')).toBe('application/json');
	});

	it('on a stale CSRF token, renews and resends the same FormData with the same timeout once', async () => {
		const timeout = vi.spyOn(AbortSignal, 'timeout');
		const { client, fetch } = scripted('a@b.c', csrfInvalid(), sessionOf('a@b.c', 'tok-new'), json({ data: { ok: 1 } }));
		client.setCsrfToken('tok-old');
		const form = upload();

		await expect(client.post('/api/collection/import', form, { timeoutMs: 60000 })).resolves.toEqual({ ok: 1 });

		expect(fetch).toHaveBeenCalledTimes(3);
		for (const index of [0, 2]) {
			const init = fetch.mock.calls[index][1]!;
			expect(init.body).toBe(form);
			expect((init.body as FormData).get('file')).toBeInstanceOf(File);
			expect(new Headers(init.headers).has('Content-Type')).toBe(false);
		}
		expect(new Headers(fetch.mock.calls[2][1]!.headers).get('X-CSRF-Token')).toBe('tok-new');
		expect(timeout.mock.calls.map(([ms]) => ms)).toEqual([60000, 15000, 60000]);
	});

	it('with another e-mail on renewal, does not resend and throws session_changed', async () => {
		const { client, fetch, onSessionChanged } = scripted('a@b.c', csrfInvalid(), sessionOf('z@b.c', 'tok-new'));

		const error = await caught(client.post('/api/collection/import', upload()));

		expect(error.code).toBe('session_changed');
		expect(fetch).toHaveBeenCalledTimes(2);
		expect(onSessionChanged).toHaveBeenCalledWith({ email: 'z@b.c' });
	});
});

describe('createApiClient per-call timeout', () => {
	it('lets post wait past the default timeout up to its own, while get still aborts at 15 s', async () => {
		vi.useFakeTimers();
		try {
			vi.spyOn(AbortSignal, 'timeout').mockImplementation((ms) => {
				const controller = new AbortController();
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
				onSessionChanged: vi.fn()
			});

			let postSettled = false;
			const posting = caught(client.post('/api/x', undefined, { timeoutMs: 60000 })).finally(() => (postSettled = true));
			const getting = caught(client.get('/api/x'));

			await vi.advanceTimersByTimeAsync(15000);
			expect((await getting).code).toBe('network_error');
			expect(postSettled).toBe(false);

			await vi.advanceTimersByTimeAsync(45000);
			expect((await posting).code).toBe('network_error');
		} finally {
			vi.useRealTimers();
		}
	});
});
