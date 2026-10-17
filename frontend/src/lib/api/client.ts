import { ApiError, apiErrorFromBody, networkError, sessionChanged, unexpectedResponse } from './errors';
import type { ApiErrorBody, SessionPayload, SessionUser } from './types';

type Method = 'GET' | 'POST' | 'PATCH' | 'PUT' | 'DELETE';
type Query = Record<string, string | number | boolean | undefined>;
type Envelope = Record<string, unknown> & { data: unknown };

export type ApiClientDeps = {
	fetch: typeof fetch;
	onUnauthenticated: () => void;
	currentUserEmail: () => string | null;
	onSessionChanged: (user: SessionUser) => void;
	timeoutMs?: number;
};

export type RequestOptions = { timeoutMs?: number };

export type ApiClient = {
	get<T>(path: string, query?: Query): Promise<T>;
	getEnvelope<T, M>(path: string): Promise<{ data: T; meta: M }>;
	post<T>(path: string, body?: unknown, options?: RequestOptions): Promise<T>;
	patch<T>(path: string, body?: unknown): Promise<T>;
	put<T>(path: string, body?: unknown): Promise<T>;
	delete<T>(path: string): Promise<T>;
	setCsrfToken(token: string | null): void;
};

const DEFAULT_TIMEOUT_MS = 15000;
const SESSION_PATH = '/api/session';
const UNAUTHENTICATED_MESSAGE = 'Faça login para continuar.';
const NETWORK_ERROR_NAMES = new Set(['TypeError', 'TimeoutError', 'AbortError']);

const isNetworkFailure = (error: unknown): boolean =>
	typeof error === 'object' && error !== null && NETWORK_ERROR_NAMES.has((error as { name?: string }).name ?? '');

const isRecord = (value: unknown): value is Record<string, unknown> =>
	typeof value === 'object' && value !== null && !Array.isArray(value);

const isErrorBody = (payload: Record<string, unknown>): payload is ApiErrorBody =>
	isRecord(payload.error) && typeof payload.error.code === 'string' && typeof payload.error.message === 'string';

const isSessionUser = (value: unknown): value is SessionUser => isRecord(value) && typeof value.email === 'string';

const isSessionPayload = (value: unknown): value is Pick<SessionPayload, 'user'> =>
	isRecord(value) && 'user' in value && (value.user === null || isSessionUser(value.user));

const isLocalPath = (path: unknown): path is string => typeof path === 'string' && /^\/(?![/\\])/.test(path);

const withQuery = (path: string, query?: Query): string => {
	const params = new URLSearchParams();
	for (const [key, value] of Object.entries(query ?? {})) {
		if (value !== undefined) params.set(key, String(value));
	}
	const search = params.toString();
	return search ? `${path}?${search}` : path;
};

const readJson = async (response: Response): Promise<unknown> => {
	try {
		return await response.json();
	} catch (error) {
		if (isNetworkFailure(error)) throw error;
		return undefined;
	}
};

export const createApiClient = ({
	fetch,
	onUnauthenticated,
	currentUserEmail,
	onSessionChanged,
	timeoutMs = DEFAULT_TIMEOUT_MS
}: ApiClientDeps): ApiClient => {
	let csrfToken: string | null = null;

	const send = async (
		method: Method,
		url: string,
		body: unknown,
		callTimeoutMs: number
	): Promise<{ status: number; payload: unknown }> => {
		const headers: Record<string, string> = { Accept: 'application/json' };
		const multipart = body instanceof FormData;
		if (body !== undefined && !multipart) headers['Content-Type'] = 'application/json';
		if (method !== 'GET' && csrfToken !== null) headers['X-CSRF-Token'] = csrfToken;
		const serialized = body === undefined || multipart ? body : JSON.stringify(body);

		try {
			const response = await fetch(url, {
				method,
				headers,
				credentials: 'same-origin',
				body: serialized,
				signal: AbortSignal.timeout(callTimeoutMs)
			});
			return { status: response.status, payload: await readJson(response) };
		} catch (error) {
			if (isNetworkFailure(error)) throw networkError();
			throw error;
		}
	};

	const requestEnvelope = async (
		method: Method,
		url: string,
		body?: unknown,
		callTimeoutMs = timeoutMs,
		retried = false
	): Promise<Envelope> => {
		if (!isLocalPath(url)) throw new Error(`O caminho da API deve começar com "/" (recebido: ${String(url)}).`);
		const { status, payload } = await send(method, url, body, callTimeoutMs);
		const ok = status >= 200 && status < 300;

		if (!ok && isRecord(payload) && isErrorBody(payload)) {
			const error = apiErrorFromBody(status, payload);
			const signingOut = method === 'DELETE' && url === SESSION_PATH;

			if (status === 401 && error.code === 'unauthenticated') {
				if (!signingOut) onUnauthenticated();
				throw error;
			}
			if (status === 422 && error.code === 'invalid_csrf_token' && method !== 'GET' && !retried) {
				return recoverFromStaleCsrf(method, url, body, callTimeoutMs, signingOut);
			}
			throw error;
		}
		if (!ok || !isRecord(payload) || !('data' in payload)) throw unexpectedResponse();

		const { data } = payload;
		if (isRecord(data) && typeof data.csrf_token === 'string') csrfToken = data.csrf_token;
		return payload as Envelope;
	};

	const request = async <T>(method: Method, url: string, body?: unknown, callTimeoutMs?: number): Promise<T> =>
		(await requestEnvelope(method, url, body, callTimeoutMs)).data as T;

	const recoverFromStaleCsrf = async (
		method: Method,
		url: string,
		body: unknown,
		callTimeoutMs: number,
		signingOut: boolean
	): Promise<Envelope> => {
		const session = await request<unknown>('GET', SESSION_PATH);
		if (!isSessionPayload(session)) throw unexpectedResponse();
		const { user } = session;

		if ((user?.email ?? null) === currentUserEmail()) return requestEnvelope(method, url, body, callTimeoutMs, true);

		if (user === null) {
			if (!signingOut) onUnauthenticated();
			throw new ApiError(401, 'unauthenticated', UNAUTHENTICATED_MESSAGE);
		}
		onSessionChanged(user);
		throw sessionChanged();
	};

	return {
		get: (path, query) => request('GET', withQuery(path, query)),
		getEnvelope: async <T, M>(path: string) => {
			const { data, meta } = await requestEnvelope('GET', path);
			if (!isRecord(meta)) throw unexpectedResponse();
			return { data: data as T, meta: meta as M };
		},
		post: (path, body, options) => request('POST', path, body, options?.timeoutMs),
		patch: (path, body) => request('PATCH', path, body),
		put: (path, body) => request('PUT', path, body),
		delete: (path) => request('DELETE', path),
		setCsrfToken: (token) => {
			csrfToken = token;
		}
	};
};
