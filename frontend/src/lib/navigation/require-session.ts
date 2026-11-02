import { redirect } from '@sveltejs/kit';
import { appPath } from './nav-entries';
import { session } from '../session.svelte';

export function requireSession(url: URL): void {
	if (session.user) return;
	redirect(307, `${appPath('/entrar')}?return_to=${encodeURIComponent(url.pathname + url.search)}`);
}
