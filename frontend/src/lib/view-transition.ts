import type { OnNavigate } from '$app/navigation';
import { prefersReducedMotion } from 'svelte/motion';

export function viewTransitionOnNavigate(navigation: OnNavigate): Promise<void> | void {
	if (!document.startViewTransition || prefersReducedMotion.current) return;

	const from = navigation.from?.url.pathname;
	if (from !== undefined && from === navigation.to?.url.pathname) return;

	return new Promise((resolve) => {
		document.startViewTransition(async () => {
			resolve();
			await navigation.complete;
		});
	});
}
