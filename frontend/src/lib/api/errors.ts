import type { ApiErrorBody } from './types';

export class ApiError extends Error {
	readonly status: number;
	readonly code: string;
	readonly fields: Record<string, string[]>;

	constructor(status: number, code: string, message: string, fields: Record<string, string[]> = {}) {
		super(message);
		this.name = 'ApiError';
		this.status = status;
		this.code = code;
		this.fields = fields;
	}
}

const fieldsFrom = (raw: unknown): Record<string, string[]> => {
	if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) return {};
	const fields: Record<string, string[]> = {};
	for (const [name, messages] of Object.entries(raw)) {
		if (Array.isArray(messages)) fields[name] = messages.filter((m): m is string => typeof m === 'string');
	}
	return fields;
};

export const apiErrorFromBody = (status: number, { error }: ApiErrorBody): ApiError =>
	new ApiError(status, error.code, error.message, fieldsFrom(error.fields));

export const networkError = (): ApiError =>
	new ApiError(0, 'network_error', 'Sem conexão com o servidor. Tente novamente.');

export const unexpectedResponse = (): ApiError =>
	new ApiError(0, 'unexpected_response', 'Erro inesperado. Tente novamente.');

export const sessionChanged = (): ApiError =>
	new ApiError(422, 'session_changed', 'A sessão mudou em outra aba. Confira a conta e tente de novo.');
