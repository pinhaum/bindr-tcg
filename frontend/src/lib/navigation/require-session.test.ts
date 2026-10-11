import { beforeEach, describe, expect, it, vi } from 'vitest';

vi.mock('$app/paths', () => ({ resolve: (path: string) => `/app${path}` }));

import { session } from '../session.svelte';
import { requireSession } from './require-session';

const thrown = (fn: () => void) => {
	try {
		fn();
	} catch (e) {
		return e as { status: number; location: string };
	}
	return null;
};

describe('requireSession', () => {
	beforeEach(() => {
		session.user = null;
	});

	it('sem usuário redireciona 307 para entrar com return_to codificado', () => {
		const e = thrown(() => requireSession(new URL('http://localhost/app/pasta?order=code')));
		expect(e?.status).toBe(307);
		expect(e?.location).toBe('/app/entrar?return_to=%2Fapp%2Fpasta%3Forder%3Dcode');
	});

	it('com usuário não lança', () => {
		session.user = { email: 'ana@example.com' } as typeof session.user;
		expect(() => requireSession(new URL('http://localhost/app/pasta'))).not.toThrow();
	});
});
