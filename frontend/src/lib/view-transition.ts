import type { OnNavigate } from '$app/navigation';
import { prefersReducedMotion } from 'svelte/motion';
import { armArrival, awaitArrival, hasMark } from './cards/morph.svelte';

const ARRIVAL_TIMEOUT_MS = 500;
const MORPH_ROUTES = new Set<string | null | undefined>(['/', '/cartas/[card_number]']);

export function viewTransitionOnNavigate(navigation: OnNavigate): Promise<void> | void {
	if (!document.startViewTransition || prefersReducedMotion.current) return;

	const from = navigation.from?.url.pathname;
	if (from !== undefined && from === navigation.to?.url.pathname) return;

	const awaitsArrival = MORPH_ROUTES.has(navigation.to?.route.id);

	return new Promise((resolve) => {
		armArrival();
		document.startViewTransition(async () => {
			resolve();
			await navigation.complete;
			if (awaitsArrival && hasMark()) await awaitArrival(ARRIVAL_TIMEOUT_MS);
		});
	});
}
