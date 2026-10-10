import { afterEach, describe, expect, it, vi } from 'vitest';
import { ApiError } from './errors';
import { createApiClient } from './client';

const json = (body: unknown, status = 200): Response =>
	new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });

const setup = (respond: () => Response | Promise<Response> = () => json({ data: null }), timeoutMs?: number) => {
	const fetch = vi.fn<typeof globalThis.fetch>(async () => respond());
	const client = createApiClient({ fetch, timeoutMs });
	return { fetch, client };
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
			const client = createApiClient({ fetch, timeoutMs: 15000 });

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
