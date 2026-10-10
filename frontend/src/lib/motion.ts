import { prefersReducedMotion } from 'svelte/motion';

export function duration(ms: number): number {
	return prefersReducedMotion.current ? 0 : ms;
}
