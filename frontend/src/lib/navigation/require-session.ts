import { redirect } from '@sveltejs/kit';
import { resolve } from '$app/paths';
import { session } from '../session.svelte';

export function requireSession(url: URL): void {
	if (session.user) return;
	const base = resolve('/').replace(/\/$/, '');
	redirect(307, `${base}/entrar?return_to=${encodeURIComponent(url.pathname + url.search)}`);
}
