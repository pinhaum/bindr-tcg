import { describe, expect, it, vi, beforeEach } from 'vitest';
import { ApiError } from '../lib/api/errors';

const loadSession = vi.hoisted(() => vi.fn());
vi.mock('../lib/session.svelte', () => ({
	loadSession,
	session: { status: 'ready', user: { email: 'x@y.z' }, error: null }
}));

import { session } from '../lib/session.svelte';
import { load } from './+layout';

describe('+layout load', () => {
	beforeEach(() => {
		loadSession.mockReset();
		session.status = 'ready';
		session.error = null;
	});

	it('chama loadSession uma vez e volta a "loading" antes da chamada', async () => {
		let statusDuringCall = '';
		loadSession.mockImplementation(async () => {
			statusDuringCall = session.status;
		});

		await load();

		expect(loadSession).toHaveBeenCalledOnce();
		expect(statusDuringCall).toBe('loading');
	});

	it('guarda qualquer ApiError em session.error com status "error"', async () => {
		const error = new ApiError(500, 'internal_error', 'Erro interno.');
		loadSession.mockRejectedValue(error);

		await expect(load()).resolves.toBeUndefined();

		expect(session.status).toBe('error');
		expect(session.error).toBe(error);
	});

	it('relança erro que não é ApiError', async () => {
		loadSession.mockRejectedValue(new TypeError('bug'));

		await expect(load()).rejects.toThrow('bug');
	});
});
