import { apiErrorFromBody, networkError, unexpectedResponse } from './errors';
import type { ApiErrorBody } from './types';

type Method = 'GET' | 'POST' | 'PATCH' | 'PUT' | 'DELETE';
type Query = Record<string, string | number | boolean | undefined>;

export type ApiClientDeps = {
	fetch: typeof fetch;
	timeoutMs?: number;
};

export type ApiClient = {
	get<T>(path: string, query?: Query): Promise<T>;
	post<T>(path: string, body?: unknown): Promise<T>;
	patch<T>(path: string, body?: unknown): Promise<T>;
	put<T>(path: string, body?: unknown): Promise<T>;
	delete<T>(path: string): Promise<T>;
	setCsrfToken(token: string | null): void;
};

const DEFAULT_TIMEOUT_MS = 15000;
const NETWORK_ERROR_NAMES = new Set(['TypeError', 'TimeoutError', 'AbortError']);

const isNetworkFailure = (error: unknown): boolean =>
	typeof error === 'object' && error !== null && NETWORK_ERROR_NAMES.has((error as { name?: string }).name ?? '');

const isRecord = (value: unknown): value is Record<string, unknown> =>
	typeof value === 'object' && value !== null && !Array.isArray(value);

const isErrorBody = (payload: Record<string, unknown>): payload is ApiErrorBody =>
	isRecord(payload.error) && typeof payload.error.code === 'string' && typeof payload.error.message === 'string';

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

export const createApiClient = ({ fetch, timeoutMs = DEFAULT_TIMEOUT_MS }: ApiClientDeps): ApiClient => {
	let csrfToken: string | null = null;

	const send = async (method: Method, url: string, body?: unknown): Promise<{ status: number; payload: unknown }> => {
		const headers: Record<string, string> = { Accept: 'application/json' };
		if (body !== undefined) headers['Content-Type'] = 'application/json';
		if (method !== 'GET' && csrfToken !== null) headers['X-CSRF-Token'] = csrfToken;

		try {
			const response = await fetch(url, {
				method,
				headers,
				credentials: 'same-origin',
				body: body === undefined ? undefined : JSON.stringify(body),
				signal: AbortSignal.timeout(timeoutMs)
			});
			return { status: response.status, payload: await readJson(response) };
		} catch (error) {
			if (isNetworkFailure(error)) throw networkError();
			throw error;
		}
	};

	const request = async <T>(method: Method, url: string, body?: unknown): Promise<T> => {
		const { status, payload } = await send(method, url, body);
		const ok = status >= 200 && status < 300;

		if (!ok && isRecord(payload) && isErrorBody(payload)) throw apiErrorFromBody(status, payload);
		if (!ok || !isRecord(payload) || !('data' in payload)) throw unexpectedResponse();

		const { data } = payload;
		if (isRecord(data) && typeof data.csrf_token === 'string') csrfToken = data.csrf_token;
		return data as T;
	};

	return {
		get: (path, query) => request('GET', withQuery(path, query)),
		post: (path, body) => request('POST', path, body),
		patch: (path, body) => request('PATCH', path, body),
		put: (path, body) => request('PUT', path, body),
		delete: (path) => request('DELETE', path),
		setCsrfToken: (token) => {
			csrfToken = token;
		}
	};
};
