import { ApiError } from '../lib/api/errors';
import { loadSession, session } from '../lib/session.svelte';

export const ssr = false;
export const prerender = false;

export async function load(): Promise<void> {
	session.status = 'loading';
	session.error = null;
	try {
		await loadSession();
	} catch (error) {
		if (!(error instanceof ApiError)) throw error;
		session.status = 'error';
		session.error = error;
	}
}
