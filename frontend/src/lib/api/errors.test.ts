import { describe, expect, it } from 'vitest';
import { ApiError, apiErrorFromBody, networkError, sessionChanged, unexpectedResponse } from './errors';

describe('ApiError', () => {
	it('is an Error carrying status, code, message and fields', () => {
		const error = new ApiError(418, 'teapot', 'Sou um bule.', { x: ['y'] });

		expect(error).toBeInstanceOf(Error);
		expect(error).toBeInstanceOf(ApiError);
		expect(error.status).toBe(418);
		expect(error.code).toBe('teapot');
		expect(error.message).toBe('Sou um bule.');
		expect(error.fields).toEqual({ x: ['y'] });
	});

	it('defaults fields to an empty object', () => {
		expect(new ApiError(500, 'internal_error', 'Erro.').fields).toEqual({});
	});
});

describe('apiErrorFromBody', () => {
	it('keeps message and fields from the API body unchanged', () => {
		const fields = { email: ['não pode ficar em branco', 'é inválido'], password: ['é muito curta'] };
		const error = apiErrorFromBody(422, {
			error: { code: 'validation_failed', message: 'Dados inválidos.', fields }
		});

		expect(error.status).toBe(422);
		expect(error.code).toBe('validation_failed');
		expect(error.message).toBe('Dados inválidos.');
		expect(error.fields).toEqual(fields);
	});
});

describe('factories', () => {
	it('networkError (SPA-12)', () => {
		const error = networkError();

		expect(error).toBeInstanceOf(ApiError);
		expect(error.status).toBe(0);
		expect(error.code).toBe('network_error');
		expect(error.message).toBe('Sem conexão com o servidor. Tente novamente.');
		expect(error.fields).toEqual({});
	});

	it('unexpectedResponse (SPA-13)', () => {
		const error = unexpectedResponse();

		expect(error).toBeInstanceOf(ApiError);
		expect(error.status).toBe(0);
		expect(error.code).toBe('unexpected_response');
		expect(error.message).toBe('Erro inesperado. Tente novamente.');
		expect(error.fields).toEqual({});
	});

	it('sessionChanged (SPA-10)', () => {
		const error = sessionChanged();

		expect(error).toBeInstanceOf(ApiError);
		expect(error.status).toBe(422);
		expect(error.code).toBe('session_changed');
		expect(error.message).toBe('A sessão mudou em outra aba. Confira a conta e tente de novo.');
		expect(error.fields).toEqual({});
	});
});
