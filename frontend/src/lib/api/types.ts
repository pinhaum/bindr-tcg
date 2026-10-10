export type ApiEnvelope<T> = { data: T; meta?: Record<string, unknown> };

export type ApiErrorBody = {
	error: { code: string; message: string; fields?: unknown };
};

export type SessionUser = { email: string };

export type SessionPayload = { user: SessionUser | null; csrf_token: string };
