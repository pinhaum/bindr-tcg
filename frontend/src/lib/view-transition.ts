import type { OnNavigate } from '$app/navigation';
import { prefersReducedMotion } from 'svelte/motion';

export function viewTransitionOnNavigate(navigation: OnNavigate): Promise<void> | void {
	if (!document.startViewTransition || prefersReducedMotion.current) return;

	return new Promise((resolve) => {
		document.startViewTransition(async () => {
			resolve();
			await navigation.complete;
		});
	});
}
