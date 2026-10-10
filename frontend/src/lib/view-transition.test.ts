import { afterEach, describe, expect, it, vi } from 'vitest';

const reduced = vi.hoisted(() => ({ current: false }));
vi.mock('svelte/motion', () => ({ prefersReducedMotion: reduced }));

import { viewTransitionOnNavigate } from './view-transition';

const navigation = (complete: Promise<void> = Promise.resolve()) =>
	({ complete }) as Parameters<typeof viewTransitionOnNavigate>[0];

describe('viewTransitionOnNavigate', () => {
	afterEach(() => {
		reduced.current = false;
		Reflect.deleteProperty(document, 'startViewTransition');
	});

	it('não lança nem devolve nada sem document.startViewTransition', () => {
		expect(() => viewTransitionOnNavigate(navigation())).not.toThrow();
		expect(viewTransitionOnNavigate(navigation())).toBeUndefined();
	});

	it('não chama startViewTransition com movimento reduzido', () => {
		const start = vi.fn();
		Object.assign(document, { startViewTransition: start });
		reduced.current = true;

		expect(viewTransitionOnNavigate(navigation())).toBeUndefined();
		expect(start).not.toHaveBeenCalled();
	});

	it('envolve a troca de rota na transição e mantém a atualização até navigation.complete', async () => {
		let finish!: () => void;
		const complete = new Promise<void>((resolve) => (finish = resolve));
		let update!: Promise<void>;
		const start = vi.fn((callback: () => Promise<void>) => {
			update = callback();
		});
		Object.assign(document, { startViewTransition: start });

		await viewTransitionOnNavigate(navigation(complete));
		expect(start).toHaveBeenCalledOnce();

		let settled = false;
		void update.then(() => (settled = true));
		await Promise.resolve();
		expect(settled).toBe(false);
		finish();
		await update;
		expect(settled).toBe(true);
	});
});
