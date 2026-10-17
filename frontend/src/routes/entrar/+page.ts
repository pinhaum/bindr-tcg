import { redirect } from '@sveltejs/kit';
import { resolve } from '$app/paths';
import { session } from '../../lib/session.svelte';
import type { PageLoad } from './$types';

export const load: PageLoad = async ({ parent }) => {
	await parent();
	if (session.user) redirect(307, resolve('/'));
};
