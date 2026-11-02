import { prefersReducedMotion } from 'svelte/motion';

export function duration(ms: number): number {
	return prefersReducedMotion.current ? 0 : ms;
}

export function cubicBezier(x1: number, y1: number, x2: number, y2: number): (t: number) => number {
	const axis = (u: number, a: number, b: number) =>
		3 * (1 - u) ** 2 * u * a + 3 * (1 - u) * u ** 2 * b + u ** 3;

	return (t) => {
		if (t <= 0) return 0;
		if (t >= 1) return 1;
		let low = 0;
		let high = 1;
		let u = t;
		for (let i = 0; i < 40; i++) {
			const x = axis(u, x1, x2);
			if (Math.abs(x - t) < 1e-7) break;
			if (x < t) low = u;
			else high = u;
			u = (low + high) / 2;
		}
		return axis(u, y1, y2);
	};
}

export const easeStandard = cubicBezier(0.2, 0, 0, 1);
