import type { OnNavigate } from '$app/navigation';
import { prefersReducedMotion } from 'svelte/motion';
import { armArrival, awaitArrival, hasMark } from './cards/morph.svelte';

const ARRIVAL_TIMEOUT_MS = 500;
const MORPH_ROUTES = new Set<string | null | undefined>(['/', '/cartas/[card_number]']);

export function viewTransitionOnNavigate(navigation: OnNavigate): Promise<void> | void {
	if (!document.startViewTransition || prefersReducedMotion.current) return;

	const from = navigation.from?.url.pathname;
	if (from !== undefined && from === navigation.to?.url.pathname) return;

	// O morph só existe no par grade <-> detalhe; origem fora dele (ex.: /entrar) não espera.
	const fromId = navigation.from?.route?.id;
	const toId = navigation.to?.route?.id;
	const awaitsArrival = MORPH_ROUTES.has(fromId) && MORPH_ROUTES.has(toId) && fromId !== toId;

	return new Promise((resolve) => {
		armArrival();
		document.startViewTransition(async () => {
			resolve();
			await navigation.complete;
			if (awaitsArrival && hasMark()) await awaitArrival(ARRIVAL_TIMEOUT_MS);
		});
	});
}
